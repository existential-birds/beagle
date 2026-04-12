# Sync Primitives

## Choosing the Right Primitive

| Need | Primitive | Notes |
|------|-----------|-------|
| Exclusive access to data | `Mutex<T>` | `tokio::sync` if held across await; `std::sync` for short sections |
| Read-heavy, write-rare access | `RwLock<T>` | Multiple concurrent readers, exclusive writers |
| Limit concurrent operations | `Semaphore` | Rate limiting, connection pooling |
| Signal one waiter | `Notify` | Lightweight, no data transfer |
| Signal all waiters | `Notify` + `notify_waiters()` | Broadcast wake-up |
| One-time initialization | `OnceCell` / `tokio::sync::OnceCell` | Lazy static-like patterns |
| Lazy static values | `std::sync::LazyLock` | Replaces `once_cell::sync::Lazy` and `lazy_static!` (stable 1.80) |

## tokio::sync::Mutex vs std::sync::Mutex

**Use `tokio::sync::Mutex` when:**
- Lock is held across `.await` points
- Lock contention is high and you don't want to block a runtime thread
- The protected section does async I/O

**Use `std::sync::Mutex` when:**
- Critical section is short and contains no `.await`
- You need `Send + Sync` without `async` overhead
- Performance matters and the lock is rarely contended

```rust
// std::sync::Mutex — good for fast, non-async access
use std::sync::Mutex;
struct Counter(Mutex<u64>);

impl Counter {
    fn increment(&self) {
        let mut count = self.0.lock().unwrap();
        *count += 1;
        // guard dropped immediately — no await in between
    }
}

// tokio::sync::Mutex — needed when holding across await
use tokio::sync::Mutex;
struct Cache(Mutex<HashMap<String, Data>>);

impl Cache {
    async fn get_or_fetch(&self, key: &str) -> Data {
        let mut cache = self.0.lock().await;
        if let Some(data) = cache.get(key) {
            return data.clone();
        }
        // CAUTION: holding lock across await
        let data = fetch(key).await;
        cache.insert(key.to_owned(), data.clone());
        data
    }
}
```

## Semaphore

Limits the number of concurrent operations. Useful for connection pools, rate limiting, and resource management.

```rust
use tokio::sync::Semaphore;
use std::sync::Arc;

let semaphore = Arc::new(Semaphore::new(10)); // max 10 concurrent

for item in items {
    let permit = semaphore.clone().acquire_owned().await.unwrap();
    tokio::spawn(async move {
        process(item).await;
        drop(permit); // explicitly release, or let it drop
    });
}
```

For try-acquire (non-blocking):

```rust
match semaphore.try_acquire() {
    Ok(permit) => { /* proceed */ }
    Err(_) => { /* at capacity, back off */ }
}
```

## RwLock

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

**Watch for writer starvation:** if readers never release, writers wait forever. tokio's `RwLock` is write-preferring by default to mitigate this.

## LazyLock (Rust 1.80+)

`std::sync::LazyLock` (stable since 1.80) replaces the `once_cell` and `lazy_static` crates for runtime-initialized global singletons. In async/tokio code, this is commonly used for shared clients, connection info, or regex patterns.

```rust
// BAD - external dependency no longer needed
use once_cell::sync::Lazy;
static CLIENT: Lazy<reqwest::Client> = Lazy::new(|| {
    reqwest::Client::builder().timeout(Duration::from_secs(30)).build().unwrap()
});

// BAD - macro-based, also superseded
lazy_static::lazy_static! {
    static ref CLIENT: reqwest::Client = reqwest::Client::builder()
        .timeout(Duration::from_secs(30))
        .build()
        .unwrap();
}

// GOOD (edition 2024) - std library, no external crate
use std::sync::LazyLock;
static CLIENT: LazyLock<reqwest::Client> = LazyLock::new(|| {
    reqwest::Client::builder().timeout(Duration::from_secs(30)).build().unwrap()
});
```

For single-threaded or non-Sync contexts, use `std::cell::LazyCell` instead.

**Note:** `tokio::sync::OnceCell` is still preferred when the initialization itself is async (requires `.await`), since `LazyLock` only supports synchronous initialization closures.

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
