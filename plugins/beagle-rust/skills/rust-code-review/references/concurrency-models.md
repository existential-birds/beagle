# Concurrency Models

Concurrency is a design decision, not a tactical choice. Pick the model — shared memory, worker pool, or actor — *before* reaching for primitives, then let the model dictate which primitives belong. Jon Gjengset's framing: most concurrency bugs come from accidentally mixing two models in one design. This file covers model selection and the review hazards specific to each. For primitive-level review (Mutex vs RwLock, atomics, UnsafeCell, OnceLock/LazyLock), see [concurrency-primitives.md](concurrency-primitives.md). For ordering semantics, see [memory-ordering.md](memory-ordering.md). For async-specific patterns, see [async-concurrency.md](async-concurrency.md) and [../../tokio-async-code-review/SKILL.md](../../tokio-async-code-review/SKILL.md).

## Shared memory model

Threads cooperate by reading and writing common memory protected by mutexes, RW-locks, or atomics.

**Valid when:** workload accesses small shared state from many threads (cache, counter, config, in-memory registry); critical sections are short (microseconds); updates are non-commutative (`f(g(s)) != g(f(s))`).

**Dangerous when:** the critical section holds I/O, network calls, allocator pressure, or unbounded work; a lock is held across `.await` on an async runtime (deadlocks the executor); one lock guards composite state where independent fields are touched by independent code paths.

**Review questions:** who holds the lock? for how long is it held in the worst case? is the critical section measured, or assumed-short? could this be an `AtomicX`, `arc-swap`, or a sharded design instead? `Mutex` (mutual exclusion, ~40 bytes on Linux), `RwLock` (read-heavy only — writer overhead exceeds `Mutex` if writes are frequent), or `parking_lot` variants (smaller, faster, fair) — which tradeoff is the code actually paying for?

The deadly shape in async code is a sync mutex held across `.await`:

```rust
// BAD: std::sync::Mutex guard alive across .await.
let mut g = state.lock().unwrap();
g.pending += 1;
let row = db.fetch(g.id).await?; // executor may suspend with guard held
g.cache.insert(row.key, row);

// GOOD: drop the guard first, or use tokio::sync::Mutex.
let id = { let g = state.lock().unwrap(); g.id };
let row = db.fetch(id).await?;
state.lock().unwrap().cache.insert(row.key, row);
```

## Worker pool model

N identical threads (or tasks) pull jobs from a shared queue and execute them independently. Every worker runs the same code; jobs differ only in data. Web servers, `rayon` parallel iterators, `tokio` multi-threaded runtime, DB connection pools.

**Valid when:** CPU-bound work that partitions cleanly (rayon, `crossbeam-channel` + threads, `tokio::task::spawn_blocking`); I/O multiplexing on a fixed pool; resource pooling (DB connections, HTTP clients) with N established handles.

**Dangerous when:** the queue is unbounded (producer outruns workers → OOM); tasks hold per-thread state that breaks when reassigned (rayon work-stealing moves tasks between threads); connection pool sized smaller than concurrent users without explicit backpressure plan; worker code branches on `thread::current().id()` or a worker index (that is an actor-shaped design wearing a pool's clothes); connections returned with open transactions, session variables, or warm prepared-statement caches.

**Review questions:** pool size and how it was chosen? queue bounded? backpressure strategy when full (block, drop, error)? does any task hold thread-local state? are pooled resources reset between borrows? is the queue itself a single MPSC bottleneck (consider work-stealing deques per worker)?

## Actor model

N independent inboxes, one per "topic" of state. Each actor owns its data exclusively; communication is messages. No locks needed inside an actor — exclusivity is structural.

**Valid when:** state is naturally encapsulated per-thing (per-connection, per-user, per-document, per-device-driver); messages are small and infrequent; cross-actor coordination is rare. Often combined with a worker pool: each actor maps to a tokio task, the pool polls tasks, exclusivity holds because only one task body runs at a time.

**Dangerous when:** message rate is high (the channel becomes the bottleneck); actors send to each other in cycles (deadlock or unbounded mailbox growth); one actor grows hot and serializes the entire workload (cannot parallelize *within* an actor); the design re-implements an actor framework (Actix and friends) for state where plain shared memory would have been simpler; cross-actor invariants are required (no atomicity guarantee across actor boundaries).

**Canonical pattern:** `mpsc::channel` to the actor for commands, `oneshot::Sender` embedded in the message for the reply. Rich `enum Msg { Get(K, oneshot::Sender<V>), Set(K, V) }` reads clearly; `Box<dyn FnOnce()>` hides what the actor does.

```rust
enum Msg { Get(Key, oneshot::Sender<Val>), Set(Key, Val) }

async fn actor(mut rx: mpsc::Receiver<Msg>) {
    let mut state = HashMap::new();
    while let Some(msg) = rx.recv().await {
        match msg {
            Msg::Get(k, tx) => { let _ = tx.send(state.get(&k).cloned().unwrap_or_default()); }
            Msg::Set(k, v) => { state.insert(k, v); }
        }
    }
}
```

## Async vs threads vs hybrid

The decision tree:

- Mostly I/O-bound, many concurrent waits → async (per-task overhead in bytes, not KB).
- Mostly CPU-bound, parallel speedup needed → threads or `rayon`.
- Mixed (I/O handler that occasionally crunches data) → async runtime + `tokio::task::spawn_blocking` for the CPU section.

**Async is not parallelism.** `async fn` on a single-threaded runtime gives interleaving, not speedup. `tokio::join!` polls all its futures *on the same task* — concurrent on one thread, never parallel. Only `tokio::spawn` (or equivalent) hands a future to the runtime as a distinct task that the multi-threaded runtime can poll on another worker. Two conditions for actual parallelism: (1) the future is `Send`, and (2) the work is split into multiple `spawn`ed tasks.

```rust
// BAD: concurrent on one task, never parallel.
let (a, b) = tokio::join!(crunch(x), crunch(y));

// GOOD: each task can land on a separate worker.
let ha = tokio::spawn(crunch(x));
let hb = tokio::spawn(crunch(y));
let (a, b) = (ha.await?, hb.await?);
```

## Data race vs race condition

These are not synonyms.

- **Data race** = two threads access the same memory, at least one writes, with no synchronization. Always UB in Rust. The borrow checker prevents data races in safe code.
- **Race condition** = observable behavior depends on thread scheduling. Not UB, not always a bug, but a frequent source of business-logic defects. Safe code can still have race conditions.

A `Mutex` resolves data races (synchronization established) but not race conditions (logic still depends on order of locking). The classic TOCTOU shape: `if map.lock().contains_key(&k) { map.lock().get(&k).unwrap() }` — the lock is released between the check and the use; another thread may remove `k` in the window. Use `entry()` to fuse check-and-act under one lock.

## CAS as hardware mutex

`compare_exchange` on a single atomic location looks lock-free, but under MESI the cache line still requires exclusive ownership for the duration of the CAS. Under N-CPU contention on one hot atomic, *coordination* scales quadratically in N. Splitting one contended atomic into N less-contended atomics is almost always a better optimization than tuning the ordering.

`fetch_add`, `fetch_sub`, `fetch_and`, `fetch_or` are preferable to `compare_exchange` *when the operation commutes*. They run unconditionally, no retry loop, and have dedicated hardware fast paths (`LDADD` on ARM, `LOCK XADD` on x86). `fetch_update` is **not** in this family — it is implemented as a `compare_exchange_weak` loop. Review questions: is this CAS loop on a hot atomic? would `fetch_add`/`fetch_or` do? could this counter be sharded per-thread with periodic summation?

## The `println!` heisenbug

`Stdout` holds a `Mutex`. Adding `println!` to investigate a race **changes** the race — the print's lock and milliseconds-scale latency dwarf the race window. Reviewer instinct: when a flaky test "fixes itself" once `dbg!` or `println!` is added, the bug is still there, just hidden. Use a per-thread in-memory log printed after the bug triggers, `tracing` with a low-overhead subscriber, `rr` on Linux, or `loom`/TSan, all of which observe without reshaping timing.

## Review checks

- `[FILE:LINE] WRONG_MODEL_FOR_WORKLOAD` — shared-memory `Mutex<HashMap>` used where each entry is independent and naturally per-actor. Convert to actor-per-key or DashMap.
- `[FILE:LINE] LOCK_ACROSS_AWAIT` — `std::sync::Mutex` guard alive at a `.await` point. Drop guard before await, or switch to `tokio::sync::Mutex`.
- `[FILE:LINE] LOCK_WRAPS_IO` — critical section holds the lock across a network/DB/filesystem call. Restructure to release before I/O, or stage I/O outside the lock.
- `[FILE:LINE] LOCK_GUARDS_INDEPENDENT_STATE` — single `Mutex` wraps a struct whose fields are touched by independent code paths. Split or shard.
- `[FILE:LINE] UNBOUNDED_WORKER_QUEUE` — `mpsc::unbounded_channel()` or `VecDeque` feeding a worker pool with no backpressure. Bound it and define overflow behavior.
- `[FILE:LINE] WORKER_POOL_BRANCHES_ON_TID` — worker code selects behavior on `thread::current().id()` or worker index. The actor model fits; convert.
- `[FILE:LINE] CONNECTION_POOL_NO_RESET` — pooled connection returned without resetting transaction state, session variables, or prepared-statement cache.
- `[FILE:LINE] CONNECTION_POOL_UNDERSIZED` — pool size < expected concurrent users with no documented backpressure or queue-wait budget.
- `[FILE:LINE] UNBOUNDED_ACTOR_MAILBOX` — `mpsc::unbounded_channel()` feeding an actor with no backpressure. Bound it or document why infinite buffering is safe.
- `[FILE:LINE] ACTOR_HOLDS_AWAIT_ON_SHARED` — actor task awaits external I/O while exclusively holding state others want to query. Spawn the I/O as a sub-task and return a future, or shard the actor.
- `[FILE:LINE] ACTOR_CYCLIC_SEND` — actor A sends to B which sends back to A on the same call path. Deadlock or unbounded queue growth; restructure to one-way or use `oneshot` reply channels.
- `[FILE:LINE] JOIN_INSTEAD_OF_SPAWN_FOR_PARALLELISM` — `tokio::join!(a, b)` where the intent was parallelism. `join!` polls both on one task; use `tokio::spawn` for each then await the handles.
- `[FILE:LINE] CHECK_THEN_ACT_ON_LOCKED_MAP` — `if !map.lock().contains_key(k) { map.lock().insert(k, v); }`. Lock dropped between read and write. Use `entry`.
- `[FILE:LINE] CAS_LOOP_FOR_COMMUTATIVE_OP` — `compare_exchange_weak` loop computing a commutative op (counter, OR-mask of flags). Replace with `fetch_add`/`fetch_or`.
- `[FILE:LINE] FETCH_UPDATE_AS_FAST_PATH` — `fetch_update` used in hot-path code under the assumption it is a hardware fast path. It is a CAS loop. If the op commutes, use `fetch_add`/`fetch_or`.
- `[FILE:LINE] CONCURRENCY_DEBUG_VIA_PRINTLN` — `println!` added to investigate a race. The print's `Stdout` mutex reshapes timing and may mask the bug. Use in-memory logging, `tracing`, `rr`, or `loom`.

## Anti-patterns

- **Mixing models in one design.** A worker pool whose tasks reach into shared mutable state without going through the queue. An actor that also holds a `Mutex` "for the hot path." Pick one model per subsystem and stay inside it.
- **One giant `Future` that you expect to run in parallel.** Without `spawn`, it is one task; the runtime cannot poll one future from two threads.
- **`std::sync::Mutex` in async code held across `.await`.** Either use the async mutex or drop the guard before the await point.
- **One `Mutex` over composite state.** Almost always becomes a contention bottleneck. Split by sub-state or shard by key.
- **Unbounded channels as the default.** Lose backpressure and produce silent OOM under load. Bound everything; raise the bound after measurement.
- **Actor for everything.** When messages are high-rate and state is small, the channel becomes the bottleneck. Shared memory with a short critical section is faster.
- **Lock-free for the sake of lock-free.** Hand-rolled atomic algorithms usually scale worse than a well-placed `Mutex` until benchmarks prove otherwise. Start with locks; optimize on evidence.
- **Adding `println!` to debug races.** Stdout's lock and latency change the very interleavings being investigated.
