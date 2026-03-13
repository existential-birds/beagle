---
name: tokio-async-code-review
description: Reviews tokio async runtime usage for task management, sync primitives, channel patterns, and runtime configuration. Use when reviewing Rust code that uses tokio, async/await patterns, spawn, channels, or async synchronization. Also covers tokio-util, tower, and hyper integration patterns.
---

# Tokio Async Code Review

## Review Workflow

1. **Check Cargo.toml** — Note tokio feature flags (`full`, `rt-multi-thread`, `macros`, `sync`, etc.). Missing features cause confusing compile errors.
2. **Check runtime setup** — Is `#[tokio::main]` or manual runtime construction used? Multi-thread vs current-thread?
3. **Scan for blocking** — Search for `std::fs`, `std::net`, `std::thread::sleep`, CPU-heavy loops in async functions.
4. **Check channel usage** — Match channel type to communication pattern (mpsc, broadcast, oneshot, watch).
5. **Check sync primitives** — Verify correct mutex type, proper guard lifetimes, no deadlock potential.

## Output Format

Report findings as:

```text
[FILE:LINE] ISSUE_TITLE
Severity: Critical | Major | Minor | Informational
Description of the issue and why it matters.
```

## Quick Reference

| Issue Type | Reference |
|------------|-----------|
| Task spawning, JoinHandle, structured concurrency | [references/task-management.md](references/task-management.md) |
| Mutex, RwLock, Semaphore, Notify, Barrier | [references/sync-primitives.md](references/sync-primitives.md) |
| mpsc, broadcast, oneshot, watch channel patterns | [references/channels.md](references/channels.md) |

## Review Checklist

### Runtime Configuration
- [ ] Tokio features in Cargo.toml match actual usage
- [ ] Runtime flavor matches workload (`multi_thread` for I/O-bound, `current_thread` for simpler cases)
- [ ] `#[tokio::test]` used for async tests (not manual runtime construction)
- [ ] Worker thread count configured appropriately for production

### Task Management
- [ ] `spawn` return values (`JoinHandle`) are tracked, not silently dropped
- [ ] `spawn_blocking` used for CPU-heavy or synchronous I/O operations
- [ ] Tasks respect cancellation (via `CancellationToken`, `select!`, or shutdown channels)
- [ ] `JoinError` (task panic or cancellation) is handled, not just unwrapped
- [ ] `tokio::select!` branches are cancellation-safe

### Sync Primitives
- [ ] `tokio::sync::Mutex` used when lock is held across `.await`; `std::sync::Mutex` for short non-async sections
- [ ] No mutex guard held across await points (deadlock risk)
- [ ] `Semaphore` used for limiting concurrent operations (not ad-hoc counters)
- [ ] `RwLock` used when read-heavy workload (many readers, infrequent writes)
- [ ] `Notify` used for simple signaling (not channel overhead)

### Channels
- [ ] Channel type matches pattern: mpsc for back-pressure, broadcast for fan-out, oneshot for request-response, watch for latest-value
- [ ] Bounded channels have appropriate capacity (not too small = deadlock, not too large = memory)
- [ ] `SendError` / `RecvError` handled (indicates other side dropped)
- [ ] Broadcast `Lagged` errors handled (receiver fell behind)
- [ ] Channel senders dropped when done to signal completion to receivers

### Timer and Sleep
- [ ] `tokio::time::sleep` used instead of `std::thread::sleep`
- [ ] `tokio::time::timeout` wraps operations that could hang
- [ ] `tokio::time::interval` used correctly (`.tick().await` for periodic work)

## Severity Calibration

### Critical
- Blocking I/O (`std::fs::read`, `std::net::TcpStream`) in async context without `spawn_blocking`
- Mutex guard held across `.await` point (deadlock potential)
- `std::thread::sleep` in async function (blocks runtime thread)
- Unbounded channel where back-pressure is needed (OOM risk)

### Major
- `JoinHandle` silently dropped (lost errors, zombie tasks)
- Missing `select!` cancellation safety consideration
- Wrong mutex type (std vs tokio) for the use case
- Missing timeout on network/external operations

### Minor
- `tokio::spawn` for trivially small async blocks (overhead > benefit)
- Overly large channel buffer without justification
- Manual runtime construction where `#[tokio::main]` suffices
- `std::sync::Mutex` where contention is high enough to benefit from tokio's async mutex

### Informational
- Suggestions to use `tokio-util` utilities (e.g., `CancellationToken`)
- Tower middleware patterns for service composition
- Structured concurrency with `JoinSet`

## Valid Patterns (Do NOT Flag)

- **`std::sync::Mutex` for short critical sections** — tokio docs recommend this when no `.await` is inside the lock
- **`tokio::spawn` without explicit join** — Valid for background tasks with proper shutdown signaling
- **Unbuffered channel capacity of 1** — Valid for synchronization barriers
- **`#[tokio::main(flavor = "current_thread")]` in simple binaries** — Not every app needs multi-thread runtime
- **`clone()` on `Arc<T>` before `spawn`** — Required for moving into tasks, not unnecessary cloning
- **Large broadcast channel capacity** — Valid when lagged errors are expensive (event sourcing)

## Before Submitting Findings

Load and follow `beagle-rust:review-verification-protocol` before reporting any issue.
