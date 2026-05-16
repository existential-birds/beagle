# Concurrency Testing

Testing hand-rolled concurrent Rust requires tools that `cargo test` cannot
provide. This reference focuses on `loom`, `cargo miri`, and complementary
tools used to *review* tests for concurrent code. For the patterns being
tested, see [../../rust-code-review/references/concurrency-primitives.md],
[../../rust-code-review/references/memory-ordering.md], and
[../../rust-code-review/references/lock-free-patterns.md].

## 1. Why concurrent code needs special testing

`cargo test` runs each test in a single OS thread (or up to
`--test-threads=N` worker threads, one test per worker). Within a single
test, every `thread::spawn` produces *one* interleaving of memory
operations. That interleaving is whatever the OS scheduler happened to
produce on this run, on this CPU, under this load. The next run may
produce the same interleaving a million times in a row.

Atomic ordering bugs are non-deterministic and platform-dependent. The
canonical example is `Relaxed` used on a flag that publishes non-atomic
data: x86-64's strong memory model effectively promotes `Relaxed` to
`Release`, so the bug is invisible there. ARM64 and RISC-V reorder
freely, and the same code corrupts ~0.4% of operations on Apple M1
(Mara Bos, *Rust Atomics and Locks*, Chapter 7). "Passes on CI" is not
evidence when CI is x86-64.

The Rust compiler *does not* catch atomic ordering bugs. The book is
explicit: the "fearless concurrency" claim covers data races (the
borrow checker prevents two threads from holding `&mut T`), not memory
ordering. `Acquire`/`Release`/`SeqCst` are *contracts*; the compiler
enforces type signatures (`load(Release)` panics, `load(AcqRel)`
panics), not happens-before relationships.

Two tools change this:

- **`loom`** — a model checker. Replaces `std::sync` and `std::thread`
  with versions that explore every legal interleaving of memory
  operations, then runs each interleaving to find the one that violates
  your assertions.
- **`cargo miri`** — a MIR interpreter. Runs your test under a model
  that catches undefined behavior (uninit reads, use-after-free,
  alignment violations, data races, certain weak-memory observations,
  Stacked/Tree Borrows violations).

They are complementary, not redundant. Loom explores *which*
interleaving could fail; Miri checks *whether* a given interleaving has
UB. Neither subsumes the other.

### Review checks

- `[FILE:LINE] CONCURRENT_CODE_NO_LOOM_TESTS` — module uses raw atomics,
  `UnsafeCell`, hand-rolled `Mutex`/channel/refcount, or `unsafe impl
  Send/Sync`, and has no `#[cfg(loom)]` test harness.
- `[FILE:LINE] UNSAFE_HEAVY_NO_MIRI` — crate has non-trivial `unsafe`
  blocks touching atomics or pointer arithmetic with no `cargo +nightly
  miri test` step in CI.
- `[FILE:LINE] X86_ONLY_TEST_COVERAGE` — concurrency tests run only on
  `target_arch = "x86_64"` (no ARM64/aarch64 runner, no loom).

## 2. `loom`

`loom = "0.7"` (current stable line) is a *permutation-testing model
checker* for concurrent Rust. It replaces `std::sync::{Arc, Mutex,
RwLock, Condvar, atomic::*}`, `std::thread`, and `std::cell::UnsafeCell`
with versions that record every operation and explore alternative
interleavings.

`loom::model(|| { ... })` runs the closure repeatedly with different
schedules until it has explored every legal interleaving (or hits the
preemption bound). A single `model` call may execute the closure
thousands to millions of times.

### Setup

```toml
[dev-dependencies]
loom = "0.7"
```

Conditional import pattern at the top of the module under test:

```rust
#[cfg(loom)]      use loom::sync::Arc;
#[cfg(loom)]      use loom::sync::atomic::AtomicUsize;
#[cfg(loom)]      use loom::thread;
#[cfg(not(loom))] use std::sync::Arc;
#[cfg(not(loom))] use std::sync::atomic::AtomicUsize;
#[cfg(not(loom))] use std::thread;
```

Same trick for `UnsafeCell`, `Mutex`, `RwLock`, `Condvar`.

### Running

```bash
RUSTFLAGS="--cfg loom" cargo test --release --test loom_tests
LOOM_MAX_PREEMPTIONS=3 RUSTFLAGS="--cfg loom" \
    cargo test --release --test loom_tests
```

Notes:

- `--release` is mandatory in practice — debug-mode loom is 10–50×
  slower, often pushing test runs past CI timeouts.
- `LOOM_MAX_PREEMPTIONS=N` bounds exploration: most real bugs surface
  at `N=2` or `N=3`. Higher `N` explodes combinatorially.
- Place loom tests in a separate `tests/loom_tests.rs` (or
  `--test <name>`) so the `cfg(loom)` flag does not poison the normal
  test build.

### Canonical loom test

```rust
#[test]
fn arc_does_not_use_after_free() {
    loom::model(|| {
        let a = Arc::new(AtomicUsize::new(0));
        let b = a.clone();
        let t = thread::spawn(move || { b.store(1, Release); });
        let _ = a.load(Acquire);
        t.join().unwrap();
    });
}
```

### Limitations

- Caps around 64 threads; exponential blow-up means real tests use 2–4
  threads and small loops.
- Does not faithfully model every `Relaxed` reordering (it
  under-approximates weak memory — covers DRF-SC, not all of C++20).
  Pair with Miri for orderings you suspect are too weak.
- Cannot model OS-level effects (signals, real timing, real IO).
- Tests must be deterministic. Random numbers, system clock, hash map
  iteration order bias the search and produce phantom "passes."

### BAD: loom test using `std::sync`

```rust
// BAD — uses std types, so loom sees zero interleavings.
#[test]
fn channel_send_recv() {
    loom::model(|| {
        let c = std::sync::Arc::new(MyChannel::new());
        let s = c.clone();
        std::thread::spawn(move || s.send(42));
        assert_eq!(c.recv(), 42);
    });
}
```

### GOOD: loom test using loom shims

```rust
#[test]
fn channel_send_recv() {
    loom::model(|| {
        let c = Arc::new(MyChannel::new());  // loom::sync::Arc under cfg(loom)
        let s = c.clone();
        thread::spawn(move || s.send(42));   // loom::thread under cfg(loom)
        assert_eq!(c.recv(), 42);
    });
}
```

### BAD: nondeterministic body

```rust
// BAD — std::time::Instant is not under loom's control; results vary
// run-to-run, defeating exhaustive exploration.
loom::model(|| {
    let start = std::time::Instant::now();
    let v = Arc::new(AtomicUsize::new(0));
    thread::spawn({ let v = v.clone(); move || v.store(start.elapsed().as_nanos() as usize, Relaxed) });
});
```

### BAD: debug-mode loom

```bash
# BAD — no --release, 10-50x slower; CI gives up before exploration completes.
RUSTFLAGS="--cfg loom" cargo test --test loom_tests
```

### Review checks

- `[FILE:LINE] LOOM_TEST_USES_STD_SYNC` — `loom::model` body imports
  `std::sync::Arc`, `std::sync::Mutex`, `std::sync::atomic::*`, or
  `std::thread::spawn` instead of the `loom::*` shims.
- `[FILE:LINE] LOOM_TEST_USES_STD_UNSAFECELL` — `loom::model` over code
  that uses `std::cell::UnsafeCell`; loom cannot track those accesses.
- `[FILE:LINE] LOOM_TEST_NONDETERMINISTIC` — body uses `Instant::now`,
  `SystemTime::now`, `rand::*`, `HashMap` iteration, or environment
  reads; loom needs deterministic inputs to enumerate schedules.
- `[FILE:LINE] LOOM_TEST_MISSING_RELEASE` — Cargo invocation lacks
  `--release`; debug-mode loom is too slow to be useful in CI.
- `[FILE:LINE] LOOM_TEST_NO_PREEMPTION_BOUND` — no `LOOM_MAX_PREEMPTIONS`
  set on a long-running test (risks CI timeout) or set absurdly high
  (`>=5`) without justification.
- `[FILE:LINE] LOOM_TEST_LIVES_IN_UNIT_TESTS` — `loom::model` invoked
  inside `#[cfg(test)] mod tests` next to non-loom unit tests, so the
  `--cfg loom` build pollutes regular `cargo test`.
- `[FILE:LINE] LOOM_RELAXED_REORDERING_ASSUMED` — test relies on loom
  to surface a `Relaxed`-only reorder; loom under-approximates this
  axis — also run under Miri with `-Zmiri-many-seeds`.

## 3. `cargo miri`

Miri is a Rust interpreter that executes your test against a model of
the language semantics rather than against real CPU instructions. It
catches undefined behavior that real hardware silently tolerates:
out-of-bounds pointer access, use-after-free, uninitialized reads,
misaligned accesses, invalid enum/bool/char bit patterns, data races
without synchronization, broken intrinsic preconditions, and aliasing
violations under Stacked Borrows or Tree Borrows.

### Install and run

```bash
rustup +nightly component add miri
cargo +nightly miri test
cargo +nightly miri test -- --test-threads=1   # if isolation matters
```

Miri requires nightly. Pin the nightly version (`rust-toolchain.toml`)
so CI does not break when miri lags `rustc`.

### Useful `MIRIFLAGS`

```bash
# Strict pointer provenance — catches pointer/usize round-trip bugs.
MIRIFLAGS="-Zmiri-strict-provenance" cargo +nightly miri test

# Tree Borrows — newer aliasing model; catches more aliasing bugs than
# Stacked Borrows.
MIRIFLAGS="-Zmiri-tree-borrows" cargo +nightly miri test

# Re-run with many non-determinism seeds (allocator addresses, atomic
# scheduling). Surfaces flaky weak-memory bugs.
MIRIFLAGS="-Zmiri-many-seeds=0..16" cargo +nightly miri test

# Allow filesystem / time / env access. Use sparingly; defeats isolation.
MIRIFLAGS="-Zmiri-disable-isolation" cargo +nightly miri test
```

### Limitations

- Slow: 10–100× test runtime. Budget for it; do not gate every PR on a
  full workspace Miri run if the suite is large.
- Does not model real OS scheduling — Miri's concurrency is its own
  interpreter scheduler. Pair with loom for interleaving exploration.
- Cannot run inline asm, syscalls, FFI to non-Rust code. Mark such
  tests `#[cfg_attr(miri, ignore)]`.
- Under-approximates weak memory in single runs — that is what
  `-Zmiri-many-seeds=0..16` is for.

### Loom + Miri pairing

| Tool | Catches | Misses |
|---|---|---|
| `loom` | wrong interleavings, missing happens-before, lost wakeups | UB within a single interleaving |
| `miri` | UB on the executed path, aliasing, uninit, alignment, data races | most interleavings (single schedule per run) |
| both | interleavings that produce UB | OS scheduling, real timing, FFI |

Standard recipe for any module with `unsafe` + atomics: loom tests on a
nightly/labeled job, Miri test pass on every PR, property tests for
shape variation.

### BAD: skipping Miri on release-only CI

```yaml
# BAD — only runs on release branches; unsafe regressions land on main.
on: push:
  branches: [release/*]
jobs:
  miri:
    steps:
      - run: cargo +nightly miri test
```

### BAD: Miri without feature coverage

```bash
# BAD — default features only; the `unsafe-fast-path` feature, which is
# the whole reason for the unsafe code, is never exercised.
cargo +nightly miri test
# GOOD
cargo +nightly miri test --all-features
```

### BAD: blanket-ignoring under Miri

```rust
// BAD — entire module is excluded, including pure-safe tests Miri could
// run cheaply. Ignore at the test-function granularity instead.
#![cfg_attr(miri, ignore)]
```

### Review checks

- `[FILE:LINE] MIRI_NOT_IN_CI` — crate has any `unsafe { ... }` block
  touching atomics, pointers, or `UnsafeCell` and no `cargo +nightly
  miri test` step in CI.
- `[FILE:LINE] MIRI_CI_RELEASE_ONLY` — Miri runs only on release tags
  or nightly cron; unsafe regressions slip into main between runs.
- `[FILE:LINE] MIRI_EXCLUDES_FEATURE_FLAGS` — `cargo miri test` invoked
  without `--all-features` (or without the specific feature gating the
  unsafe path).
- `[FILE:LINE] MIRI_IGNORE_TOO_BROAD` — `#![cfg_attr(miri, ignore)]` at
  module or crate level rather than per-test on the FFI/syscall cases
  that actually need it.
- `[FILE:LINE] MIRI_NO_STRICT_PROVENANCE` — code performs `usize ↔ ptr`
  casts and CI does not set `MIRIFLAGS=-Zmiri-strict-provenance`.
- `[FILE:LINE] MIRI_NO_TREE_BORROWS` — code uses heavy raw-pointer
  aliasing (intrusive lists, lock-free) and CI does not run a
  `-Zmiri-tree-borrows` job; Stacked Borrows alone misses some bugs.

## 4. Other tools

### `shuttle` (AWS)

`shuttle` is a randomized concurrency tester. Same API surface as loom
(replaces `std::sync`/`std::thread`), but instead of exhaustively
exploring all interleavings, it samples N random schedules. Less
rigorous than loom but scales to bigger code under test, so it works on
codebases where loom's combinatorics blow up. Treat it as complementary
to loom, not a substitute for hand-rolled lock-free correctness work.

### `cargo nextest run -j1`

A common confusion: `nextest run -j1` runs *tests* on a single thread
(one test process at a time). It does **not** force a test's *internal*
`thread::spawn` calls to run serially. It does nothing for concurrency
bugs inside the code under test. Flag any reviewer comment claiming
otherwise.

### `kani` and `prusti`

Formal verification tools for restricted subsets of Rust. Out of scope
for most production code, but worth knowing for kernel modules, OS
primitives, and cryptographic implementations that justify proof
effort.

### ThreadSanitizer (`-Z sanitizer=thread`)

Nightly-only sanitizer that instruments compiled code to detect data
races at runtime. Catches races that miri misses when the race spans
FFI into a non-Rust dependency (Miri cannot enter FFI). Useful for
crates with `unsafe extern "C"` boundaries.

```bash
RUSTFLAGS="-Z sanitizer=thread" cargo +nightly test \
    --target x86_64-unknown-linux-gnu
```

### Review checks

- `[FILE:LINE] NEXTEST_J1_AS_CONCURRENCY_FIX` — comment or commit
  message claims `nextest run -j1` "tests for race conditions"; it does
  not.
- `[FILE:LINE] FFI_HEAVY_NO_TSAN` — crate has `unsafe extern "C"`
  blocks calling C/C++ libraries and CI has no ThreadSanitizer job;
  Miri cannot see into the FFI side.

## 5. CI integration

A workable matrix for an unsafe-heavy concurrency crate:

| Job | Toolchain | Trigger | Command |
|---|---|---|---|
| unit + integration | stable | every PR | `cargo test --workspace --all-features` |
| miri | nightly (pinned) | every PR | `cargo +nightly miri test --workspace --all-features` |
| loom | stable | label `concurrency` or nightly cron | `RUSTFLAGS="--cfg loom" cargo test --release --test loom_tests` |
| tsan | nightly | nightly cron | `RUSTFLAGS="-Z sanitizer=thread" cargo +nightly test` |

The general principle: a "tests pass" claim must specify *which* of
these jobs passed. "All green on x86_64-unknown-linux-gnu without
loom or miri" is not the same evidence as a full matrix.

### BAD: unspecified test pass claim

```text
PR description: "Tests pass." (No CI link, no mention of which jobs.)
```

The reviewer cannot tell whether the unsafe path was exercised. Demand
specifics: cargo test passed, miri passed with `--all-features`, loom
passed for the affected modules.

### BAD: loom job runs on debug

```yaml
# BAD — no --release, slow, may timeout, exploration incomplete.
- run: RUSTFLAGS="--cfg loom" cargo test --test loom_tests
```

### Review checks

- `[FILE:LINE] CI_PASS_CLAIM_UNQUALIFIED` — PR claims "tests pass"
  without naming the toolchains/jobs; loom and miri may have been
  skipped.
- `[FILE:LINE] CI_LOOM_NO_RELEASE` — CI loom job omits `--release`,
  making the job too slow to complete real exploration.

## 6. Patterns that always need a concurrency test

| Pattern | Required test |
|---|---|
| `unsafe impl Send for X {}` / `unsafe impl Sync for X {}` | loom test exercising the invariant that justifies the impl; comment naming the safety argument |
| New atomic state machine (multi-state futex, three-state mutex) | loom test reaching every state from every other state |
| Lock-free data structure (`AtomicPtr`-based stack/queue/list) | loom **and** miri (Stacked Borrows + Tree Borrows) **and** `proptest`-driven operation sequences |
| Custom `Drop` reading shared atomic state | loom test for drop-during-access (one thread mid-operation while another drops) |
| Hand-rolled refcount with `fetch_sub(1, Release) + fence(Acquire)` | loom test exercising the last-decrement path and a non-last decrement |
| Channel with `MaybeUninit<T>` and a `ready` flag | loom test for send-then-receive plus drop-without-receive (Drop must observe the flag) |

### Review checks

- `[FILE:LINE] UNSAFE_SEND_SYNC_NO_LOOM_TEST` — `unsafe impl (Send|Sync)
  for X` with no corresponding `loom::model` test demonstrating the
  invariant.
- `[FILE:LINE] LOCKFREE_STRUCT_MISSING_BOTH_TOOLS` — module defines a
  lock-free queue/stack/list and exercises it under loom but not Miri,
  or under Miri but not loom; lock-free code needs both.
- `[FILE:LINE] CUSTOM_DROP_NO_RACE_TEST` — type with shared
  `AtomicUsize`/`AtomicPtr` state and a non-trivial `Drop` has no test
  for drop-while-another-thread-still-accessing.
- `[FILE:LINE] REFCOUNT_LAST_DECREMENT_UNTESTED` — `fetch_sub(1,
  Release)` + `fence(Acquire)` pattern with no loom test that covers
  both the last-decrement and non-last-decrement branches.
