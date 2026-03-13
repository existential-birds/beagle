# Task Management

## Spawning Tasks

### tokio::spawn

Creates an independent task on the runtime. The spawned future must be `Send + 'static`.

```rust
// Basic spawn with error handling
let handle = tokio::spawn(async move {
    process(data).await
});

match handle.await {
    Ok(Ok(result)) => tracing::info!(?result, "task completed"),
    Ok(Err(e)) => tracing::error!(error = %e, "task failed"),
    Err(e) => tracing::error!(error = %e, "task panicked"),
}
```

### tokio::spawn_blocking

Runs a closure on a dedicated thread pool for blocking operations. Returns a `JoinHandle` like `spawn`.

```rust
// CPU-heavy work belongs on blocking threads
let hash = tokio::task::spawn_blocking(move || {
    argon2::hash_password(&password, &salt)
}).await??;

// Synchronous file I/O
let contents = tokio::task::spawn_blocking(move || {
    std::fs::read_to_string(path)
}).await??;
```

### JoinSet for Structured Concurrency

`JoinSet` manages a group of tasks with collective lifecycle control. Preferred over tracking individual `JoinHandle`s when spawning dynamic numbers of tasks.

```rust
use tokio::task::JoinSet;

let mut set = JoinSet::new();
for item in items {
    set.spawn(async move {
        process(item).await
    });
}

// Collect all results
while let Some(result) = set.join_next().await {
    match result {
        Ok(Ok(value)) => results.push(value),
        Ok(Err(e)) => tracing::warn!(error = %e, "task failed"),
        Err(e) => tracing::error!(error = %e, "task panicked"),
    }
}
```

When a `JoinSet` is dropped, all tasks in it are cancelled (aborted). This provides automatic cleanup.

## Cancellation

### CancellationToken (tokio-util)

Hierarchical cancellation for structured shutdown. Child tokens are cancelled when parents are.

```rust
use tokio_util::sync::CancellationToken;

let token = CancellationToken::new();

// Worker respects cancellation
let child = token.child_token();
tokio::spawn(async move {
    loop {
        tokio::select! {
            _ = child.cancelled() => break,
            item = rx.recv() => {
                if let Some(item) = item {
                    process(item).await;
                }
            }
        }
    }
});

// On shutdown:
token.cancel(); // cancels all children
```

### select! Cancellation Safety

When `tokio::select!` resolves one branch, other branches are dropped. A future is cancellation-safe if dropping it at any `.await` point doesn't lose data.

**Cancellation-safe operations:**
- `tokio::sync::mpsc::Receiver::recv()`
- `tokio::sync::oneshot::Receiver::recv()`
- `tokio::time::sleep()`
- `tokio::io::AsyncReadExt::read()` (data goes to caller's buffer)

**NOT cancellation-safe:**
- `tokio::io::AsyncReadExt::read_exact()` — partial reads are lost
- Custom futures that do internal buffering

```rust
// RISKY - read_exact may partially fill buffer then get cancelled
tokio::select! {
    result = reader.read_exact(&mut buf) => { ... }
    _ = cancel.cancelled() => { return; }
}

// SAFER - use read() and handle partial reads manually
tokio::select! {
    result = reader.read(&mut buf) => { ... }
    _ = cancel.cancelled() => { return; }
}
```

## Review Questions

1. Are all `JoinHandle`s either awaited, stored, or deliberately dropped with comment?
2. Is `spawn_blocking` used for CPU-heavy or synchronous I/O work?
3. Are task groups managed with `JoinSet` instead of manual handle tracking?
4. Is cancellation implemented via `CancellationToken` or equivalent?
5. Are `select!` branches cancellation-safe?
