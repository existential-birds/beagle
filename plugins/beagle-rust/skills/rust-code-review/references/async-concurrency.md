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
