# Async and Concurrency

## Critical Anti-Patterns

### 1. Blocking in Async Context

Blocking operations inside async functions starve the tokio runtime's thread pool, causing latency spikes and potential deadlocks.

```rust
// BAD - blocks the async runtime thread
async fn read_config() -> Config {
    let data = std::fs::read_to_string("config.toml").unwrap(); // BLOCKING!
    toml::from_str(&data).unwrap()
}

// GOOD - use async I/O
async fn read_config() -> Result<Config, Error> {
    let data = tokio::fs::read_to_string("config.toml").await?;
    let config: Config = toml::from_str(&data)?;
    Ok(config)
}

// GOOD - offload blocking work to a dedicated thread
async fn compute_hash(data: Vec<u8>) -> Result<Hash, Error> {
    tokio::task::spawn_blocking(move || {
        expensive_hash(&data)
    }).await?
}
```

Common blockers to watch for: `std::fs`, `std::net`, `std::thread::sleep`, CPU-heavy computation, synchronous database drivers.

### 2. Holding Locks Across Await Points

A `MutexGuard` held across an `.await` can cause deadlocks and prevents `Send` bounds from being satisfied.

```rust
// BAD - guard held across await
async fn update(state: &Mutex<State>) {
    let mut guard = state.lock().await;
    let data = fetch_data().await; // guard still held!
    guard.data = data;
}

// GOOD - drop guard before await
async fn update(state: &Mutex<State>) {
    let current = {
        let guard = state.lock().await;
        guard.data.clone()
    }; // guard dropped here
    let new_data = fetch_data().await;
    let mut guard = state.lock().await;
    guard.data = new_data;
}
```

### 3. Using std::sync::Mutex in Async Code

`std::sync::Mutex` blocks the thread while waiting. In async code, use `tokio::sync::Mutex` which yields to the runtime, or use `std::sync::Mutex` only for short, non-async critical sections.

```rust
// RISKY - std mutex in async context
use std::sync::Mutex;
async fn process(shared: &Mutex<Vec<Item>>) {
    let mut guard = shared.lock().unwrap(); // blocks thread
    guard.push(item);
}

// GOOD - tokio mutex for async-aware locking
use tokio::sync::Mutex;
async fn process(shared: &Mutex<Vec<Item>>) {
    let mut guard = shared.lock().await; // yields to runtime
    guard.push(item);
}
```

Exception: `std::sync::Mutex` is fine when the critical section is very short (no async operations, just field access) because it avoids the overhead of tokio's async mutex. The tokio docs themselves recommend this pattern.

> For a detailed comparison of `tokio::sync::Mutex` vs `std::sync::Mutex` and other sync primitives (`RwLock`, `Semaphore`, `Notify`), see `beagle-rust:tokio-async-code-review` (references/sync-primitives.md).

### 4. Spawning Tasks Without Join Handles

Fire-and-forget tasks can silently fail, leak resources, or outlive their logical scope.

```rust
// BAD - task error is lost, no lifecycle management
tokio::spawn(async {
    process_batch(items).await;
});

// GOOD - handle tracked for cancellation and error reporting
let handle = tokio::spawn(async move {
    process_batch(items).await
});
// ... later
match handle.await {
    Ok(result) => result?,
    Err(e) => tracing::error!(error = %e, "batch processing panicked"),
}
```

### 5. Missing Cancellation Safety

When a future is dropped (e.g., via `tokio::select!`), partially completed operations may leave state inconsistent.

```rust
// RISKY - if timeout fires, partial write may have occurred
tokio::select! {
    result = write_to_db(&data) => { ... }
    _ = tokio::time::sleep(timeout) => {
        return Err(Error::Timeout);
    }
}

// SAFER - use cancellation-safe operations or checkpoints
tokio::select! {
    result = write_to_db_atomic(&data) => { ... }
    _ = tokio::time::sleep(timeout) => {
        // write_to_db_atomic either completes fully or not at all
        return Err(Error::Timeout);
    }
}
```

### 6. Send/Sync Bound Violations

Types shared across tasks must be `Send`. Types shared across threads must be `Send + Sync`. `Rc`, `RefCell`, and raw pointers are not `Send`.

```rust
// WON'T COMPILE - Rc is not Send
let data = Rc::new(vec![1, 2, 3]);
tokio::spawn(async move {
    println!("{:?}", data); // Rc is !Send
});

// GOOD - Arc is Send + Sync
let data = Arc::new(vec![1, 2, 3]);
tokio::spawn(async move {
    println!("{:?}", data);
});
```

## `async fn` in Traits (Stable Since 1.75)

Native `async fn` in trait definitions is stable since Rust 1.75. The `async-trait` crate is no longer needed for most use cases.

```rust
// BAD — unnecessary dependency on async-trait (if MSRV >= 1.75)
#[async_trait::async_trait]
trait Service {
    async fn call(&self, req: Request) -> Response;
}

// GOOD — native async fn in trait
trait Service {
    async fn call(&self, req: Request) -> Response;
}
```

**When `async-trait` is still needed**:
- **`dyn Trait`**: Native async traits don't support dynamic dispatch (`dyn Service`). Use `async-trait` or the `trait_variant` crate for object-safe async traits.
- **MSRV < 1.75**: Projects that must compile on older Rust versions.

When reviewing, check whether `async-trait` usage can be replaced with native syntax. The crate adds a heap allocation per call (`Box::pin`), which native async traits avoid.

## Channel Patterns

Choose channels based on communication shape: `mpsc` for back-pressure, `broadcast` for fan-out, `oneshot` for request-response, `watch` for latest-value. Ensure bounded channels are sized to avoid OOM risks with unbounded alternatives.

> For detailed channel patterns, usage examples, and pitfalls, see `beagle-rust:tokio-async-code-review` (references/channels.md).

## Graceful Shutdown

Use `CancellationToken` from `tokio_util` with child tokens for hierarchical shutdown. Combine with `tokio::select!` to listen for cancellation alongside work.

> For full shutdown patterns and cancellation token usage, see `beagle-rust:tokio-async-code-review` (references/task-management.md).

## Review Questions

1. Are there any blocking operations (`std::fs`, `std::net`, `thread::sleep`) in async functions?
2. Are mutex guards dropped before `.await` points?
3. Is `tokio::sync::Mutex` used when locks are held across await points?
4. Are spawned tasks tracked via join handles?
5. Is `select!` used with cancellation-safe futures?
6. Do types shared across tasks satisfy `Send + Sync` bounds?
7. Can `async-trait` be replaced with native `async fn` in traits (MSRV >= 1.75, no `dyn Trait` needed)?

## The Poll Contract — Register Before Checking

A leaf `Future::poll` impl must store the latest `cx.waker()` BEFORE checking whether the resource is ready. If the order is reversed (check first, then store), there is a TOCTOU race: a producer can publish data and call the OLD waker between the check and the store, and the consumer parks holding a waker that will never fire again. The task sleeps forever.

```rust
// WRONG — race window between check and waker store.
fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
    if let Some(v) = self.queue.try_pop() { return Poll::Ready(v); }
    *self.waker.lock() = Some(cx.waker().clone()); // too late
    Poll::Pending
}

// RIGHT — register first, then re-check (spurious wake is harmless).
fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
    *self.waker.lock() = Some(cx.waker().clone());
    if let Some(v) = self.queue.try_pop() { return Poll::Ready(v); }
    Poll::Pending
}
```

Executors are free to construct a fresh `Waker` per `poll`, so caching the first waker forever is also a bug — see `WAKER_NOT_UPDATED_BETWEEN_POLLS`. Compare with `Waker::will_wake` before cloning to skip redundant atomic increments. See [concurrency-primitives.md](concurrency-primitives.md) for the underlying `Arc`/atomic mechanics.

## Pin Wraps a Pointer, Not a Value

`Pin<P>` is always `Pin<P>` where `P` is a pointer type: `Pin<&mut T>`, `Pin<Box<T>>`, `Pin<Arc<T>>`, `Pin<&T>`. The invariant `Pin` enforces is "the memory address of `*P` will not change until `T` is dropped." Wrapping a pointer keeps the pointee in place while the `Pin` itself can move freely. If `Pin` held a `T` by value, moving the `Pin` would move the `T` and break self-references.

The safety surface extends to `P`'s `Deref`, `DerefMut`, and `Drop` impls: if any of them move the pointee via the `&mut self` they receive, the pin invariant is violated from outside an `unsafe` block. Custom smart pointers that intend to be wrapped in `Pin` must keep these impls move-free or document the hazard.

## Box::pin vs std::pin::pin!

| Mechanism | Allocation | Lifetime | When to use |
|-----------|------------|----------|-------------|
| `Box::pin(value)` | heap | `'static` (if value is) | Need to store, return, send across threads, or `spawn` the future. `Pin<Box<T>>` is itself `Unpin`, so you can move the box. |
| `std::pin::pin!(value)` | stack (frame) | local scope | Hot paths where heap allocation matters, `no_std`, short-lived locals. Pinned value cannot outlive its scope. |

`Box` has an unconditional `Unpin` impl: moving a `Box<T>` does not move the `T`. But `Pin<Box<T>>` does NOT let you move a `!Unpin` `T` out — only the box itself. Prefer `pin!` for stack-local futures inside `select!` arms or driver loops to avoid per-iteration allocation.

## Structural vs Non-Structural Pinning

When a struct opts out of `Unpin` (via `PhantomPinned`) and is pinned, each field is either *structurally pinned* — pinning the outer pins this field, projecting `Pin<&mut Self>` to `Pin<&mut Field>` — or *non-structural* — the field can be accessed as plain `&mut Field` and moved out. Pick one per field and stick to it; `Drop` must not move structurally-pinned fields. Hand-rolling this is error-prone; use `pin-project-lite`.

```rust
use std::marker::PhantomPinned;
use pin_project_lite::pin_project;

pin_project! {
    struct SelfRef {
        #[pin] inner: InnerFuture,   // structurally pinned
        counter: u64,                // not structural, freely accessible
        _pin: PhantomPinned,
    }
}
```

Without `PhantomPinned`, a struct of all-`Unpin` fields auto-derives `Unpin` and `Pin` provides zero protection — callers can `Pin::new(&mut x)` and then move it.

## Cancellation Soundness — Drop Equals Cancel

There is no `async Drop`. When an async fn is dropped mid-poll, its generated state machine drops every local currently held across the latest await point, in reverse order of construction. No "cleanup" coroutine runs. A future that has already written half a request and is then dropped (timeout, `select!`, `JoinHandle::abort`) leaves external state in whatever partial form was reached.

Cancel-safety taxonomy for review:

- **Cancel-safe**: futures that hold no "I started but didn't finish" state across `.await`. Examples: `mpsc::Receiver::recv`, `broadcast::Receiver::recv`, `tokio::time::sleep`, `Mutex::lock`, `read` (returns whatever arrived), `accept`.
- **Cancel-unsafe**: futures with internal partial-buffer state that gets dropped. Examples: `AsyncReadExt::read_exact`, `read_to_end`, `read_line`, `AsyncWriteExt::write_all`, HTTP body reads from `reqwest`/`hyper`, anything with a per-call invariant spanning multiple polls.

Defensive pattern for cancel-unsafe work: spawn it onto a detached task and `.await` the `JoinHandle`. The `JoinHandle` future is cancel-safe; the work behind it runs to a clean checkpoint even if the awaiter is cancelled. See [../../tokio-async-code-review/references/pinning-cancellation.md](../../tokio-async-code-review/references/pinning-cancellation.md) for tokio-specific cancellation primitives and [concurrency-models.md](concurrency-models.md) for choosing between channel-driven supervisors and direct spawn.

## Send Propagation Through `.await`

The auto-trait `Send` on the compiler-generated future is decided by every local that is live across any `.await` point. A single non-Send local — `Rc<T>`, `RefCell<T>` (held), `std::sync::MutexGuard<'_, T>` from `std::sync`, a raw pointer, a thread-local handle — downgrades the whole future to `!Send`. `tokio::spawn` then rejects it with an error pointing at the await, not at the offending local.

Fix patterns:

```rust
// BAD — Rc lives across the await; whole future is !Send.
let local = Rc::new(state);
let _ = use_local(&local);
fetch().await;

// GOOD — scope the !Send local so it drops before the await.
{
    let local = Rc::new(state);
    let _ = use_local(&local);
} // Rc dropped here
fetch().await;
```

The same pattern fixes `std::sync::MutexGuard` held across `.await` — scope it. `parking_lot::MutexGuard` is `Send`, which means the compiler does NOT catch the hazard; review for it manually.

## Cross-Runtime Compatibility

A leaf future built against tokio's reactor (e.g. `tokio::net::TcpStream::read`, `tokio::time::sleep`) panics with "there is no reactor running" when polled under `smol`, `async-std`, or `monoio`. For library code that should be runtime-agnostic, depend on `futures` crate primitives (`AsyncRead`, `AsyncWrite`, `Stream`), expose `async fn` or `impl Future` from your public API, and do NOT spawn internally — let the caller's runtime own the task graph. If you must depend on tokio, declare it loudly in the crate docs and gate alternative runtimes behind feature flags.

## Additional Review Checks

- [FILE:LINE] LEAF_POLL_CHECK_BEFORE_REGISTER — `poll` impl checks readiness BEFORE installing `cx.waker()`. Producer can publish + wake in the gap; consumer parks forever. Fix: store waker first, then re-check.
- [FILE:LINE] WAKER_STORED_ONCE_NEVER_REFRESHED — Leaf future stashes the first waker and never updates it. Executor may rebind the task (`FuturesUnordered`, task migration) and produce a fresh waker per `poll`; the cached one wakes nothing. Refresh on every `Pending` return, or compare via `Waker::will_wake`.
- [FILE:LINE] WAKER_CLONED_EVERY_POLL_HOT_PATH — Leaf future calls `cx.waker().clone()` unconditionally each `poll`, even when the previously stored waker would wake the same task. Use `Waker::will_wake(&old, cx.waker())` to skip the atomic increment on hot paths.
- [FILE:LINE] PIN_HOLDS_VALUE_NOT_POINTER — Code constructs `Pin<T>` directly or treats `Pin` as a value wrapper. `Pin` must wrap a pointer type (`&mut T`, `Box<T>`, `Arc<T>`). Likely a misuse of `Pin::new_unchecked` on a non-pointer.
- [FILE:LINE] CUSTOM_SMART_POINTER_MOVES_IN_DEREF — A `Deref`/`DerefMut`/`Drop` impl on a pointer type intended to be wrapped in `Pin` moves the pointee (e.g. via `mem::replace` in `Drop`). Breaks the pin invariant from safe code.
- [FILE:LINE] BOX_PIN_IN_HOT_LOOP — `Box::pin(async { ... })` allocates on the heap every iteration of a polling loop. Replace with `std::pin::pin!` for stack-local pinning unless the future must escape the scope.
- [FILE:LINE] PIN_BOX_USED_TO_MOVE_OUT_OF_T — Code calls `*pin_box` or `mem::replace` on `Pin<Box<T>>` expecting to move `T`. `Box: Unpin` lets you move the box, not the `T` inside. Use `into_inner_unchecked` only with the same justification as `Pin::new_unchecked`.
- [FILE:LINE] STRUCTURAL_PIN_DROP_MOVES_FIELD — A `!Unpin` struct's hand-written `Drop` impl moves a structurally-pinned field (e.g. via `mem::take`). Violates the structural pinning contract — switch to `pin-project-lite` or document why the field isn't structural.
- [FILE:LINE] PIN_PROJECT_MIXED_STRUCTURAL — Same field accessed as both `Pin<&mut Field>` (structural) and `&mut Field` (non-structural) across different methods of an `impl`. Pick one per field. Use `pin-project-lite` to enforce.
- [FILE:LINE] PHANTOMPINNED_MISSING_ON_SELFREF — A struct holds raw pointers or references into its own data but is auto-`Unpin` (all fields are `Unpin`, no `PhantomPinned`). Callers can move it freely via `Pin::new`. Add `_pin: PhantomPinned`.
- [FILE:LINE] ASYNC_DROP_ATTEMPT — A struct's `Drop` impl needs to flush a channel, send a goodbye message, or `.await` cleanup. There is no async `Drop`; the work is silently skipped or blocks the runtime thread. Expose `async fn close(self)` and require callers to invoke it explicitly.
- [FILE:LINE] CANCEL_UNSAFE_IN_SELECT_BRANCH — `tokio::select!` branch holds `read_exact`, `read_to_end`, `read_line`, `write_all`, or an HTTP body read. Cancellation drops partial buffers → silent data loss or wire-protocol corruption. Move the call into a spawned task and select on its `JoinHandle`.
- [FILE:LINE] CRITICAL_WRITE_BEHIND_TIMEOUT — `tokio::time::timeout(d, work)` wraps a write/commit that cannot be undone (DB transaction, file write, network publish). On timeout the work is mid-flight and dropped. Spawn the work and timeout the `JoinHandle` instead.
- [FILE:LINE] NON_SEND_LOCAL_ACROSS_AWAIT — A `Rc<T>`, `RefCell` borrow, raw pointer, thread-local handle, or `std::sync::MutexGuard` is held across an `.await`. The future becomes `!Send` and cannot be spawned on a multi-thread runtime. Scope the local so it drops before the await.
- [FILE:LINE] PARKING_LOT_GUARD_ACROSS_AWAIT — A `parking_lot::MutexGuard` (which is `Send`) is held across `.await`. Compiler does NOT reject the spawn; logic still deadlocks if the resumed task tries to re-acquire the same lock on a different worker thread. Flag manually.
- [FILE:LINE] LIBRARY_HARDCODES_TOKIO_REACTOR — A crate's public `async fn` API internally calls `tokio::net::*`, `tokio::time::sleep`, or `tokio::spawn` without declaring tokio as a hard requirement or gating it behind a feature. Callers on `smol`/`async-std` get a runtime-mismatch panic. Either document loudly or abstract over `AsyncRead + AsyncWrite`.
- [FILE:LINE] INTERNAL_SPAWN_IN_LIBRARY — Library code calls `tokio::spawn` internally, locking callers into tokio and stealing task ownership from the caller's supervisor. Expose `impl Future` and let the caller spawn.

## Cross-References

- [concurrency-primitives.md](concurrency-primitives.md) — `Arc`, atomic ordering, and the synchronization primitives that underpin `Waker` storage and cross-task handoff.
- [concurrency-models.md](concurrency-models.md) — choosing between actor/supervisor models, channel-driven concurrency, and shared-state mutexes for cancel-safe designs.
- [../../tokio-async-code-review/references/pinning-cancellation.md](../../tokio-async-code-review/references/pinning-cancellation.md) — tokio-specific cancellation primitives (`CancellationToken`, `JoinSet`, `select!` semantics, `spawn_blocking` bridge).
