# Lock-Free Patterns: Hand-Rolled Concurrency Review

For high-level primitive selection (Mutex vs RwLock vs Atomics) and `Send`/`Sync` bounds, see [concurrency-primitives.md](concurrency-primitives.md). For deep dives on `Ordering` and happens-before reasoning, see [memory-ordering.md](memory-ordering.md). For verifying hand-rolled primitives with `loom` and Miri, see [../../rust-testing-code-review/references/concurrency-testing.md](../../rust-testing-code-review/references/concurrency-testing.md).

This reference distills Chapters 4–9 of Mara Bos's *Rust Atomics and Locks* into reviewer-actionable patterns for spinlocks, channels, `Arc`, CAS loops, seqlocks, mutexes, and condvars.

## When to Hand-Roll (and when not to)

The first review question for any hand-rolled concurrency primitive is **"why isn't this an existing crate?"**. The community-maintained alternatives below are battle-tested across architectures and have shipped years of bug fixes you do not want to re-encounter:

| Need | Reach for |
|------|-----------|
| Mutual exclusion (sync) | `std::sync::Mutex` or `parking_lot::Mutex` |
| Mutual exclusion (async, held across `.await`) | `tokio::sync::Mutex` |
| MPMC channel | `crossbeam::channel` |
| MPSC channel (async) | `tokio::sync::mpsc` |
| Read-mostly snapshot | `arc-swap::ArcSwap` |
| Shared mutable map | `dashmap::DashMap` or `flurry::HashMap` |
| Lock-free reclamation | `crossbeam-epoch`, `haphazard`, `seize` |
| Wait-free queue | `crossbeam-queue::ArrayQueue`, `concurrent-queue` |

**Legitimate reasons to hand-roll**:

1. **Profiling shows a std primitive is the bottleneck** — and you have benchmarks proving the hand-rolled replacement actually wins on your workload, on every target architecture you ship.
2. **The primitive does not exist in any crate** — e.g., a wait-free SPSC ring with a specific memory layout, a fixed-size lock-free freelist with bounded latency.
3. **`no_std` or kernel context** — `std::sync` is unavailable.

**Never legitimate**:

- "Locks are slow" without a profile.
- "I wanted to learn how it works" in production code — implement it in a scratch crate, link tests, then use the upstream crate.
- "Our code is simple enough that we don't need `crossbeam-epoch`" — pointer-based lock-free code without reclamation is almost always wrong.

**Loud rule**: hand-rolling concurrency without `loom` interleavings *and* `cargo +nightly miri test` is a reviewer-blocker. The bug rate on hand-rolled atomics is high enough that "it passes `cargo test` on x86" is not evidence of correctness. See [../../rust-testing-code-review/references/concurrency-testing.md](../../rust-testing-code-review/references/concurrency-testing.md) for the required test harness.

- `[FILE:LINE] HAND_ROLLED_LOCK_NO_JUSTIFICATION` — `unsafe impl Sync` on a struct wrapping `AtomicBool` + `UnsafeCell` (or `AtomicPtr` + custom drop) with no comment naming the specific upstream primitive considered and rejected.
- `[FILE:LINE] HAND_ROLLED_LOCK_NO_LOOM` — Hand-rolled lock-free type with no `cfg(loom)` test module.
- `[FILE:LINE] HAND_ROLLED_LOCK_NO_MIRI` — Hand-rolled lock-free type with no Miri-runnable test (no test, or all atomic tests carry `#[cfg_attr(miri, ignore)]`).

## Spinlocks

A minimal spinlock pairs `AtomicBool` (the lock state) with `UnsafeCell<T>` (the protected data). The whole correctness story is:

- `swap(true, Acquire)` on lock — `Acquire` so the critical section observes prior `Release` unlocks.
- `store(false, Release)` on unlock — `Release` so the critical section's writes publish.
- `unsafe impl<T: Send> Sync for SpinLock<T> {}` — bound is `T: Send`, not `Sync`, because only one thread accesses `T` at a time (ownership transfers across threads via the lock handoff).
- `unsafe impl<T: Sync> Sync for Guard<'_, T> {}` — the *guard* exposes `&T` to two threads via two `&Guard`s, so `T: Sync` is required here.

### Idiomatic pattern

```rust
pub struct SpinLock<T> {
    locked: AtomicBool,
    value: UnsafeCell<T>,
}
unsafe impl<T: Send> Sync for SpinLock<T> {}

impl<T> SpinLock<T> {
    pub fn lock(&self) -> Guard<'_, T> {
        while self.locked.swap(true, Ordering::Acquire) {
            std::hint::spin_loop();
        }
        Guard { lock: self }
    }
}
```

### Anti-patterns

```rust
// BAD: no spin_loop hint — pegs the core, starves the SMT sibling, slows
// the holder. PAUSE / YIELD frees pipeline resources and is mandatory.
while self.locked.swap(true, Ordering::Acquire) {}
```

```rust
// BAD: Relaxed on either side. The protected data writes are not synced.
// Passes on x86, fails on ARM (the book demonstrates ~0.4% corruption on M1).
while self.locked.swap(true, Ordering::Relaxed) { std::hint::spin_loop(); }
self.locked.store(false, Ordering::Relaxed);
```

**Spinlocks in user-space are a footgun**. The OS may preempt the lock holder mid-critical-section, after which every contender spins waiting for a sleeping thread. On a system with priority inheritance (real-time threads holding the lock), this is unbounded spin and priority inversion. **Default to `parking_lot::Mutex` or `std::sync::Mutex`**; hand-rolled spinlocks belong in kernels, embedded code, or extremely short critical sections inside cooperative schedulers.

If a spinlock is genuinely the right tool, add **exponential backoff** and an **eventual yield**:

```rust
let mut backoff = 1;
while self.locked.swap(true, Ordering::Acquire) {
    for _ in 0..backoff { std::hint::spin_loop(); }
    if backoff < 64 { backoff *= 2; } else { std::thread::yield_now(); }
}
```

### False sharing

A `SpinLock` byte placed adjacent to another hot atomic on the same 64-byte cache line costs ~10x in throughput (Chapter 7). Wrap with `crossbeam::utils::CachePadded` or `#[repr(align(64))]` when the lock and its protected data are in the same struct as other shared atomics.

- `[FILE:LINE] SPINLOCK_MISSING_SPIN_LOOP_HINT` — `swap(true, Acquire)` loop body lacks `std::hint::spin_loop()`.
- `[FILE:LINE] SPINLOCK_RELAXED_ORDERING` — `AtomicBool` lock state using `Relaxed` for `swap`/`store`.
- `[FILE:LINE] SPINLOCK_USERSPACE_PREEMPTIBLE` — `SpinLock` used in a normal binary (not `no_std`, not a kernel) without a comment naming the specific reason a `Mutex` is unsuitable.
- `[FILE:LINE] SPINLOCK_NO_BACKOFF_OR_YIELD` — Spin loop with no exponential backoff and no `thread::yield_now()` escape hatch on extended contention.
- `[FILE:LINE] SPINLOCK_FALSE_SHARING` — `AtomicBool` lock state in a struct with other hot atomic fields, no `CachePadded` / `#[repr(align(64))]`.
- `[FILE:LINE] SPINLOCK_WRONG_SYNC_BOUND` — `unsafe impl Sync for SpinLock<T> where T: Sync` (should be `T: Send`).
- `[FILE:LINE] SPINLOCK_GUARD_MISSING_SYNC_BOUND` — `unsafe impl Sync for Guard<T>` with no bound, or `T: Send`; the guard exposes `&T` and needs `T: Sync`.

## Hand-Rolled Channels

Chapter 5 walks five channel designs, each adding one correctness technique. The common shape is `UnsafeCell<MaybeUninit<T>>` + `AtomicBool` for the "ready" flag.

### Correct one-shot blocking channel

```rust
pub struct Channel<T> {
    message: UnsafeCell<MaybeUninit<T>>,
    ready: AtomicBool,
}
unsafe impl<T: Send> Sync for Channel<T> {}

pub struct Sender<'a, T>   { channel: &'a Channel<T>, rx: Thread }
pub struct Receiver<'a, T> { channel: &'a Channel<T>, _ns: PhantomData<*const ()> }

impl<T> Sender<'_, T> {
    pub fn send(self, msg: T) {
        unsafe { (*self.channel.message.get()).write(msg) };
        self.channel.ready.store(true, Ordering::Release);
        self.rx.unpark();
    }
}
impl<T> Receiver<'_, T> {
    pub fn receive(self) -> T {
        while !self.channel.ready.swap(false, Ordering::Acquire) {
            std::thread::park();
        }
        unsafe { (*self.channel.message.get()).assume_init_read() }
    }
}
```

### Drop safety

A channel storing `MaybeUninit<T>` **must** implement `Drop` to run `T`'s destructor when dropped with an unreceived message. Forgetting this leaks any non-trivial `T` (`Vec`, `Box`, `File`, `Arc`).

```rust
impl<T> Drop for Channel<T> {
    fn drop(&mut self) {
        if *self.ready.get_mut() {
            unsafe { self.message.get_mut().assume_init_drop() }
        }
    }
}
```

```rust
// BAD: unconditional drop. Runs T::drop on uninit memory if no send happened.
impl<T> Drop for Channel<T> {
    fn drop(&mut self) {
        unsafe { self.message.get_mut().assume_init_drop() }
    }
}
```

### Panic safety

`send` writes the `MaybeUninit<T>`, **then** flips the ready flag. If the user's `T::clone` or moves can panic, the flag must only be set after the value is fully written. Code that flips ready *before* writing exposes the receiver to uninitialized memory:

```rust
// BAD: ready is true before the value lands.
self.channel.ready.store(true, Ordering::Release);
unsafe { (*self.channel.message.get()).write(msg) }; // panic here = UB read
```

### Type-state split

Use a typed split (`Sender`/`Receiver` consuming `self` by value, or borrowing with lifetimes) so the type system rules out double-send and send-after-close. Multi-send via `&self` without either a runtime `swap(true, …)` guard or type-level prevention lets two callers race on the same `UnsafeCell`.

### Park / unpark race

`unpark()` is **pre-arming and idempotent**: an `unpark` that lands before `park` is not lost (it sets a flag that `park` consumes immediately). What *can* be lost is multiple `unpark`s — they do not stack. Always combine `park()` with an explicit `swap`/`load` re-check in a loop. `park` is also allowed to return spuriously on every major OS; the loop must re-check the predicate.

```rust
// BAD: assumes park returns only when ready is set. Spurious wakeup = UAF.
std::thread::park();
unsafe { (*ch.message.get()).assume_init_read() }
```

The blocking variant must make `Receiver` `!Send` (via `PhantomData<*const ()>` or equivalent) — the stored `Thread` handle is the receiver thread, and a `Send` receiver would let another thread call `receive()` while `unpark` targets the original.

- `[FILE:LINE] CHANNEL_DROP_MISSING_OR_UNCONDITIONAL` — `MaybeUninit<T>` channel with no `Drop`, or a `Drop` that calls `assume_init_drop` without checking the ready flag.
- `[FILE:LINE] CHANNEL_READY_FLAG_RELAXED` — `ready.store(true, Relaxed)` or `ready.load(Relaxed)` with non-atomic data published through the flag.
- `[FILE:LINE] CHANNEL_READY_FLIPPED_BEFORE_WRITE` — `ready.store(true, Release)` appears textually *before* the `MaybeUninit::write`; reorders observers see uninit data.
- `[FILE:LINE] CHANNEL_PARK_NOT_IN_LOOP` — `thread::park()` not inside a re-checking `while` loop; spurious wakeups read uninit memory.
- `[FILE:LINE] CHANNEL_RECEIVER_SEND_NOT_BLOCKED` — Blocking channel receiver lacks `PhantomData<*const ()>` (or equivalent `!Send` marker) while storing a `Thread`.
- `[FILE:LINE] CHANNEL_DOUBLE_SEND_UNGUARDED` — `send(&self, …)` writes to `UnsafeCell<MaybeUninit<T>>` with no `swap(true, …)` guard and no type-level single-send enforcement.

## Hand-Rolled Arc

`Arc<T>` is the most commonly hand-rolled primitive and almost always gets the ordering wrong. Chapter 6's rules:

- **Clone uses `Relaxed`.** The cloning thread already has access to the data; the increment publishes nothing.
- **Drop uses `Release`** on the `fetch_sub`. The thread whose decrement reaches zero performs `fence(Ordering::Acquire)` before freeing.
- **Both** `T: Send` *and* `T: Sync` are required for `Arc<T>: Send + Sync`. Sending an `Arc` shares `T` via the clones (`T: Sync`); the receiver may drop the last one (`T: Send`).

### Idiomatic clone / drop

```rust
impl<T> Clone for Arc<T> {
    fn clone(&self) -> Self {
        if self.data().refcount.fetch_add(1, Ordering::Relaxed) > usize::MAX / 2 {
            std::process::abort();
        }
        Arc { ptr: self.ptr }
    }
}
impl<T> Drop for Arc<T> {
    fn drop(&mut self) {
        if self.data().refcount.fetch_sub(1, Ordering::Release) == 1 {
            std::sync::atomic::fence(Ordering::Acquire);
            unsafe { drop(Box::from_raw(self.ptr.as_ptr())) };
        }
    }
}
```

The **`Acquire` fence on the last decrement** is the canonical optimization: it would be correct to use `AcqRel` on every `fetch_sub`, but that pays for synchronization on every drop. The fence-only-on-last pattern moves the cost to the rare path where it is needed.

### Anti-patterns

```rust
// BAD: Relaxed on drop. The freeing thread may execute before another
// thread's read of T finishes. UB.
self.data().refcount.fetch_sub(1, Ordering::Relaxed);
```

```rust
// BAD: missing Acquire fence. The drop of *T can be reordered before
// other threads' accesses to T complete. UB on weakly ordered archs.
if self.data().refcount.fetch_sub(1, Ordering::Release) == 1 {
    unsafe { drop(Box::from_raw(self.ptr.as_ptr())) };
}
```

```rust
// BAD: no overflow guard. A pathological clone storm wraps refcount to 0,
// the next drop frees while clones still exist. UAF.
impl<T> Clone for Arc<T> {
    fn clone(&self) -> Self {
        self.data().refcount.fetch_add(1, Ordering::Relaxed);
        Arc { ptr: self.ptr }
    }
}
```

### Weak references and the two-counter layout

The std `Arc<T>` uses a two-counter layout supporting `Weak`:

```rust
struct ArcData<T> {
    data_ref_count: AtomicUsize,   // strong arcs
    alloc_ref_count: AtomicUsize,  // weak arcs + (1 if any strong exists)
    data: UnsafeCell<ManuallyDrop<T>>,
}
```

`Weak::upgrade` is a **CAS loop that increments-if-nonzero**, not `fetch_add` + check — `fetch_add` races with a concurrent last-drop that may already have decided to free:

```rust
pub fn upgrade(&self) -> Option<Arc<T>> {
    let mut n = self.data().data_ref_count.load(Ordering::Relaxed);
    loop {
        if n == 0 { return None; }
        if let Err(e) = self.data().data_ref_count
            .compare_exchange_weak(n, n + 1, Ordering::Relaxed, Ordering::Relaxed)
        {
            n = e; continue;
        }
        return Some(Arc { ptr: self.ptr });
    }
}
```

### Usage smells

- `Arc::strong_count(&a)` / `Arc::weak_count(&a)` used for synchronization decisions — both are TOCTOU. The count can change between the load and the next instruction. They are debugging aids, not sync primitives.
- `Arc::clone(&x)` vs `x.clone()` — both compile to the same code. The explicit form documents intent and grep finds it; reviewer preference, not a correctness issue.
- `Arc<Mutex<Inner>>` cycles where `Inner` holds another `Arc<Mutex<Inner>>` — classic memory leak. The cycle must include a `Weak` to break.
- `Arc<Mutex<u64>>` (or any `Copy` primitive) — almost always wants `Arc<AtomicU64>` instead.

- `[FILE:LINE] ARC_CLONE_NOT_RELAXED` — Hand-rolled `Arc::clone` using stronger-than-`Relaxed` ordering on `fetch_add`.
- `[FILE:LINE] ARC_DROP_NOT_RELEASE` — Hand-rolled `Arc::drop` using weaker-than-`Release` ordering on `fetch_sub`.
- `[FILE:LINE] ARC_DROP_MISSING_ACQUIRE_FENCE` — `fetch_sub(1, Release) == 1` branch with no subsequent `fence(Acquire)` before deallocation.
- `[FILE:LINE] ARC_CLONE_NO_OVERFLOW_GUARD` — Hand-rolled refcount `fetch_add` with no `> usize::MAX / 2` check or `process::abort()` path.
- `[FILE:LINE] ARC_SEND_SYNC_BOUND_INSUFFICIENT` — `unsafe impl Send for Arc<T> where T: Send` missing the `T: Sync` half.
- `[FILE:LINE] ARC_STRONG_COUNT_AS_SYNC` — Control-flow branches on `Arc::strong_count` / `weak_count` for correctness (not debugging); TOCTOU.
- `[FILE:LINE] ARC_MUTEX_CYCLE` — `Arc<Mutex<T>>` where `T` transitively holds another `Arc<Mutex<T>>` without a `Weak` to break the cycle.
- `[FILE:LINE] WEAK_UPGRADE_NOT_CAS_LOOP` — `Weak::upgrade` using `fetch_add` + check rather than `compare_exchange_weak` loop guarding against zero.

## CAS Loops and ABA

The canonical CAS retry loop uses `compare_exchange_weak` because `_weak` may spuriously fail on LL/SC architectures (ARM, RISC-V) but is cheaper than `_strong` inside a loop:

```rust
let mut cur = value.load(Ordering::Relaxed);
loop {
    let next = f(cur);
    match value.compare_exchange_weak(cur, next,
        Ordering::AcqRel, Ordering::Relaxed)
    {
        Ok(_) => break,
        Err(observed) => cur = observed,
    }
}
```

`fetch_update(set_ordering, fetch_ordering, f)` collapses this to one call and is the preferred form for new code.

### The ABA problem

Between your `load` (sees `A`) and your `compare_exchange(A, B)`, another thread executes `A → X → A`. The CAS succeeds, but the *meaning* of `A` may have changed.

| Where ABA is a real bug | Where ABA is benign |
|-------------------------|----------------------|
| Pointer-based lock-free stacks/queues — the freed node was recycled into a new node | Monotonic counters (ID allocation) — value identity *is* the value |
| Freelists — a popped node may have been freed and re-pushed; UAF | Refcounts — wrap-around is an overflow bug, not ABA |
| Linked-list traversal with `AtomicPtr` next-links | Version-tagged values where the version is part of the comparison |

### Mitigations for real ABA

- **Tagged pointers** — pack `(ptr, generation)` into a `AtomicU64` (or `AtomicUsize` on 64-bit) and bump the generation on every store. ABA still happens but the generation differs.
- **Hazard pointers** — readers register the pointer they're about to dereference; deallocation defers until no hazard names it. Crate: `haphazard`.
- **Epoch-based reclamation** — `crossbeam-epoch` pins an epoch on read, defers free until all readers have advanced past the epoch.
- **Generational indices** — replace pointers with `(index, generation)` into a `Vec`; the generation rules out stale references.

```rust
// BAD: AtomicPtr<Node> freelist with no reclamation discipline.
// Pop sees head=A, another thread pops A, frees it, allocates new node at
// the same address, pushes it as A again. CAS succeeds, head.next is wrong.
let head = self.head.load(Ordering::Acquire);
let next = unsafe { (*head).next }; // <-- UAF if A was freed
self.head.compare_exchange(head, next, AcqRel, Relaxed)?;
```

- `[FILE:LINE] CAS_LOOP_USES_STRONG` — `compare_exchange` (not `_weak`) inside a retry `loop`.
- `[FILE:LINE] HAND_ROLLED_FETCH_UPDATE` — CAS-loop transform with no comment explaining why `fetch_update` is unsuitable.
- `[FILE:LINE] ABA_HAND_ROLL` — Pointer-based CAS on `AtomicPtr<Node>` without epoch/hazard/tagged-pointer reclamation.

## Seqlocks

A seqlock supports **frequent lock-free reads of a value too big to fit in one atomic**, with rare writes. The pattern:

- Even sequence number = stable; odd = write in progress.
- Reader: load `seq` (`Acquire`); if odd, retry. Read fields. Load `seq` again (`Acquire`); if it changed, retry.
- Writer: increment `seq` to odd (`Release`), write fields, increment to even (`Release`).

```rust
pub fn read(&self) -> Snapshot {
    loop {
        let s1 = self.seq.load(Ordering::Acquire);
        if s1 & 1 != 0 { std::hint::spin_loop(); continue; }
        let snap = unsafe { std::ptr::read(self.data.get()) };
        let s2 = self.seq.load(Ordering::Acquire);
        if s1 == s2 { return snap; }
    }
}
```

The reader's both `load(seq)`s must be `Acquire` (or `SeqCst`) so the field reads cannot be reordered outside the seq-number bracket. A `Relaxed` load on either lets the compiler hoist the field reads past the version check, defeating the protocol.

- `[FILE:LINE] SEQLOCK_RELAXED_VERSION_LOAD` — Seqlock reader uses `Relaxed` on the version load. Field reads can be reordered outside the version bracket.
- `[FILE:LINE] SEQLOCK_NONATOMIC_FIELD_NO_ACQUIRE` — Seqlock reader reads protected fields without an `Acquire` version load preceding them.

## Hand-Rolled Mutex and Condvar

Chapter 9's mutex is a three-state machine on `AtomicU32` (futex word):

| State | Meaning |
|-------|---------|
| `0` | Unlocked |
| `1` | Locked, no waiters |
| `2` | Locked, one or more waiters parked on the futex |

```rust
pub fn lock(&self) -> MutexGuard<'_, T> {
    if self.state.compare_exchange(0, 1, Ordering::Acquire, Ordering::Relaxed).is_err() {
        lock_contended(&self.state);
    }
    MutexGuard { mutex: self }
}
impl<T> Drop for MutexGuard<'_, T> {
    fn drop(&mut self) {
        if self.mutex.state.swap(0, Ordering::Release) == 2 {
            atomic_wait::wake_one(&self.mutex.state);
        }
    }
}
```

The "only wake when prior state was 2" optimization is what separates a good hand-rolled mutex from a bad one. Unconditionally calling `wake_one` on every unlock pays a syscall per critical section even on the uncontended path.

### Condvar

The condvar protocol from `ch9_locks/condvar_2.rs`:

```rust
pub fn wait<'a, T>(&self, guard: MutexGuard<'a, T>) -> MutexGuard<'a, T> {
    self.num_waiters.fetch_add(1, Ordering::Relaxed);
    let counter = self.counter.load(Ordering::Relaxed); // BEFORE drop(guard)
    let m = guard.mutex;
    drop(guard);
    atomic_wait::wait(&self.counter, counter);
    self.num_waiters.fetch_sub(1, Ordering::Relaxed);
    m.lock()
}
```

**Critical**: load the counter **before** dropping the mutex guard. A `notify_one` that lands between `drop(guard)` and `wait(&counter, counter)` increments the counter, so `wait` returns immediately because the observed value no longer matches `expected`. Loading after unlock opens a lost-wakeup window where the notify happens, then we sleep on a counter that has already moved past.

### Spurious wakeups

The OS may return from `wait` without a corresponding `notify`. Callers **must** re-check the predicate in a loop:

```rust
// CORRECT
let mut q = queue.lock().unwrap();
while q.is_empty() {
    q = not_empty.wait(q).unwrap();
}
```

```rust
// BAD: single wait, no predicate loop. Spurious wakeup returns Some(garbage).
let mut q = queue.lock().unwrap();
q = not_empty.wait(q).unwrap();
let item = q.pop_front().unwrap();
```

A condvar `wait` always pairs with **one specific mutex**. Using the same `Condvar` with two different mutexes is UB on `std::sync::Condvar` (debug-asserted on some platforms, undefined on others). The reviewer cue is `cv.wait(m1.lock()…)` and `cv.wait(m2.lock()…)` in the same module.

- `[FILE:LINE] MUTEX_ALWAYS_WAKE_ON_UNLOCK` — `Drop for MutexGuard` calls `wake_one`/`wake_all` unconditionally instead of gating on `swap` returning the "waiters" state.
- `[FILE:LINE] CONDVAR_COUNTER_AFTER_UNLOCK` — `counter.load` called *after* the mutex guard is dropped. Lost-wakeup window.
- `[FILE:LINE] CONDVAR_WAIT_NOT_IN_LOOP` — `cv.wait(g)` not inside a `while !predicate { g = cv.wait(g)?; }` loop.

## Ecosystem Alternatives — Quick Reference

Reach for these instead of hand-rolling, unless you have a specific justification documented in the code:

| Pattern | Crate |
|---------|-------|
| Lock-free read-mostly snapshot of an `Arc` | `arc-swap::ArcSwap<T>` |
| Lock-free MPMC channel | `crossbeam::channel` |
| Concurrent hash map | `dashmap::DashMap` or `flurry` |
| Hazard pointers | `haphazard` |
| Epoch-based reclamation | `crossbeam-epoch`, `seize` |
| Wait-free queue (bounded) | `crossbeam-queue::ArrayQueue`, `concurrent-queue` |
| Atomic `Option<T>` for non-pointer `T` | `atomic_option` |
| Atomic enum (small repr) | `atomic_enum` |
| Reentrant mutex | `parking_lot::ReentrantMutex` |
| Sharded RwLock for high reader contention | `crossbeam_utils::sync::ShardedLock` |
| Generic `AtomicCell<T>` | `crossbeam_utils::atomic::AtomicCell` |

- `[FILE:LINE] HANDROLLED_LOCKFREE_DATA_STRUCTURE` — Bespoke lock-free queue/stack/list/map without a comment naming the specific crate alternative considered and rejected.
- `[FILE:LINE] HANDROLLED_RCU` — Refcount-tagged pointer swaps (read-mostly snapshot) implemented by hand instead of `arc-swap` / `seize`.
