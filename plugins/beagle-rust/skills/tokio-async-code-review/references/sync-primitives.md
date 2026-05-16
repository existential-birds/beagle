# Sync Primitives

## Choosing the Right Primitive

| Need | Primitive | Notes |
|------|-----------|-------|
| Exclusive access to data | `Mutex<T>` | `std::sync` by default; `tokio::sync` only if held across `.await` |
| Single integer / bool / pointer of state | `Atomic*` | No lock needed; see "Atomics beat locks" below |
| Read-heavy, write-rare access | `RwLock<T>` | Benchmark vs `Mutex`; consider `arc_swap::ArcSwap` for replace-not-mutate |
| Limit concurrent operations | `Semaphore` | Rate limiting, connection pooling, bounded fan-out |
| Signal one waiter | `Notify` | Lightweight, no data transfer; mind the lost-wakeup hazard |
| Signal all waiters | `Notify` + `notify_waiters()` | Broadcast wake-up |
| One-time initialization (sync init) | `OnceLock` / `LazyLock` | Stable in std since 1.70 / 1.80 |
| One-time initialization (async init) | `tokio::sync::OnceCell` | When the initializer must `.await` |
| High-contention sync code | `parking_lot::Mutex` / `RwLock` | Smaller, faster, no poisoning |

## Mutex decision matrix: std vs tokio vs parking_lot

Default to `std::sync::Mutex` even in async code, provided the critical section is short and contains no `.await`. This is what the Tokio tutorial itself recommends.

| Want | Use | Why |
|------|-----|-----|
| Short critical section, no `.await` inside | `std::sync::Mutex` | Cheapest; uses OS primitive |
| Lock genuinely must span an `.await` | `tokio::sync::Mutex` | Async-aware; suspends the task instead of the thread |
| High contention on sync code, no poisoning desired, fair RwLock, or `Send` guard via `send_guard` | `parking_lot::Mutex` / `RwLock` | Smaller, faster lock; no `unwrap()` on `lock()` |
| Single integer / bool / pointer of state | atomic (see below) | No lock, no guard, no await question |

`tokio::sync::Mutex` is a `Semaphore` under the hood. The Tokio docs and Mara both note it is materially more expensive (commonly cited as ~3x slower) than `std::sync::Mutex` for short critical sections because of its async-wakeup machinery. Reserve it for the case where you genuinely cannot extract or clone the data out before the `.await`.

`parking_lot::Mutex::lock()` returns the guard directly — no `Result`. A `.unwrap()` here is a smell. Its `RwLock` is fair by default; `std::sync::RwLock` is platform-dependent and can starve writers (or, on glibc, readers) — see the RwLock section below.

```rust
// GOOD - std::sync::Mutex in async code, no .await inside the critical section
use std::sync::Mutex;
struct Counter(Mutex<u64>);

impl Counter {
    async fn bump_and_log(&self) {
        let n = {
            let mut count = self.0.lock().unwrap();
            *count += 1;
            *count
        }; // guard dropped here, before any .await
        log(n).await;
    }
}

// GOOD - tokio::sync::Mutex only when the lock truly spans an await
use tokio::sync::Mutex;
struct Cache(Mutex<HashMap<String, Data>>);

impl Cache {
    async fn get_or_fetch(&self, key: &str) -> Data {
        let mut cache = self.0.lock().await;
        if let Some(data) = cache.get(key) { return data.clone(); }
        let data = fetch(key).await; // lock held across .await — intentional
        cache.insert(key.to_owned(), data.clone());
        data
    }
}
```

Review checks:

- `[FILE:LINE] TOKIO_MUTEX_FOR_SHORT_SECTION` — `tokio::sync::Mutex` wrapping data whose critical sections contain no `.await`. Replace with `std::sync::Mutex`.
- `[FILE:LINE] PARKING_LOT_UNWRAP_ON_LOCK` — `parking_lot::Mutex::lock().unwrap()`. `parking_lot` locks do not return `Result`; drop the `.unwrap()`.

## std::sync::MutexGuard held across .await (canonical async footgun)

This is not just a performance issue. It is a deadlock hazard.

The executor wants to suspend the task at the `.await`. The `std::sync::MutexGuard` is still alive, holding the OS lock. If any other task on the same multi-threaded runtime worker takes the same lock and blocks, the runtime worker is stuck — the holder cannot be polled because its future is parked, and the contender cannot make progress because it owns the worker thread. On a single-threaded runtime, the deadlock is immediate.

`std::sync::MutexGuard` is `!Send` on most platforms, so the compiler will reject the future being spawned onto a multi-threaded runtime. On `LocalSet`, current-thread runtimes, or with `parking_lot`'s `send_guard` feature, it compiles silently — and is still wrong.

The clippy lint `clippy::await_holding_lock` catches the common cases. Treat it as an error in any async crate.

Dropping the guard explicitly before the `.await` (`drop(guard); other.await;`) is correct in principle, but the borrow-region the compiler tracks does not always end at the `drop()` call — block-scoping is more robust.

```rust
// BAD - guard is alive across the .await; deadlock-prone, !Send so won't spawn
async fn lookup(state: &Mutex<HashMap<String, String>>, key: &str) -> Option<String> {
    let guard = state.lock().unwrap();
    let value = guard.get(key);
    fetch_metadata(key).await; // guard still held here
    value.cloned()
}

// GOOD - block-scope drops the guard before any .await
async fn lookup(state: &Mutex<HashMap<String, String>>, key: &str) -> Option<String> {
    let value = {
        let guard = state.lock().unwrap();
        guard.get(key).cloned()
    }; // guard dropped here
    fetch_metadata(key).await;
    value
}
```

Review checks:

- `[FILE:LINE] STD_MUTEX_HELD_ACROSS_AWAIT` — `std::sync::MutexGuard` (or `parking_lot::MutexGuard`) is alive across an `.await`. Block-scope to drop before the await, or move to `tokio::sync::Mutex` if the lock must span it.
- `[FILE:LINE] EXPLICIT_DROP_DOES_NOT_RELEASE_FOR_AWAIT` — `drop(guard); x.await;` used to "release" the lock before an await. The compiler may keep the borrow region open. Use block-scoping instead.

## Semaphore as a generalized lock and back-pressure primitive

`tokio::sync::Semaphore` is the right primitive for **permit-based concurrency limiting**: bounding parallel HTTP fetches, capping in-flight DB queries, throttling a fan-out, or implementing a connection pool. Unlike a `Mutex`, permits compose — you can hold N at once.

Two acquire flavours:

- `acquire()` returns a `SemaphorePermit<'_>` borrowed from `&self`. Cheaper, but tied to the lifetime — useless for `tokio::spawn`'d tasks.
- `acquire_owned()` consumes an `Arc<Semaphore>` and returns an `OwnedSemaphorePermit: 'static`. Required for spawning, more allocation.

```rust
use tokio::sync::Semaphore;
use std::sync::Arc;

// GOOD - bounded fan-out with explicit back-pressure
let sem = Arc::new(Semaphore::new(10));
let mut handles = Vec::new();
for item in items {
    let permit = sem.clone().acquire_owned().await.unwrap(); // back-pressure here
    handles.push(tokio::spawn(async move {
        let result = process(item).await;
        drop(permit); // released on task completion (or here, explicit)
        result
    }));
}
```

```rust
// BAD - unbounded spawn; producer outruns consumer, memory grows without limit
for item in items {
    tokio::spawn(async move { process(item).await });
}
```

For try-acquire (non-blocking):

```rust
match sem.try_acquire() {
    Ok(permit) => { /* proceed */ }
    Err(_) => { /* at capacity, back off or shed load */ }
}
```

`Semaphore::close()` permanently fails all future and pending acquires — useful for shutdown signalling without a separate channel.

Review checks:

- `[FILE:LINE] UNBOUNDED_FAN_OUT_NO_SEMAPHORE` — `for ... { tokio::spawn(...) }` over an unbounded input stream with no semaphore, channel, or `buffer_unordered` capping concurrency. Producer can outpace the runtime.
- `[FILE:LINE] SEMAPHORE_REF_PERMIT_ACROSS_SPAWN` — `sem.acquire().await` (returns borrowed `SemaphorePermit<'_>`) used in a closure passed to `tokio::spawn`. The lifetime cannot be `'static`. Use `acquire_owned()` on an `Arc<Semaphore>`.

## RwLock fairness and writer/reader starvation

Allows multiple concurrent readers or one exclusive writer.

```rust
use tokio::sync::RwLock;

let config = Arc::new(RwLock::new(Config::default()));

// Many readers concurrently
let cfg = config.read().await;
let port = cfg.port;
drop(cfg);

// Exclusive writer
let mut cfg = config.write().await;
cfg.port = 8080;
```

`tokio::sync::RwLock` prevents the classic writer-starvation case — a constant stream of readers cannot indefinitely block a queued writer, because once a writer is queued, new readers are forced to wait. But the reverse is now possible: **readers can be delayed if writers are constantly queueing**. For a write-heavy or write-bursty workload, this can convert an `RwLock` into a worse-than-`Mutex` serialization point. Benchmark before assuming `RwLock` wins.

The same write-preferring discipline causes **recursive reads on the same task to deadlock**: if your task is holding a read guard and a writer queues, asking for a second read guard from the same task waits for that writer, who is waiting for you.

`parking_lot::RwLock` is unfair by default (no writer-preference; readers may starve writers, writers may starve readers depending on contention) but has a `fair` mode (`fair_unlock`) and supports upgradable read guards. In sync code that needs predictable behavior, prefer `parking_lot::RwLock` over `std::sync::RwLock` (whose fairness is platform-dependent — glibc can starve readers, musl can starve writers).

**Reach for `Mutex` when in doubt.** With short critical sections, a `Mutex` is often faster than an `RwLock` even with many readers — the bookkeeping cost of `RwLock` exceeds the savings from reader concurrency until critical sections are long enough to amortize it. For read-mostly state that is occasionally *replaced* (rather than mutated in place), `arc_swap::ArcSwap` beats both — readers are wait-free.

Review checks:

- `[FILE:LINE] TOKIO_RWLOCK_NESTED_READ` — Two `read().await` calls taken in nested scopes on the same task. Write-preferring fairness will deadlock if a writer queues between them. Hoist into a single read scope, or refactor.
- `[FILE:LINE] RWLOCK_FOR_SHORT_SECTION` — `RwLock` wrapping data whose critical sections are a few field reads. Benchmark against `Mutex`; the reader-concurrency win likely does not amortize the overhead.
- `[FILE:LINE] RWLOCK_ARC_FOR_READ_MOSTLY` — `RwLock<Arc<T>>` (or `RwLock<T>` with `Clone`-then-mutate-then-replace) used for read-mostly, write-rare state. Use `arc_swap::ArcSwap<T>` for wait-free reads.

## Atomics beat locks for single-word state

A single `Mutex<u64>` or `Mutex<bool>` for a counter or a flag is almost always the wrong primitive. Prefer the matching atomic (`AtomicU64`, `AtomicBool`, `AtomicUsize`, `AtomicPtr`):

- No lock contention.
- No `MutexGuard` to accidentally hold across `.await`.
- Smaller — an atomic is the size of its underlying type; a `Mutex` carries the lock word plus the OS handle.
- Compatible with `Relaxed` ordering for the common cases (statistics, stop flags, monotonic counters) — see `[../../rust-code-review/references/memory-ordering.md]` for ordering choice and `[../../rust-code-review/references/lock-free-patterns.md]` for CAS-loop patterns.

```rust
// BAD - Mutex for a counter; lock contention, awkward in async
use std::sync::{Arc, Mutex};
let count = Arc::new(Mutex::new(0u64));
for _ in 0..n {
    let c = count.clone();
    tokio::spawn(async move { *c.lock().unwrap() += 1; });
}

// GOOD - atomic; no lock, no guard, no await question
use std::sync::Arc;
use std::sync::atomic::{AtomicU64, Ordering::Relaxed};
let count = Arc::new(AtomicU64::new(0));
for _ in 0..n {
    let c = count.clone();
    tokio::spawn(async move { c.fetch_add(1, Relaxed); });
}
```

The mutex form is *also* wrong if you ever read multiple counters together and treat them as a snapshot — separate atomic loads can interleave with another thread's increments. For coherent multi-field snapshots you do need a `Mutex` (or pack the fields into one atomic word with bit-fields). See `[../../rust-code-review/references/concurrency-primitives.md]` for that case.

Review checks:

- `[FILE:LINE] ARC_MUTEX_FOR_COPY_TYPE` — `Arc<Mutex<T>>` where `T` is `Copy` and primitive-sized (`u8..u64`, `bool`, `usize`, raw pointer) used for a single piece of state. Replace with `Arc<Atomic*>`. Document the chosen `Ordering`.
- `[FILE:LINE] ATOMIC_SNAPSHOT_TORN` — Multiple `Atomic*::load` calls treated as a coherent snapshot by the caller. Either use a `Mutex` over the struct, or pack the fields into one atomic word.

## tokio::sync::Notify and the Notified future

`Notify` is the cheapest "wake one waiter" primitive in Tokio. Reach for it when you have a clear state-change event but no value to transfer (a channel would be the wrong tool) and no shared count to track (a `Semaphore` would be overkill).

The lost-wakeup hazard: `Notify` permits coalesce — if two notifications arrive before any task calls `notified().await`, only one wakeup remains. **You must create the `Notified` future before re-checking the state**; otherwise a notification arriving between the state check and the `.notified().await` will appear as no notification at all.

```rust
// BAD - lost wakeup: notify can fire between the check and the await
async fn wait_ready(notify: &Notify, ready: &AtomicBool) {
    while !ready.load(Acquire) {
        notify.notified().await; // notification before this line is lost
    }
}

// GOOD - register the future first, then re-check, then await
async fn wait_ready(notify: &Notify, ready: &AtomicBool) {
    loop {
        let notified = notify.notified();         // register first
        if ready.load(Acquire) { return; }        // then check
        notified.await;                           // then sleep
    }
}
```

Use a channel (`mpsc`, `watch`, `broadcast`) when you need to *transfer a value*. Use `Notify` only when the wakeup itself is the signal and there is associated state (an `AtomicBool`, a queue length, etc.) the waiter can re-check after waking.

Review checks:

- `[FILE:LINE] NOTIFY_REGISTER_AFTER_CHECK` — `if !ready { notify.notified().await }` or `while !ready { notify.notified().await }` without first constructing the `Notified` future before the state check. Lost-wakeup hazard.
- `[FILE:LINE] NOTIFY_WITHOUT_STATE` — `Notify::notify_one()` used as a wake mechanism with no associated ready/queue-length state for the waiter to re-check. `Notify` coalesces; pair it with an `AtomicBool` / `watch` channel, or use a channel directly.

## OnceCell, OnceLock, and LazyLock in async code

| Primitive | Init signature | Use when |
|-----------|----------------|----------|
| `std::sync::OnceLock<T>` | sync closure, returns `T` | One-time init in sync or async code where the initializer does no `.await` |
| `std::sync::LazyLock<T, F>` | sync closure, called on first deref | Global singletons accessed via static; replaces `lazy_static!` and `once_cell::sync::Lazy` |
| `tokio::sync::OnceCell<T>` | async closure (`get_or_init` is async) | Initialization itself must `.await` (e.g., async DB connect, async config fetch) |

`std::sync::LazyLock` is **effectively poisoned by an init panic**: the panic propagates, every subsequent access also panics, and there is no `clear_poison` analogue. For long-running services with fallible initialization, prefer `OnceLock::get_or_try_init` and store a `Result<T, E>` (or store a sentinel and retry) so the program survives a transient failure during cold start.

`OnceLock::wait()` (stable 1.86) blocks the current thread until the value is set — use it instead of busy-polling `get()`.

`tokio::sync::OnceCell::get_or_init` deadlocks if the initializing closure re-enters the same cell — same hazard as the std version. Precompute or restructure.

```rust
// BAD - LazyLock with fallible init; one bad config file kills the whole service
static CFG: LazyLock<Config> = LazyLock::new(|| Config::load().unwrap());

// GOOD - OnceLock with try-init; caller decides how to handle the error
static CFG: OnceLock<Config> = OnceLock::new();
fn cfg() -> Result<&'static Config, ConfigError> {
    CFG.get_or_try_init(Config::load)
}

// GOOD - tokio::sync::OnceCell for async initialization
static POOL: OnceCell<Pool> = OnceCell::const_new();
async fn pool() -> &'static Pool {
    POOL.get_or_init(|| async { Pool::connect(&DB_URL).await.unwrap() }).await
}
```

For single-threaded or non-`Sync` contexts, use `std::cell::LazyCell` instead.

Migration: replace `once_cell::sync::Lazy` and `lazy_static!` in any crate targeting MSRV ≥ 1.80 with `std::sync::LazyLock`.

Review checks:

- `[FILE:LINE] LAZYLOCK_FALLIBLE_INIT` — `LazyLock::new` whose closure can panic on bad input (missing env var, malformed config). Panic is unrecoverable; cell stays poisoned for the process lifetime. Use `OnceLock::get_or_try_init` instead.

## if let Temporary Scope Changes (Edition 2024)

In Rust 2024, temporaries in `if let` conditions are dropped at the end of the `if let` **condition**, not at the end of the block. This affects async lock guard patterns.

```rust
// Edition 2021 - guard lives through the if-let body
if let Some(val) = state.lock().await.get("key") {
    // guard is still alive here in edition 2021
    do_work(val).await; // holding the lock across await — risky but compiles
}

// Edition 2024 - guard is dropped after the condition evaluates
// val would be a dangling reference — this may fail to compile
if let Some(val) = state.lock().await.get("key") {
    do_work(val).await; // guard already dropped!
}

// GOOD - explicit binding extends the guard's lifetime
let guard = state.lock().await;
if let Some(val) = guard.get("key") {
    do_work(val).await;
}
drop(guard);

// GOOD - clone the value to avoid depending on guard lifetime
if let Some(val) = state.lock().await.get("key").cloned() {
    do_work(val).await; // val is owned, guard already dropped — safe
}
```

This also applies to `while let` and `match` with temporary-producing expressions. Review any pattern where a lock guard is created inline in a conditional.

## Common Mistakes

### Deadlock via Lock Ordering

```rust
// BAD - potential deadlock if another task locks B then A
let _a = state_a.lock().await;
let _b = state_b.lock().await;

// GOOD - always lock in consistent order, or use a single lock
```

### Forgetting to Drop Guards

```rust
// BAD - guard lives until end of scope, holding lock during await
let guard = state.lock().await;
let value = guard.get_value();
do_async_work(value).await; // guard still held!

// GOOD - extract value and drop guard
let value = {
    let guard = state.lock().await;
    guard.get_value().clone()
};
do_async_work(value).await;
```

## Review Questions

1. Is the right sync primitive chosen for the access pattern?
2. Are mutex guards dropped before `.await` points?
3. Is lock ordering consistent to prevent deadlocks?
4. Is `Semaphore` used instead of ad-hoc concurrency limits?
5. Are `std::sync` vs `tokio::sync` primitives matched to their context?
6. Are `once_cell` / `lazy_static` usages replaced with `std::sync::LazyLock` where possible?
7. Do `if let` / `while let` patterns with inline lock guards account for edition 2024 temporary scoping?
