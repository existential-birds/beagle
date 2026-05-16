# Concurrency Primitives

For async-specific patterns (tokio, channels, cancellation), see [async-concurrency.md](async-concurrency.md). For deep dives on `Ordering` and happens-before reasoning, see [memory-ordering.md](memory-ordering.md). For hand-rolled spinlocks, channels, and Arc, see [lock-free-patterns.md](lock-free-patterns.md).

## Send and Sync Semantics

- **`Send`**: a type can be transferred to another thread. Most types are `Send`. Notable exceptions: `Rc`, `MutexGuard` (on some platforms).
- **`Sync`**: a type can be shared (via `&T`) between threads. `T` is `Sync` if `&T` is `Send`. Notable exceptions: `Cell`, `RefCell`, `Rc`.

Both are auto-traits: the compiler implements them if all fields are `Send`/`Sync`. Raw pointers block auto-implementation as a safety guard.

### Manual Implementation

**Flag when**: `unsafe impl Send` or `unsafe impl Sync` appears without:
1. A safety comment explaining why the invariant holds
2. Bounds on generic parameters

```rust
// BAD — missing bound allows T: !Send to cross threads
unsafe impl<T> Send for MyWrapper<T> {}

// GOOD — bound ensures inner T is also Send
unsafe impl<T: Send> Send for MyWrapper<T> {}
```

**Check for**: types containing `Rc`, `Cell`, `RefCell`, or raw pointers that manually implement `Send`/`Sync` — these need extra scrutiny.

### Why `Rc` is `!Send + !Sync`, but `Arc` is both

`Rc<T>` uses a non-atomic counter — two threads cloning concurrently would corrupt it. `Arc<T>` uses `AtomicUsize` for the strong/weak counts, so `Arc<T>: Send + Sync` *when `T: Send + Sync`*. Both bounds are required: sending an `Arc` clone to another thread implicitly shares `&T` (so `T: Sync`), and the receiver may drop the last reference (so `T: Send`). `Arc<Cell<u32>>` is rejected because `Cell: !Sync`.

### Why `MutexGuard<'_, T>` is `!Send`

On platforms where `std::sync::Mutex` wraps `pthread_mutex_t`, POSIX requires the unlocking thread to be the locking thread. Rust encodes this by making `MutexGuard: !Send`. `parking_lot::MutexGuard` is `!Send` by default; opting into the `send_guard` feature drops priority inheritance on platforms that need it. Reviewers should not "fix" a `!Send` compile error by transmuting or wrapping the guard.

### `unsafe impl` for wrappers around `UnsafeCell`

When you wrap `Arc<UnsafeCell<T>>` or similar to share interior-mutable data, both bounds matter:

```rust
struct Shared<T> { inner: Arc<UnsafeCell<T>> }
// SAFETY: All access to T is serialized through the spin-lock in `inner`.
// T: Send is required because ownership crosses threads via the lock handoff.
unsafe impl<T: Send> Sync for Shared<T> {}
unsafe impl<T: Send> Send for Shared<T> {}
```

Note `T: Send` (not `T: Sync`) is the typical bound for a *lock-like* wrapper: only one thread accesses `T` at a time, but ownership transfers across threads. A wrapper that exposes `&T` concurrently (e.g., an `RwLock` reader) needs `T: Sync`.

### Opting out of auto traits

Use `PhantomData<*const ()>` to make a type `!Send + !Sync` (raw pointers are `!Send + !Sync`, and `PhantomData` propagates). Use `PhantomData<Cell<()>>` to keep `Send` but drop `Sync`. Reviewers should flag `PhantomData<T>` used purely as an auto-trait switch when the type does not actually own a `T` — preferred forms above are clearer.

- `[FILE:LINE] UNSAFE_SEND_SYNC_WITHOUT_SAFETY_COMMENT` — `unsafe impl (Send|Sync)` with no preceding `// SAFETY:` justification.
- `[FILE:LINE] UNSAFE_SEND_SYNC_MISSING_GENERIC_BOUND` — `unsafe impl<T> Send for W<T> {}` with no bound; almost always wrong.
- `[FILE:LINE] PHANTOMDATA_AUTO_TRAIT_HACK` — `PhantomData<T>` used to block `Send`/`Sync` when the type doesn't own a `T`; prefer `PhantomData<*const ()>` or `PhantomData<Cell<()>>`.

## Atomics and Memory Ordering

Atomic types (`AtomicBool`, `AtomicUsize`, `AtomicPtr`, etc.) provide lock-free concurrent access. Every operation takes an `Ordering` argument.

### Ordering Guide

| Ordering | Guarantees | Use When |
|----------|-----------|----------|
| `Relaxed` | Atomic access only, no ordering with other ops | Counters, statistics, flags where order doesn't matter |
| `Acquire` | Loads cannot be reordered before this load; sees all stores before a paired `Release` | Reading a lock state, reading a "ready" flag |
| `Release` | Stores cannot be reordered after this store | Writing to a lock state, setting a "ready" flag |
| `AcqRel` | Both `Acquire` and `Release` | `compare_exchange` that both reads and writes |
| `SeqCst` | All threads see the same total order of `SeqCst` operations | When multiple atomics must be globally ordered |

### Common Patterns

**Acquire/Release pair** (most common for synchronization):
```rust
// Writer thread
data.store(42, Ordering::Relaxed);
flag.store(true, Ordering::Release); // all prior stores visible to Acquire readers

// Reader thread
if flag.load(Ordering::Acquire) {
    // guaranteed to see data == 42
    let val = data.load(Ordering::Relaxed);
}
```

**Flag when**:
- `Relaxed` used where the value gates access to other shared data — needs at least `Acquire`/`Release`
- `SeqCst` used everywhere "to be safe" — this is correct but may be unnecessarily costly on non-x86 architectures. Flag as informational if `Acquire`/`Release` would suffice.
- `compare_exchange` success ordering is `Relaxed` when it guards a critical section — needs `AcqRel`

**Valid pattern**: `Relaxed` for metrics counters, reference counts (when paired with `Acquire` on the final decrement), and statistics.

## UnsafeCell and Interior Mutability Invariants

`UnsafeCell<T>` is the **only** legitimate primitive that lets safe code obtain `&mut T` from `&T`. Every interior-mutability type in `std` (`Cell`, `RefCell`, `Mutex`, `RwLock`, `OnceLock`, atomics) is built on it. The rule: a shared reference to an `UnsafeCell` is the only way to obtain a mutable raw pointer to data behind a shared reference. Any wrapper that hands out `&mut T` from `&T` without going through `UnsafeCell::get()` is unsound and violates the aliasing rules Miri checks.

```rust
use std::cell::UnsafeCell;

pub struct OneShot<T> {
    cell: UnsafeCell<Option<T>>,
}
// SAFETY: callers must serialize access externally (e.g., via an AtomicBool).
unsafe impl<T: Send> Sync for OneShot<T> {}

impl<T> OneShot<T> {
    pub fn set(&self, value: T) {
        // Caller has proven exclusive write access.
        unsafe { *self.cell.get() = Some(value) };
    }
}
```

A public type containing `UnsafeCell<T>` **must** have an `unsafe impl Sync` (or be explicitly `!Sync`) with a written safety argument; the auto-trait default would leave the type `!Sync` for the wrong reason.

- `[FILE:LINE] UNSAFECELL_NO_SYNC_RATIONALE` — public type holds `UnsafeCell<T>` with `unsafe impl Sync` but no `// SAFETY:` comment describing the access-serialization scheme.
- `[FILE:LINE] UNSAFECELL_GET_MUT_ALIASING` — `&mut *cell.get()` produced while another `&T` or `&mut T` derived from the same cell is live; flag any place where two such pointers' lifetimes overlap.
- `[FILE:LINE] PUB_UNSAFECELL_FIELD` — `pub` field of type `UnsafeCell<T>` on an otherwise safe API; external callers can mint aliasing pointers.

## MaybeUninit and Atomic Initialization Patterns

`MaybeUninit<T>` represents possibly-uninitialized storage. The "atomic initialization" pattern uses an `AtomicBool` (or `AtomicU8` with multiple states) to gate access to a `MaybeUninit<T>` until it has been written:

```rust
use std::cell::UnsafeCell;
use std::mem::MaybeUninit;
use std::sync::atomic::{AtomicBool, Ordering::{Acquire, Release}};

pub struct LazyInit<T> {
    value: UnsafeCell<MaybeUninit<T>>,
    ready: AtomicBool,
}

impl<T> LazyInit<T> {
    pub fn set(&self, v: T) {
        unsafe { (*self.value.get()).write(v) };
        self.ready.store(true, Release); // publishes the write above
    }
    pub fn get(&self) -> Option<&T> {
        if self.ready.load(Acquire) {
            // SAFETY: `ready == true` happens-after `set`'s write.
            Some(unsafe { (*self.value.get()).assume_init_ref() })
        } else { None }
    }
}
```

Pitfalls to flag:

- `MaybeUninit::uninit().assume_init()` called without ever writing the storage — UB even for `Copy` types when their bit pattern is invalid (`bool`, `char`, references, enums).
- `assume_init_read` called twice on the same `MaybeUninit` — double-drop or use-after-move; the value's destructor may already have run.
- A `Drop` impl that unconditionally calls `assume_init_drop` on a `MaybeUninit<T>` field — drops uninitialized memory when the gate flag is false. The correct shape is `if *self.ready.get_mut() { unsafe { self.value.get_mut().assume_init_drop() } }`.
- For lazy one-shot init, prefer `OnceLock::get_or_init` over hand-rolled `MaybeUninit` + `AtomicBool` unless allocation or `const fn` construction is a hard requirement.

- `[FILE:LINE] MAYBEUNINIT_UNCONDITIONAL_DROP` — `assume_init_drop` in a `Drop` impl without checking an init flag.
- `[FILE:LINE] MAYBEUNINIT_DOUBLE_READ` — two `assume_init_read` calls reachable on the same `MaybeUninit` storage.

## Mutex and RwLock Poisoning

A `Mutex<T>` poisons when a thread panics while holding the guard. `RwLock<T>` poisons **only** when a write-guard holder panics; a panic with a read guard does not poison. Subsequent `lock()` / `write()` calls return `Err(PoisonError<MutexGuard<T>>)`. `PoisonError::into_inner()` yields the (possibly inconsistent) guard so you can repair the data and continue.

`std::sync::Mutex::clear_poison()` and `RwLock::clear_poison()` (stable in **1.77**) let code recover after repairing the invariant:

```rust
let guard = m.lock().unwrap_or_else(|mut e| {
    **e.get_mut() = T::default(); // restore the invariant
    m.clear_poison();
    e.into_inner()
});
```

When `.unwrap()` is fine vs. when it is not:

- **Fine**: the protected data has no multi-field invariant a partial update could break — e.g., a `Mutex<Vec<Event>>` where any prefix of events is valid.
- **Flag**: a `Mutex<State>` where `State` has fields that must agree (cached count vs. underlying collection length, two halves of a struct). Recommend documenting the rationale or using `clear_poison` with a repair step.

Important asymmetry: `LazyLock<T, F>` poisoning is **unrecoverable**. An init-closure panic propagates, and every subsequent access also panics with no `clear_poison` analogue. For fallible init in long-running services, use `OnceLock::get_or_init` (or the unstable `get_or_try_init`), which is *not* poisoned by a panicking closure — the next caller may retry.

`is_poisoned()` is advisory only: it races against other threads and can be stale by the time you act on it. Branching on `is_poisoned()` to decide control flow is almost always wrong; act on the `PoisonError` returned by `lock()` directly.

- `[FILE:LINE] UNWRAP_ON_LOCK_DROPS_RECOVERY` — `lock().unwrap()` on data with a multi-field invariant and no rationale comment. Recommend `unwrap_or_else(|e| { repair; clear_poison(); e.into_inner() })`.
- `[FILE:LINE] BRANCH_ON_IS_POISONED` — control flow branches on `mutex.is_poisoned()`; race-prone. Act on `lock()`'s `PoisonError` instead.
- `[FILE:LINE] LAZYLOCK_FALLIBLE_INIT` — `LazyLock::new(|| ...)` with an initializer that can panic (network calls, parsing user input). One panic permanently breaks the cell. Use `OnceLock` and explicit retry.

## Mutex vs RwLock vs Atomics

| Primitive | Read Contention | Write Contention | Use When |
|-----------|----------------|------------------|----------|
| `Mutex` | Blocks all readers | Blocks all | Simple mutual exclusion, short critical sections |
| `RwLock` | Concurrent reads OK | Blocks all | Read-heavy workloads with infrequent writes |
| Atomics | Lock-free reads | Lock-free CAS | Single values, counters, flags |
| `parking_lot::Mutex` | Faster than std | Faster than std | Drop-in replacement when performance matters |
| `parking_lot::RwLock` | Faster, fair | Faster, fair | Read-heavy with fairness requirements |

**Check for**:
- `RwLock` where writes are frequent — reader/writer lock overhead may exceed a simple `Mutex`
- `Mutex` protecting a single integer — an atomic is simpler and lock-free
- `std::sync::Mutex` in async code held across `.await` — use `tokio::sync::Mutex` instead (see async-concurrency.md)

## Lock Ordering and Deadlock Prevention

**Flag when**: code acquires multiple locks without a documented ordering. Two threads acquiring locks in different orders will deadlock.

```rust
// DEADLOCK RISK — thread 1 locks A then B, thread 2 locks B then A
let _a = lock_a.lock().unwrap();
let _b = lock_b.lock().unwrap();

// SAFE — document and enforce a global lock ordering
// Rule: always acquire lock_a before lock_b
```

Prevention strategies:
- **Global lock ordering**: document which locks must be acquired first. Enforce in code review.
- **Lock splitting**: use finer-grained locks that are never held simultaneously
- **Lock-free algorithms**: avoid locks entirely with atomics and `compare_exchange`
- **`try_lock` with backoff**: detect contention and retry

## Common Concurrency Bugs to Flag

1. **Data races**: mutation of non-atomic shared state without synchronization — always undefined behavior
2. **Lock held across await**: `MutexGuard` alive at `.await` point — see [async-concurrency.md](async-concurrency.md). Block-scope the guard or switch to `tokio::sync::Mutex`; `drop(guard)` before `.await` does not always convince the compiler the borrow region has closed.
3. **Incorrect `Send`/`Sync`**: manual implementations missing generic bounds
4. **TOCTOU (time-of-check-to-time-of-use)**: checking a condition then acting on it without holding the lock
5. **Forgetting to join spawned threads**: fire-and-forget threads with `thread::spawn` may outlive the data they reference
6. **`compare_exchange` without loop**: CAS can spuriously fail on some architectures — use `compare_exchange_weak` in a loop for better performance
7. **ABA on pointer-tagged CAS**: between a `load(A)` and `compare_exchange(A, B)`, the value goes `A → X → A`. CAS succeeds and the caller misses an intermediate state. **When this is a real bug**: lock-free stacks, queues, linked lists where `A` is a pointer to a freed-and-reused node — silent use-after-free or lost insertions. **When it is benign**: integer refcounts, ID counters, or anywhere the value identity *is* the value. Fix by using `crossbeam-epoch`, hazard pointers, or a packed `(ptr, generation)` `AtomicU64`. See [lock-free-patterns.md](lock-free-patterns.md).
8. **"Out of thin air" panic-mongering**: the formal C++/Rust memory model permits `Relaxed` reads to materialize circular-dependency values. No real compiler or CPU has ever exhibited this. Do **not** let it scare you off `Relaxed` for counters, statistics, or correctly-paired publish flags. The legitimate concerns with `Relaxed` are missing happens-before, not thin-air values. See [memory-ordering.md](memory-ordering.md) for the full story.

```rust
// BAD — single compare_exchange may fail spuriously
let old = val.compare_exchange(0, 1, Ordering::AcqRel, Ordering::Relaxed);

// GOOD — loop for retry (unless you handle failure explicitly)
loop {
    match val.compare_exchange_weak(0, 1, Ordering::AcqRel, Ordering::Relaxed) {
        Ok(_) => break,
        Err(_) => continue,
    }
}
```

## Atomic Types Survey

`std::sync::atomic` exposes one atomic per primitive width:

| Type | Notes |
|------|-------|
| `AtomicBool` | One-byte flag. Use for stop signals, ready flags, lock state. |
| `AtomicUsize` / `AtomicIsize` | Pointer-sized integers; the usual choice for counters and indices. |
| `AtomicU8/16/32/64` and signed variants | Sized integers. `AtomicU64` is **not available on every target** (see below). |
| `AtomicPtr<T>` | Raw pointer; load/store/CAS lock-free for lock-free data structures. |

### Target gating

Availability is gated by `#[cfg(target_has_atomic = "8" | "16" | "32" | "64" | "ptr")]`. Notable gaps:

- 32-bit PowerPC and MIPS: no `AtomicU64`.
- `thumbv6m-*` and `thumbv8m.base-*`: only `load`/`store` are available — no CAS, no `fetch_*`.

Portable code must `#[cfg(target_has_atomic = "64")]`-gate any 64-bit atomic use, with a fallback (typically `Mutex<u64>`).

### Convenience methods worth knowing

- `fetch_update(set_ordering, fetch_ordering, f)` — built-in CAS loop. Replace hand-rolled `loop { let cur = a.load(...); a.compare_exchange_weak(cur, f(cur), ...) }` with it when `f` is pure.
- `get_mut(&mut self) -> &mut T`, `into_inner(self) -> T` — no ordering needed; the borrow checker proves exclusivity. Prefer these in constructors and `&mut self` methods over `load(SeqCst)`.
- `as_ptr() -> *mut T` — raw pointer for FFI.

### Nightly-only (do not flag absence)

- `Atomic*::from_ptr(*mut T)` (feature `atomic_from_ptr`) — view a raw pointer as an atomic.
- `Atomic*::from_mut(&mut T)` (feature `atomic_from_mut`) — view a unique borrow as an atomic.

### Concurrent atomic / non-atomic accesses

Rust permits a `Relaxed` atomic load to race with a non-atomic *read* of the same address (this differs from C++). Concurrent atomic writes vs. non-atomic accesses of any kind, and mixed-size atomic accesses to overlapping memory, are UB. Atomic accesses to read-only memory (statics in `.rodata`) are UB *except* for "small" `Relaxed` loads (≤4 bytes on 32-bit, ≤8 bytes on 64-bit) — use `load(Relaxed)` followed by `fence(Acquire)` instead of `load(Acquire)` on a static.

- `[FILE:LINE] ATOMIC_NO_TARGET_HAS_ATOMIC_CFG` — `AtomicU64` / `AtomicI64` used in a library targeting `no_std` or embedded without a `#[cfg(target_has_atomic = "64")]` gate.
- `[FILE:LINE] HAND_ROLLED_FETCH_UPDATE` — `loop { let cur = a.load(...); if a.compare_exchange_weak(cur, f(cur), ...).is_ok() { break; } }` where `fetch_update` would express the same intent.

## `std::thread::scope` for Bounded Thread Lifetimes

Scoped threads (stable since 1.63) borrow non-`'static` data safely by guaranteeing all threads join before the scope exits.

```rust
let mut data = vec![1, 2, 3];
std::thread::scope(|s| {
    s.spawn(|| {
        println!("{:?}", &data); // borrows data — no Arc needed
    });
    s.spawn(|| {
        println!("len: {}", data.len());
    });
}); // all threads joined here — data is safe to use again
```

**Flag when**: `Arc<T>` is used to share data with threads that are joined before the function returns — `thread::scope` is simpler and avoids the allocation.

## OnceLock / LazyLock Patterns

`OnceLock` stable since 1.70, `LazyLock` stable since 1.80. Replace `once_cell` and `lazy_static` for new code.

```rust
use std::sync::{LazyLock, OnceLock};

// LazyLock: initialize with a closure, computed on first access
static CONFIG: LazyLock<Config> = LazyLock::new(|| load_config());

// OnceLock: initialize at runtime, set exactly once
static DB: OnceLock<Database> = OnceLock::new();
fn init_db(conn_str: &str) {
    DB.set(Database::connect(conn_str)).expect("DB already initialized");
}
```

**Flag when**: new code (MSRV >= 1.80) uses `once_cell::sync::Lazy` or `lazy_static!` — prefer `LazyLock`/`OnceLock` from std.

## crossbeam and parking_lot Patterns

### crossbeam

- `crossbeam::channel`: faster, more ergonomic channels than `std::sync::mpsc`. Supports `select!` over multiple channels.
- `crossbeam::epoch`: epoch-based memory reclamation for lock-free data structures
- `crossbeam::utils::CachePadded`: wraps a value to occupy a full cache line, preventing false sharing

**Flag when**: hot concurrent counters or flags are in adjacent memory without cache-line padding — likely false sharing.

### parking_lot

- Drop-in replacements for `std::sync::{Mutex, RwLock, Condvar, Once}`
- Faster on contended workloads, smaller `Mutex` size (1 byte vs 40+ bytes on Linux)
- Provides `MutexGuard::map` for projecting through a lock

**Valid pattern**: `parking_lot::Mutex` over `std::sync::Mutex` when benchmarks show contention is a bottleneck.

## Review Questions

1. Are `Send`/`Sync` implementations bounded on generic parameters?
2. Is the memory ordering for each atomic operation sufficient for its use case?
3. Are multiple locks acquired in a consistent, documented order?
4. Could `thread::scope` replace `Arc` for data shared with joined threads?
5. Are `once_cell`/`lazy_static` uses replaceable with `OnceLock`/`LazyLock` (MSRV >= 1.80)?
6. Is there false sharing risk from adjacent atomic values without cache-line padding?
7. Are `compare_exchange` operations in a retry loop when spurious failure is possible?
8. Does every `UnsafeCell<T>` field have an accompanying `unsafe impl Sync` (or explicit `!Sync`) with a written safety argument naming the access-serialization mechanism?
9. Does every `MaybeUninit<T>` field have a `Drop` impl that checks an init flag before calling `assume_init_drop`?
10. For each `lock().unwrap()`, is poisoning genuinely unrecoverable, or should the code repair the invariant and call `clear_poison()` (1.77+)? Is any `LazyLock` initializer fallible (a one-shot panic permanently breaks the cell)?
11. For each pointer CAS, is ABA addressed via `crossbeam-epoch`, hazard pointers, or a generation counter? Or is the data integer-like enough for ABA to be benign?
12. Is any `AtomicU64` / `AtomicI64` use gated on `#[cfg(target_has_atomic = "64")]` for portable / `no_std` crates?
