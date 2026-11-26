# Pinning, Cancellation, and Async Internals

## Pin<P<T>> Semantics

`Pin<P>` wraps a pointer type `P` (e.g., `&mut T`, `Box<T>`) and guarantees the target `T` will not move after being pinned. Required for self-referential types like async state machines, where internal references would be invalidated by a move.

- `Pin::new_unchecked()` is unsafe -- caller must guarantee the referent won't move
- `get_unchecked_mut()` is unsafe -- caller must not move `T` through the returned `&mut T`
- `Pin` always implements `Deref<Target = T>` safely (shared refs can't move `T`)
- **When required**: Futures from `async fn`/blocks (self-referential across `.await` points), any struct storing data and pointers into that data

### Unpin Trait

`Unpin` is an auto-trait indicating a type is safe to move out of a `Pin`. Most standard types are `Unpin`. Compiler-generated futures from `async` blocks are `!Unpin`.

```rust
// Unpin types can use the safe Pin::new constructor
let mut fut = ready(42);
let pinned = Pin::new(&mut fut); // safe, ready() is Unpin

// !Unpin types require heap or stack pinning
let fut = async { do_work().await };
let pinned = Box::pin(fut); // heap pinning, always safe
```

## Stack vs Heap Pinning

**`Box::pin(value)`** (heap): Always safe. Allocates on the heap, so the `Pin` can move freely without moving `T`.

**`std::pin::pin!(value)`** (stack, stable since 1.68): Avoids heap allocation. Pins the value to the current stack frame via variable shadowing.

```rust
use std::pin::pin;

// GOOD - stack pinning with std::pin::pin! (stable 1.68+)
let fut = pin!(async { long_running().await });
fut.await;

// GOOD - heap pinning when you need to store or move the pinned future
let fut = Box::pin(async { long_running().await });
tokio::spawn(fut);
```

Flag when: `pin_mut!` from `pin-utils` or `futures` crate is used instead of `std::pin::pin!` on Rust 1.68+.

## Future Trait Internals

The actual `Future` trait requires pinning and a waker context:

```rust
trait Future {
    type Output;
    fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output>;
}
```

- **`Poll::Pending`**: Future cannot make progress. Must arrange for `cx.waker().wake()` to be called when progress is possible.
- **`Poll::Ready(T)`**: Future has resolved. Do not poll again (may panic).
- **Waker contract**: If `poll` returns `Pending`, the future must ensure `wake()` is called eventually. Leaf futures store the waker where the event source can trigger it.

## Executor Model

Executors manage tasks (top-level futures) and decide which to poll when wakers fire.

- **Work-stealing (tokio multi-thread)**: Multiple threads share a task queue. Idle threads steal work from busy ones. Good for I/O-bound workloads with many tasks.
- **Single-threaded (tokio current_thread)**: One thread polls all tasks. No `Send` requirement on futures. Simpler, lower overhead, but no parallelism.

Check for: Blocking operations in async context. A future that runs >1ms without yielding `Pending` starves other tasks on the same executor thread.

## Stream Trait (Async Iteration)

`Stream` (from `futures` crate) is the async equivalent of `Iterator`, with `poll_next(self: Pin<&mut Self>, cx: &mut Context) -> Poll<Option<Self::Item>>`.

**Use `Stream` when**: Producing a sequence of values from a single source (file chunks, database rows, transformed events).

**Use channels when**: Multiple producers need to send to one consumer, or you need back-pressure across task boundaries.

Valid pattern: `tokio_stream::StreamExt` for combinators like `.map()`, `.filter()`, `.throttle()` on streams.

## Cancellation Patterns

### Drop as Cancellation

Dropping a future cancels it. This is fundamental to how `tokio::select!` works: unselected branches are dropped.

```rust
// Dropping the JoinHandle does NOT cancel the task (it detaches)
let handle = tokio::spawn(work());
drop(handle); // task keeps running!

// To cancel a spawned task, call abort()
let handle = tokio::spawn(work());
handle.abort(); // task is cancelled
```

### CancellationToken + Graceful Shutdown

Hierarchical cancellation for coordinated shutdown. Child tokens cancel when parents do. Combine with `JoinSet` for clean drain.

```rust
use tokio_util::sync::CancellationToken;

let token = CancellationToken::new();
let mut set = JoinSet::new();

for worker in workers {
    let child = token.child_token();
    set.spawn(async move {
        tokio::select! {
            _ = child.cancelled() => worker.drain().await,
            _ = worker.run() => {}
        }
    });
}

// On SIGTERM: cancel parent, then drain all tasks
token.cancel();
while let Some(result) = set.join_next().await {
    result.expect("worker panicked");
}
```

## select! Deep Semantics

- **Branch priority**: When multiple branches are ready simultaneously, `tokio::select!` picks one randomly by default. Use `biased;` to evaluate top-to-bottom.
- **Cancellation safety**: Unselected branches are dropped. A future is cancellation-safe if dropping it at any `.await` point doesn't lose data.

```rust
// RISKY - read_exact buffers internally, partial reads lost on cancel
tokio::select! {
    result = reader.read_exact(&mut buf) => { ... }
    _ = token.cancelled() => { return; }
}

// SAFER - use cancellation-safe recv()
tokio::select! {
    msg = rx.recv() => { ... }
    _ = token.cancelled() => { return; }
}
```

Flag when: `read_exact`, `read_to_end`, or custom buffering futures appear in `select!` branches without cancellation safety analysis.

## Blocking Bridge

| Situation | Use | Why |
|-----------|-----|-----|
| CPU-heavy or sync I/O from async context | `spawn_blocking` | Runs on dedicated blocking thread pool, won't starve async workers |
| Already on a tokio runtime thread, need to block briefly | `block_in_place` | Converts current thread to blocking temporarily, avoids extra thread spawn |
| Need to run async code from sync context | `Handle::block_on` | Blocks current thread until the future completes |

```rust
// spawn_blocking: preferred for most blocking work
let hash = tokio::task::spawn_blocking(move || {
    compute_hash(&data)
}).await?;

// block_in_place: only on multi-thread runtime, avoids thread pool queue
tokio::task::block_in_place(|| {
    std::fs::write(path, &data)?;
    Ok::<_, std::io::Error>(())
})?;
```

Flag when: `block_in_place` is used on `current_thread` runtime (it will panic).

## Memory Ordering in Async Context

Async task scheduling provides happens-before relationships:

- `tokio::spawn` establishes happens-before between the spawning code and the spawned task's first poll
- `.await` on a `JoinHandle` establishes happens-before between the task's completion and the awaiting code
- Waker mechanics ensure proper ordering between `wake()` calls and subsequent `poll()`

When using atomics across async tasks, `Ordering::Relaxed` is usually sufficient for simple counters and flags, because task scheduling already provides synchronization. Use `Acquire`/`Release` only when you need ordering guarantees beyond what the runtime provides (e.g., custom lock-free structures shared across tasks).

## Review Questions

1. Are `!Unpin` futures pinned correctly before polling (via `Box::pin` or `std::pin::pin!`)?
2. Are futures held across `.await` points reviewed for size (large futures = excessive memcpy)?
3. Is cancellation handled explicitly (CancellationToken, abort, or select) for long-running tasks?
4. Are `select!` branches cancellation-safe, or is data loss possible on cancel?
5. Is `spawn_blocking` used for blocking work instead of running it directly in async context?
6. Is `block_in_place` avoided on `current_thread` runtime?
7. Are dropped `JoinHandle`s intentional (detached tasks) or accidental (lost errors)?
