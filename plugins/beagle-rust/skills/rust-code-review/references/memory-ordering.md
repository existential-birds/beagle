# Memory Ordering

For general atomics/lock/`Send`-`Sync` background, see [concurrency-primitives.md](concurrency-primitives.md). For hand-rolled spinlocks, channels, and `Arc` patterns, see [lock-free-patterns.md](lock-free-patterns.md). For loom/Miri test patterns, see [../../rust-testing-code-review/references/concurrency-testing.md](../../rust-testing-code-review/references/concurrency-testing.md).

The single highest-value reviewer instinct: **every atomic operation should be paired in your mind with the happens-before relationship it participates in.** If you cannot name the relationship in one sentence, the ordering is probably wrong, or `SeqCst` is being used as a fig leaf.

## Why Memory Ordering Exists

Atomic ordering is about *reorderings*, not propagation speed. Three independent agents reorder memory accesses:

1. **The compiler** rewrites your code to keep registers warm and folds independent stores.
2. **The CPU** reorders loads/stores out of program order; weakly-ordered ISAs (ARM64, RISC-V) reorder aggressively, while x86-64 only allows store-load reordering.
3. **The cache** can publish writes to other cores out of issue order (though a single atomic's modification order is always preserved per-atomic).

Cache coherence is not ordering. Coherence guarantees that writes to a *single* memory location are observed in *some* total order — every CPU agrees on the modification order of one address. Ordering is about how operations on *different* locations relate.

"Happens-before" is the formal name for the partial order over operations in a concurrent program. If A happens-before B, then B observes A's effects. Atomic ordering builds happens-before edges between threads — without those edges, a write in one thread is not guaranteed to be visible to a load in another, even hours later. The borrow checker prevents data races (UB); memory ordering decides which writes are *visible* across threads.

### The modification order

Every atomic has a single Total Modification Order (TMO) that all threads agree on. `Relaxed` does not destroy this — threads will not see modifications to one atomic out of order. What `Relaxed` *does* allow is disagreement between threads about how modifications to *different* atomics interleave. Two threads can each see a coherent timeline of `X` and a coherent timeline of `Y`, but disagree about whether `X.store(1)` happened before or after `Y.store(1)`.

```rust
// Thread A:                Thread B:
// X.store(1, Relaxed);     Y.store(1, Relaxed);
// let y = Y.load(Relaxed); let x = X.load(Relaxed);
// Both threads can observe (x, y) = (0, 0). That is not a bug — there is no
// happens-before relationship to violate.
```

Cross-thread happens-before edges are created by exactly four things:

- `thread::spawn` — everything in the parent before the spawn happens-before everything in the child.
- `JoinHandle::join` — everything in the child happens-before everything after the join.
- A release-store observed by an acquire-load **on the same atomic** (the "release sequence").
- Fences (`fence(Release)`/`fence(Acquire)`/`fence(SeqCst)`) paired with atomic operations.

If you cannot point to one of these four mechanisms producing the visibility you depend on, the code is broken.

## The Five Orderings

Rust exposes `Relaxed`, `Acquire`, `Release`, `AcqRel`, and `SeqCst`. C++20's `Consume` is intentionally absent; Rust silently promotes it to `Acquire` if you reach for it.

**Decision tree** (Mara Bos's actual rule — *not* "SeqCst if in doubt"):

1. Counters, statistics, refcount increments, "stop" flags whose only payload is the flag itself → `Relaxed`.
2. Publishing data: store the data, then signal via `Release`. Observe via `Acquire`. Pair `Release` store with `Acquire` load *on the same atomic*.
3. Read-modify-write that both observes published data and publishes new data (locks, channel handoffs, ref-counts with publication) → `AcqRel`.
4. You need a single global total order across two or more *independent* atomics (Dekker-style mutual exclusion) → `SeqCst`. Comment why.
5. Use a fence to amortize ordering across many subsequent operations, or defer the cost to a rare path (e.g., the "last decrement" pattern in `Arc::drop`).

### `Relaxed`

Atomic access only. No happens-before with anything other than the atomic itself. The TMO is still preserved; only inter-atomic interleaving is unconstrained.

**Correct use**: stop flag where the only shared datum is the flag.

```rust
static STOP: AtomicBool = AtomicBool::new(false);
while !STOP.load(Relaxed) {
    work();
}
// from another thread:
STOP.store(true, Relaxed);
```

**Wrong use**: publishing a pointer or data, where the load is gated on a `Relaxed` flag and the data is read non-atomically afterwards.

```rust
// BAD: observer can see READY = true with DATA still 0.
unsafe { DATA = 123; }
READY.store(true, Relaxed); // should be Release

if READY.load(Relaxed) {    // should be Acquire
    let v = unsafe { DATA }; // may observe 0
}
```

`[FILE:LINE] RELAXED_PUBLISH_OF_DATA` — `store(.., Relaxed)` on an atomic that gates access to non-atomic data on the same or another thread. Use `Release`.

### `Acquire`

Load-only ordering. Once an `Acquire` load observes a value, every memory access in the *observing* thread after the load sees everything that happened in the *releasing* thread before its `Release` store.

**Correct use**: observing a `Release`-published flag.

```rust
while !READY.load(Acquire) {} // observe
let v = unsafe { DATA };      // safe: happens-before via Release/Acquire pair
```

**Wrong use**: `Acquire` on a store. Compiler-rejected on modern rustc (`store(.., Acquire)` panics at runtime in older versions, but `Ordering::Acquire` is invalid for `store`). Pure stores cannot have acquire semantics.

```rust
// BAD: store does not have an acquire half; compiles in some older
// rustc versions and silently degrades. New rustc panics.
flag.store(true, Acquire);
```

`[FILE:LINE] STORE_WITH_ACQUIRE` — `.store(.., Acquire)` or `.store(.., AcqRel)`. Use `Release` (or `SeqCst` if a global total order is required).

### `Release`

Store-only ordering. Every memory access in the *releasing* thread before the store happens-before every memory access in any *acquiring* thread after a paired `Acquire` load that observes the released value.

**Correct use**: publishing data to other threads via a `Release` store.

```rust
unsafe { DATA = 123; }        // non-atomic write
READY.store(true, Release);   // publishes DATA
```

**Wrong use**: `Release` on a load. A pure load has nothing to publish. The Rust API rejects this (`load(Release)` and `load(AcqRel)` panic).

```rust
// BAD: load cannot have a release half.
let v = flag.load(Release);
```

`[FILE:LINE] LOAD_WITH_RELEASE` — `.load(.., Release)`. Use `Acquire` (or `SeqCst`).

### `AcqRel`

`Acquire` + `Release`, for read-modify-write operations only (`fetch_add`, `fetch_sub`, `fetch_or`, `swap`, `compare_exchange`). The load half is `Acquire`; the store half is `Release`. Use when an RMW both observes prior published data and publishes new data — locks, channel handoffs, ref-count operations that hand off ownership.

**Correct use**: locking via a CAS that observes "unlocked" and publishes "locked".

```rust
// Spinlock acquire:
while self.locked.swap(true, Acquire) { std::hint::spin_loop(); }
// ... critical section reads/writes ...
self.locked.store(false, Release); // unlock publishes the writes above
```

`swap(true, Acquire)` is enough on the lock-acquire path because the *release* half of the publication happens on the matching unlock store. The book's spinlock uses `Acquire` on `swap` and `Release` on `store`. Use full `AcqRel` when the RMW *itself* is the publication point.

**Wrong use**: `AcqRel` on a pure load. Rust rejects it.

```rust
// BAD: pure load has no release component. Panics.
let v = flag.load(AcqRel);
```

`[FILE:LINE] LOAD_WITH_ACQREL` — `.load(.., AcqRel)`. Use `Acquire` (or `SeqCst`).

### `SeqCst`

`AcqRel` **plus** participation in a single global total order with every other `SeqCst` operation in the program. The only thing `SeqCst` gives you over `AcqRel` is that global agreement across *different* atomics. If you cannot point to two `SeqCst` operations on *different* atomics whose global ordering you actually depend on, `SeqCst` is wasted strength and a review smell.

**Correct use**: Dekker-style mutual exclusion across two atomics.

```rust
static A: AtomicBool = AtomicBool::new(false);
static B: AtomicBool = AtomicBool::new(false);
// Thread 1
A.store(true, SeqCst);
if !B.load(SeqCst) { critical_section(); }
// Thread 2
B.store(true, SeqCst);
if !A.load(SeqCst) { critical_section(); }
```

With `SeqCst`, at most one thread enters the critical section. With `Release`/`Acquire` on each atomic separately, both can enter — the store-before-load ordering across two different atomics is not guaranteed.

**Wrong use**: `SeqCst` sprinkled defensively where `Acquire`/`Release` would suffice.

```rust
// BAD: SeqCst on a simple publish-then-observe pair adds dmb ish on ARM
// for no benefit. Acquire/Release is enough.
flag.store(true, SeqCst);
if flag.load(SeqCst) { read_data(); }
```

`[FILE:LINE] SEQCST_WITHOUT_JUSTIFICATION` — any `SeqCst` not accompanied by a comment naming the Dekker-pattern or similar global total-order requirement.

## `compare_exchange` Ordering Pair

`compare_exchange` takes **two** orderings: one for the success path (an RMW that may publish) and one for the failure path (an aborted load).

**Rules** (compiler-enforced, but worth flagging if mechanically duplicated):
- The failure ordering must be no stronger than the success ordering.
- The failure ordering may not be `Release` or `AcqRel` (a failed CAS performs no store).
- Failure of `Acquire`/`Release`/`AcqRel`/`SeqCst` success usually pairs with `Relaxed` or `Acquire` failure — `Acquire` if even an unsuccessful peek must still observe a release.

**Weak vs strong**:
- `compare_exchange_weak` may spuriously fail on LL/SC architectures (ARM, RISC-V) even when the value matches. Cheaper inside a retry loop.
- `compare_exchange` (strong) never spuriously fails. Use for one-shot updates with no retry.

**The canonical CAS loop**:

```rust
let mut cur = state.load(Relaxed);
loop {
    if cur != 0 { break Err(()); }
    match state.compare_exchange_weak(cur, 1, Acquire, Relaxed) {
        Ok(_) => break Ok(()),
        Err(v) => cur = v,
    }
}
```

The `Acquire` on success synchronizes with the previous holder's `Release` unlock. The `Relaxed` on failure is correct because we did not observe the published critical section — we re-read and try again.

**The `fetch_update` alternative** (stable, often clearer):

```rust
state.fetch_update(Acquire, Relaxed, |cur| if cur == 0 { Some(1) } else { None });
```

`[FILE:LINE] STRONG_CAS_IN_LOOP` — `compare_exchange(` (not `_weak`) inside a `loop {`. Use `compare_exchange_weak` to avoid LL/SC retry cost on ARM/RISC-V.

`[FILE:LINE] CAS_FAILURE_STRONGER_THAN_SUCCESS` — `compare_exchange[_weak](.., A, B)` where B is stricter than A. Rust enforces this, but mechanical duplication is a smell.

**BAD vs GOOD on the lock path**:

```rust
// BAD: success Relaxed cannot establish a lock acquire happens-before chain.
state.compare_exchange(0, 1, Relaxed, Relaxed);

// GOOD: success Acquire observes the prior holder's Release unlock.
state.compare_exchange(0, 1, Acquire, Relaxed);
```

`[FILE:LINE] CAS_RELAXED_ON_LOCK_ACQUIRE` — `compare_exchange[_weak](.., 1, _, Relaxed, _)` (or similar) used as a lock acquire. Use `Acquire` on success.

`[FILE:LINE] CAS_WEAK_OUTSIDE_LOOP` — `compare_exchange_weak` outside a retry loop. Either use the strong variant or wrap in a loop.

## Fences

`atomic::fence(Ordering)` decouples ordering from a specific operation. A `fence(Release)` before a `Relaxed` store has the same effect as a `Release` store; a `fence(Acquire)` after a `Relaxed` load has the same effect as an `Acquire` load.

**When a fence is useful**: amortizing ordering across many operations, or deferring the cost to a rare path. The canonical example is `Arc::drop`:

```rust
if ref_count.fetch_sub(1, Release) == 1 {
    fence(Acquire); // synchronize only on the final drop
    unsafe { drop(Box::from_raw(ptr.as_ptr())); }
}
```

Every decrement uses cheap `Release`. Only the thread that observes the count hit zero pays for the `Acquire` fence. This is strictly cheaper than `AcqRel` on every decrement, yet correct — the dropping thread synchronizes with all prior drops before freeing.

See [lock-free-patterns.md](lock-free-patterns.md) for the full `Arc` drop pattern.

**Wrong use**: using a fence in place of properly ordered atomic ops on the *hot* load.

```rust
// BAD: the load itself is the hot operation; using Relaxed + fence here
// does not save anything and obscures intent.
let v = flag.load(Relaxed);
fence(Acquire);
if v { read_data(); }

// GOOD: just use load(Acquire) — same cost, clearer.
if flag.load(Acquire) { read_data(); }
```

`[FILE:LINE] FENCE_INSTEAD_OF_ORDERED_OP` — a `Relaxed` load followed by `fence(Acquire)` on the hot path where `load(Acquire)` would be equally cheap and clearer.

`[FILE:LINE] FENCE_WITHOUT_PAIRED_ATOMIC` — `atomic::fence(Acquire)` with no associated `Relaxed` load nearby (or `fence(Release)` with no `Relaxed` store). Fences pair with atomic operations; a lone fence is either a bug or pointless.

`[FILE:LINE] COMPILER_FENCE_OUTSIDE_SIGNAL_CONTEXT` — `compiler_fence` outside an `extern "C"` signal handler or interrupt context. `compiler_fence` constrains only the compiler, not the CPU. Almost no application code should reach for it.

## Common Mistakes

The most common ordering bugs, with grep-friendly flags. Each pairs a `[FILE:LINE]` check with the underlying mistake.

`[FILE:LINE] RELAXED_PUBLISH_OF_DATA` — `store(.., Relaxed)` on a flag that gates non-atomic data; reader observes the flag and reads the data. No happens-before edge. Use `Release` on the store and `Acquire` on the load.

`[FILE:LINE] RELAXED_LOAD_GATING_DATA_ACCESS` — `load(.., Relaxed)` followed by a non-atomic read conditional on the result. Same bug from the reader side; should be `Acquire`.

`[FILE:LINE] STORE_WITH_ACQUIRE` — `.store(.., Acquire)`. Stores cannot acquire (rejected at compile time / panics at runtime depending on version). Use `Release`.

`[FILE:LINE] LOAD_WITH_RELEASE` — `.load(.., Release)`. Loads cannot release. Use `Acquire`.

`[FILE:LINE] LOAD_WITH_ACQREL` — `.load(.., AcqRel)`. Pure loads cannot have a release component. Use `Acquire`.

`[FILE:LINE] SEQCST_DEFENSIVE` — `SeqCst` used on every atomic operation in a module "for safety". On ARM each `SeqCst` costs `dmb ish`. Demand a comment that names a specific multi-atomic global-order requirement; otherwise downgrade to `Acquire`/`Release` or `Relaxed`.

`[FILE:LINE] CAS_RELAXED_ON_LOCK_ACQUIRE` — `compare_exchange[_weak](.., Relaxed, _)` used to acquire a critical section. The success path must be `Acquire` (or `AcqRel` if the CAS is itself the publication).

`[FILE:LINE] CAS_WEAK_OUTSIDE_LOOP` — `compare_exchange_weak` used once with no retry. Either switch to the strong variant or wrap in a loop that re-reads on `Err`.

`[FILE:LINE] FETCH_OR_AS_LOAD` — `fetch_or(0, _)` (or `fetch_and(!0, _)`) used as a load. These are still RMW operations and claim exclusive cache-line ownership. Use `load`.

`[FILE:LINE] CAS_CHECK_BEFORE_SUCCESS` — code reads the *new* value from the `Ok` branch of `compare_exchange` and trusts it, when the value of interest is in the `Err` branch (which returns the *current* value at failure time). Or the inverse: assuming the loaded-but-then-CAS-failed value is up to date when it has already moved on.

`[FILE:LINE] SEQCST_NOT_TRANSITIVE_TO_NON_SEQCST` — assuming that a `SeqCst` operation on atomic `A` synchronizes with an `Acquire`/`Release` operation on atomic `B` via the SeqCst global order. SeqCst only orders SeqCst operations against other SeqCst operations; it provides Acquire/Release for the *same* atomic, not bonus synchronization with non-SeqCst operations on *other* atomics.

`[FILE:LINE] WALL_CLOCK_HAPPENS_BEFORE` — code reasoning like "thread B's store happened 50ms after thread A's load, so B saw A". Happens-before is a partial order over operations connected by synchronization edges, not a wall-clock order. Without a release/acquire/spawn/join/fence edge between them, "later in time" implies nothing about visibility.

`[FILE:LINE] X86_ONLY_ORDERING` — code uses `Relaxed` on a publish/observe pair, with no `target_arch` cfg gating. On x86-64, `Relaxed`, `Acquire`, `Release`, and `AcqRel` compile to the *same* instructions; the bug is invisible on x86 hardware and macOS Intel CI. Mara's book demonstrates a 0.4% corruption rate on Apple M1 from this exact mistake. Test on ARM/RISC-V or run loom.

`[FILE:LINE] ATOMIC_U8_FLAG_SEQCST` — `AtomicU8` or `AtomicBool` flag using `SeqCst` for both store and load when `Release`/`Acquire` (or `Relaxed`) would do. Flag bits do not participate in multi-atomic global ordering unless explicitly designed to.

`[FILE:LINE] MIXED_ORDERINGS_ON_SAME_ATOMIC` — different code paths use different orderings on the same atomic without comment. Sometimes intentional (e.g., `Relaxed` on the fast clone path, `Acquire` fence on the rare last-drop path). Flag when the asymmetry is not justified — often a sign that one path is intentionally too weak.

`[FILE:LINE] LOAD_TAKES_RELEASE_VARIANT` — confusing reads and writes: `load` accepts only `Relaxed`/`Acquire`/`SeqCst`; `store` accepts only `Relaxed`/`Release`/`SeqCst`. Compile error on stable, but flag it as a sign the author has not internalized which half of the pair each operation occupies.

`[FILE:LINE] FETCH_ADD_RELAXED_FOR_LOCK_ACQUIRE` — `fetch_add(1, Relaxed)` used to acquire a slot in a ring buffer or to claim a critical section. The increment publishes the claim; observers must synchronize. Use `AcqRel` (or `Acquire` if there is no publication on this RMW).

`[FILE:LINE] ARC_DROP_MISSING_ACQUIRE_FENCE` — `fetch_sub(1, Release) == 1` branch without a subsequent `fence(Acquire)` before freeing. The dropping thread must synchronize with all prior `Release` decrements before touching the data.

## Tooling Notes

Most real memory-ordering bugs hide on weakly-ordered platforms. x86-64's strong model masks them; ARM64 and RISC-V expose them. CI that runs only on x86 Linux / macOS Intel will not catch `Relaxed`-where-`Release`-belongs. Apple Silicon (M-series) and `aarch64-unknown-linux-gnu` are the practical reproduction targets.

- **`cargo +nightly miri test`** detects data races, use-after-free, uninit reads, and a subset of memory-ordering violations along the executed path. Slow but precise. Required in CI for any crate with `unsafe` touching atomics or `UnsafeCell`.
- **`loom`** is a model checker that explores possible thread interleavings. Replace `std::sync::{Arc, Mutex, atomic::*}`, `std::thread`, and `std::cell::UnsafeCell` with `loom::sync::*`, `loom::thread`, and `loom::cell::UnsafeCell` under `#[cfg(loom)]`. Loom under-approximates `Relaxed` reordering — pair with Miri's `-Zmiri-many-seeds` for `Relaxed`-heavy code.
- **`-Zmiri-tree-borrows`** opts into the newer Tree Borrows aliasing model, which catches more subtle pointer-aliasing bugs in `unsafe` code.

See [../../rust-testing-code-review/references/concurrency-testing.md](../../rust-testing-code-review/references/concurrency-testing.md) for loom and Miri test patterns.

`[FILE:LINE] CONCURRENT_UNSAFE_NO_MIRI` — `unsafe` block touching atomics or `UnsafeCell` in a crate without `cargo +nightly miri test` in CI.

`[FILE:LINE] LOCKFREE_NO_LOOM` — hand-rolled lock-free data structure without a `#[cfg(loom)]` test harness.

## Mara Bos's Quotable Rules

> "Don't use `SeqCst` unless you actually need it."

`SeqCst` is the strongest ordering and the easiest to reach for, but every `SeqCst` operation on ARM emits `dmb ish` (full memory barrier), and the only thing `SeqCst` provides over `AcqRel` is a single global total order across *different* atomics. If the reviewer cannot name two `SeqCst` operations whose relative order is load-bearing, the ordering is decorative. Downgrade to `Acquire`/`Release` or `Relaxed` and re-prove correctness.

> "Out-of-thin-air values are a theoretical artifact, not a practical concern."

The C++/Rust memory model allows, in principle, `Relaxed` loads to "fabricate" values from circular self-dependencies. No real compiler or CPU does this; the standards bodies acknowledge it as a model defect. Do not let it scare you off `Relaxed` when the code is otherwise correct. (Inversely: do not use it to justify `Relaxed` where `Release`/`Acquire` is required for data publication — those are unrelated concerns.)

> "Release-Acquire only synchronizes the two specific atomics, not the threads as a whole."

A `Release` store on atomic `X` only forms a happens-before edge with `Acquire` loads of `X` that observe that store. It does not give blanket synchronization between the two threads on all other atomics or shared memory. If thread B needs to observe writes that thread A made before storing to `Y`, B must `Acquire`-load `Y`, not `X`. Reviewers should ask: "which atomic is the synchronization edge, and what data does it protect?"

## Quick Reference

| Pattern | Store / RMW Ordering | Load Ordering | Notes |
| --- | --- | --- | --- |
| Stop flag, counter, statistic | `Relaxed` | `Relaxed` | No other data piggybacks on the atomic. |
| Publish flag, observe-then-read data | `Release` | `Acquire` | Workhorse pair. Most synchronization fits here. |
| Lock acquire via `swap`/CAS | `Acquire` (RMW) | n/a | Pair with `Release` store on unlock. |
| Lock release | `Release` (store) | n/a | Pair with `Acquire` on the next acquire. |
| `compare_exchange` success / failure | `Acquire` / `Relaxed` | n/a | Bump success to `AcqRel` if CAS itself publishes. |
| Refcount increment (clone) | `Relaxed` (RMW) | n/a | Caller already has access; no publication. |
| Refcount decrement (drop) | `Release` (RMW) | n/a | Pair with `fence(Acquire)` on final decrement. |
| Refcount last-drop fence | `fence(Acquire)` | n/a | Only the dropping thread pays for ordering. |
| CAS-spin (lock attempt loop) | `Acquire` (success), `Relaxed` (failure) | `Relaxed` (preliminary load) | Use `compare_exchange_weak`. |
| Dekker / store-then-load across two atomics | `SeqCst` | `SeqCst` | Document why a global total order is required. |
