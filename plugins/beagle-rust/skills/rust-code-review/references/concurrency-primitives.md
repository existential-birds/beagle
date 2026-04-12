# Concurrency Primitives

For async-specific patterns (tokio, channels, cancellation), see [async-concurrency.md](async-concurrency.md).

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
2. **Lock held across await**: `MutexGuard` alive at `.await` point (see async-concurrency.md)
3. **Incorrect `Send`/`Sync`**: manual implementations missing generic bounds
4. **TOCTOU (time-of-check-to-time-of-use)**: checking a condition then acting on it without holding the lock
5. **Forgetting to join spawned threads**: fire-and-forget threads with `thread::spawn` may outlive the data they reference
6. **`compare_exchange` without loop**: CAS can spuriously fail on some architectures — use `compare_exchange_weak` in a loop for better performance

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
