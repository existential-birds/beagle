# Advanced Testing

## Fuzzing

Fuzzing generates semi-random inputs to find crashes. Modern fuzzers use code coverage to explore paths efficiently. Use for parsers, deserializers, codec implementations, and anything accepting untrusted input.

### cargo-fuzz with libfuzzer

```rust
#![no_main]
use libfuzzer_sys::fuzz_target;

fuzz_target!(|data: &[u8]| {
    if let Ok(s) = std::str::from_utf8(data) {
        let _ = url::Url::parse(s); // looking for panics, not checking results
    }
});
```

For complex types, derive `Arbitrary` to convert raw bytes into structured inputs:

```rust
#[derive(arbitrary::Arbitrary, Debug)]
struct FuzzInput { key: String, value: Vec<u8>, ttl: u32 }

fuzz_target!(|input: FuzzInput| {
    let mut cache = Cache::new();
    cache.insert(&input.key, &input.value, input.ttl);
});
```

**Flag when:**
- Fuzz targets exist without a `corpus/` directory (no seed inputs)
- Fuzz targets check return values instead of letting panics surface
- Parsers or protocol handlers lack fuzz targets entirely

## Property-Based Testing

Verifies invariants hold across generated inputs rather than checking specific cases.

```rust
use proptest::prelude::*;

proptest! {
    #[test]
    fn round_trip_serialization(input in any::<MyStruct>()) {
        let bytes = input.serialize();
        let decoded = MyStruct::deserialize(&bytes).unwrap();
        prop_assert_eq!(input, decoded);
    }

    #[test]
    fn sort_is_idempotent(mut v in prop::collection::vec(any::<i32>(), 0..100)) {
        v.sort();
        let sorted = v.clone();
        v.sort();
        prop_assert_eq!(v, sorted);
    }
}
```

Test stateful types with operation sequences via `Vec<Op>` where `Op` is an enum of possible actions. Testers minimize failing sequences automatically.

**Flag when:**
- proptest strategies are overly narrow (e.g., `1..5` when valid range is `0..u64::MAX`)
- Property tests check only success, not invariants (no `prop_assert!`)
- Data structures lack operation-sequence testing for stateful invariants

## Miri

Miri interprets Rust's MIR to detect undefined behavior in unsafe code. Run with `cargo +nightly miri test`.

**Catches:** Uninitialized memory reads, use-after-free, out-of-bounds pointer access, invalid exclusive references (Stacked Borrows violations), misaligned accesses.
**Misses:** Data races (use Loom), logic bugs, performance issues, FFI calls to non-Rust code.

**Flag when:**
- Crate contains `unsafe` blocks but CI does not run `cargo miri test`
- Miri is disabled for tests that exercise unsafe code paths
- Raw pointer arithmetic lacks Miri coverage

## Loom

Exhaustively tests concurrent code by exploring all thread interleavings at synchronization points.

```rust
#[test]
fn concurrent_counter() {
    loom::model(|| {
        let counter = loom::sync::Arc::new(loom::sync::atomic::AtomicUsize::new(0));
        let c1 = counter.clone();
        let t = loom::thread::spawn(move || {
            c1.fetch_add(1, Ordering::SeqCst);
        });
        counter.fetch_add(1, Ordering::SeqCst);
        t.join().unwrap();
        assert_eq!(counter.load(Ordering::SeqCst), 2);
    });
}
```

**When to use Loom:** Lock-free data structures, custom synchronization primitives, code using `Ordering` weaker than `SeqCst`. Regular `#[tokio::test]` is sufficient for high-level async workflows.

**Flag when:**
- Lock-free or atomic-based concurrency code has only regular tests
- Loom tests use `std::sync` instead of `loom::sync` (defeats the purpose)

## Benchmarking Rigor

### criterion with black_box

```rust
use criterion::{black_box, criterion_group, criterion_main, Criterion};

fn bench_parse(c: &mut Criterion) {
    let input = "https://example.com/path?query=value";
    c.bench_function("url_parse", |b| {
        b.iter(|| url::Url::parse(black_box(input)))
    });
}

criterion_group!(benches, bench_parse);
criterion_main!(benches);
```

Without `black_box`, the compiler may eliminate the entire computation as dead code. Use `black_box` on mutable pointer (`as_ptr()`) rather than shared reference -- the compiler can legally assume shared references are not mutated.

**Flag when:**
- Benchmarks do not use `black_box` on inputs or outputs
- Benchmark loop body includes I/O (`println!`, logging) or RNG that dominates measured time
- Benchmarks run once instead of using criterion's statistical sampling
- No `harness = false` in `Cargo.toml` for criterion benchmark targets

## compile_fail Tests

Verify code correctly fails to compile. Useful for type-level safety guarantees (Send, Sync, lifetimes).

**Doctests:** `compile_fail` attribute on doc code blocks. Crude -- passes for any compilation failure including typos.
**trybuild:** Fine-grained compile-fail testing. Each `.rs` file in `tests/ui/` has a matching `.stderr` with the expected error.

```rust
#[test]
fn compile_fail_tests() {
    let t = trybuild::TestCases::new();
    t.compile_fail("tests/ui/*.rs");
}
```

**Flag when:**
- `compile_fail` doctests lack a comment explaining which error is expected
- Crate enforces type-level invariants without compile_fail tests
- trybuild `.stderr` files are outdated after a rustc version bump

## Test Harness Customization

Set `harness = false` in `Cargo.toml` for custom test runners (fuzzers, model checkers, criterion benchmarks, WebAssembly targets). Without the harness, `#[test]` attributes are silently ignored -- you write your own `main`.

**Flag when:**
- `harness = false` set but test file still uses `#[test]` attributes
- Custom harness does not handle `--test-threads` or `--nocapture` when needed

## Mocking Strategies

**Trait-based (primary pattern):** Make code generic over traits, substitute mocks in tests. See [integration-tests.md](integration-tests.md) for async trait mock examples.
**Conditional compilation:** Use `#[cfg(test)]` to swap implementations when generics are inconvenient (e.g., deterministic timestamps, fixed randomness).
**mockall:** Generates mocks via `#[automock]`. Set `times()` constraints on expectations to catch unexpected call counts.

```rust
#[automock]
trait Storage {
    fn get(&self, key: &str) -> Option<String>;
    fn set(&self, key: &str, value: &str);
}

#[test]
fn cache_miss_fetches_from_source() {
    let mut mock = MockStorage::new();
    mock.expect_get().with(eq("key")).returning(|_| None);
    mock.expect_set().with(eq("key"), eq("value")).times(1).return_const(());
    let svc = Service::new(mock);
    svc.fetch("key");
}
```

**Flag when:**
- Mocking external types directly instead of wrapping behind an owned trait
- `#[cfg(test)]` mocks change behavior that could mask production bugs
- mockall expectations lack `times()` constraints

## Review Rules Summary

| Pattern | Flag When |
|---------|-----------|
| Fuzzing | Parsers/deserializers lack fuzz targets; targets have no corpus |
| Property testing | Strategies too narrow; missing `prop_assert!` invariants |
| Miri | `unsafe` code not covered by `cargo miri test` in CI |
| Loom | Lock-free code tested only with regular `#[test]` |
| Benchmarks | Missing `black_box`; I/O in benchmark loop; no statistical sampling |
| compile_fail | No explanation of expected error; stale `.stderr` files |
| Custom harness | `#[test]` used alongside `harness = false` |
| Mocking | External types mocked directly; cfg(test) mocks skip validation |

## Test Augmentation Taxonomy

The earlier "Mocking Strategies" section conflates four distinct patterns. The taxonomy below makes the distinctions Jon Gjengset draws in *Rust for Rustaceans* Ch 6 explicit. Pick the lightest pattern that proves what you need.

- **Stub** — returns canned values for a fixed input shape. No state, no recording, no expectations. A function `fn now() -> Instant { fixed }` is a stub. Use when the test only needs a deterministic input to a downstream computation.
- **Fake** — a working alternative implementation of the same trait/contract, with simplified internals (in-memory `HashMap` backing a `Repository`, in-memory `VecDeque` backing a `Queue`, a deterministic monotonic clock). Has state and correct end-to-end behavior; just smaller, faster, and process-local. Use when the production code is generic over the trait.
- **Mock** — pre-programmed with expectations. The test declares "this method must be called N times with these arguments" up front. Tears down with assertion failures if expectations aren't met. `mockall::automock` is the standard tool. Use when the *interaction pattern* itself is the property under test.
- **Spy** — records calls in a `Vec<(method, args)>` field without expectations. The test inspects the recording after the fact. Use when calls are unordered or branch-dependent and a mock's strict expectation graph is too rigid.

**Trait-as-seam pattern.** Production code is generic over a trait the test substitutes. The seam lives at the trait boundary, not at `#[cfg(test)]` swaps:

```rust
pub trait Repository {
    fn get(&self, id: u64) -> Option<Row>;
    fn put(&self, row: Row);
}

pub struct Service<R: Repository> { repo: R }
// production: Service<PgRepository>
// tests:      Service<InMemoryRepository>  // a fake
```

The `InMemoryRepository` fake implements `Repository` with a `Mutex<HashMap<u64, Row>>`. Tests exercise the real `Service` logic against a process-local store; no `#[cfg(test)]` divergence in the production code path.

Review checks:

- [FILE:LINE] MOCKALL_WHERE_FAKE_FITS — Test uses `#[automock]` to script `expect_get().returning(|_| Some(row))` for many calls, when an in-memory fake implementing the same trait would be smaller, more readable, and exercise the production code path identically.
- [FILE:LINE] FAKE_DIVERGES_FROM_PROD — In-memory `Repository` fake silently sorts entries or returns insertion order, but the production Postgres implementation returns rows by primary key. Tests will pass against bugs the production wiring exposes.
- [FILE:LINE] NO_TRAIT_SEAM — `Service` directly owns a `PgPool`. There is no trait boundary to substitute in tests, so every test must spin up Postgres. Introduce a `Repository` trait and parameterize `Service` over it.
- [FILE:LINE] SPY_PRESENTED_AS_MOCK — A struct records calls into a `Vec` but is named `MockFoo` and reviewed as if it asserts. The test inspects the vec after, so it's a spy. Rename and document, or add explicit `expect_*` assertions.
- [FILE:LINE] STUB_LEAKS_TEST_API — Stub returns hard-coded data via a `pub fn for_tests()` constructor that is reachable from production builds. Gate behind `#[cfg(test)]` or move to `tests/common/`.

## Test Generation Strategies

Beyond hand-written `#[test] fn` and the `rstest` examples in [integration-tests.md](integration-tests.md), four generation strategies cover most data shapes.

- **`rstest` with `#[case(...)]`** — table-driven tests with descriptive case names. Each `#[case]` becomes a separately-named test in cargo output. Good for a small, hand-curated set of inputs where each row tells a story (each `#[case]` documents one behavior).
- **`rstest` matrix** — Cartesian product across parameters via `#[values(a, b, c)]` on each argument. Three values on one axis and three on another yields nine generated tests. Good when every combination must be exercised and the cases share assertions:

  ```rust
  use rstest::rstest;
  #[rstest]
  fn handles_combinations(
      #[values("ascii", "utf8", "mixed")] encoding: &str,
      #[values(0, 1, 1024)] size: usize,
  ) {
      assert!(roundtrip(encoding, size).is_ok());
  }
  ```

- **`paste!` macro** — generates uniquely-named `#[test] fn` for a list of inputs by concatenating identifiers. Use when each input deserves a stable, greppable name in CI output (e.g., one test per supported format), and the body is identical except for one substitution.
- **`build.rs`-generated tests** — for large input corpora (parser fixtures, compiler conformance suites, golden files). The build script writes one `#[test] fn case_<name>` per file in `tests/fixtures/`, included via `include!(concat!(env!("OUT_DIR"), "/generated_tests.rs"))`. Good when the test set grows by adding files, not by editing Rust.

Pick by intent: hand-curated stories use `#[case]`; combinatorial coverage uses matrix; stable per-input names use `paste!`; large file-driven corpora use `build.rs`.

Review checks:

- [FILE:LINE] HANDROLLED_PARAMETERIZED_TESTS — Test file contains 12 copy-pasted `#[test]` functions that vary only in input literals. Replace with `#[rstest] #[case(...)]` so cargo output names each row.
- [FILE:LINE] MATRIX_EXPANSION_TOO_LARGE — `rstest` matrix with `#[values]` over four axes generates 10,000+ tests. CI runtime balloons. Either reduce axes, sample with proptest, or move to a corpus.
- [FILE:LINE] PASTE_INSTEAD_OF_RSTEST — `paste!` macro generates tests when `rstest` `#[case]` would do, losing rstest's per-case failure reporting and IDE integration.
- [FILE:LINE] BUILD_RS_TESTS_NOT_DETERMINISTIC — `build.rs` walks `tests/fixtures/` with `read_dir` (filesystem order is unspecified). CI test names differ between machines. Sort the directory listing.
- [FILE:LINE] GENERATED_TESTS_NO_RERUN_IF_CHANGED — `build.rs` emits tests from a fixture directory but does not call `cargo:rerun-if-changed=tests/fixtures`. Adding a fixture file does not regenerate the test list.

## Criterion Specifics

Criterion is the de facto Rust benchmark harness. The basics appeared in "Benchmarking Rigor" above. The points below are what reviewers should actually check on.

- **Statistical confidence.** Criterion runs each benchmark for many iterations, computes mean and variance, and applies bootstrap resampling to produce a confidence interval. A single timing is meaningless; criterion's number is the mean of the distribution with a stated CI. Reject benchmarks reported as `Instant::now(); work(); start.elapsed()` one-shot timings.
- **Baselines.** `cargo bench -- --save-baseline main` saves a named baseline. On a PR branch, `cargo bench -- --baseline main` compares the current run against it; criterion reports `change: -3.2% (-4.5%, -2.0%)` with a confidence interval and classifies the result (Improved / Regressed / No change). CI should save a baseline on merge to trunk and compare against it on every PR.
- **`black_box` discipline.** `criterion::black_box` is the prevent-constant-folding marker. For pointer-backed inputs use `black_box(input.as_ptr())` — the optimizer can't reason through pointer arithmetic. `black_box(&input)` is sometimes optimized away because the compiler can legally assume `&T` is not mutated.
- **`iter_batched`.** For benchmarks needing fresh setup per iteration (mutating a vec, draining a channel), `bencher.iter_batched(setup, routine, BatchSize::SmallInput)` runs `setup` uncounted and the `routine` closure counted. Without `iter_batched`, the setup cost pollutes the measurement or worse, the second iteration runs on already-mutated state.

  ```rust
  use criterion::{black_box, BatchSize, Criterion};
  fn bench_drain(c: &mut Criterion) {
      c.bench_function("drain_vec", |b| {
          b.iter_batched(
              || (0..1024).collect::<Vec<u32>>(),
              |mut v| { for x in v.drain(..) { black_box(x); } },
              BatchSize::SmallInput,
          );
      });
  }
  ```

- **`--profile bench`.** Release optimizations with debug symbols retained, so `cargo flamegraph --bench foo` can correlate samples to source lines. Set `[profile.bench] debug = true` (or `debug = "line-tables-only"` for smaller binaries).
- **I/O isolation.** Any file open, network call, or RNG seed belongs in the `setup` closure of `iter_batched` (or before `b.iter`), not inside the measured closure. Otherwise the benchmark times the OS, not your code.

Review checks:

- [FILE:LINE] BENCH_NO_BLACK_BOX_ON_RESULT — Benchmark closure's return value is dropped without `black_box`. The compiler can prove the value is unused and eliminate the computation. Wrap with `black_box(result)`.
- [FILE:LINE] BENCH_IO_IN_MEASURED_CLOSURE — `File::open` or `TcpStream::connect` inside `b.iter`. Move to `iter_batched` setup so I/O cost is excluded.
- [FILE:LINE] BENCH_NO_BASELINE_IN_CI — `criterion_group!` exists but no CI job runs `--save-baseline` on trunk merges or `--baseline` on PRs. Regressions ship undetected. Add a CI step gating PRs on the comparison.
- [FILE:LINE] BENCH_NO_REGRESSION_THRESHOLD — CI runs criterion comparison but does not fail the job on `Regressed`. Add a script that greps criterion output or use `criterion-compare-action`.
- [FILE:LINE] ITER_BATCHED_NOT_USED_FOR_MUTATION — Benchmark calls `b.iter(|| my_vec.drain(..))` where `my_vec` is captured by reference. The second iteration runs on an empty vec. Use `iter_batched` to rebuild input each iteration.

## trybuild for Proc-Macro UI Tests

`trybuild::TestCases` runs `.rs` files in `tests/ui/` through the compiler and compares stderr against a sibling `.stderr` file. Use it to confirm a proc-macro emits the expected diagnostic for invalid input (a derive macro applied to a union, a function-like macro fed wrong syntax, an attribute macro on the wrong item kind). The mechanism is described in [../../macros-code-review/references/procedural-macros.md](../../macros-code-review/references/procedural-macros.md).

```rust
#[test]
fn ui() {
    let t = trybuild::TestCases::new();
    t.compile_fail("tests/ui/fail/*.rs");
    t.pass("tests/ui/pass/*.rs");
}
```

The pitfall is the `.stderr` reference output is **rustc-version-sensitive**. Span format, lint names, suggestion punctuation, and even ANSI escapes can change between stable releases. A green local run on `1.84` will fail in CI pinned to `1.82`. Mitigations:

- Pin a specific stable rustc for the trybuild CI job (`rust-toolchain.toml` with `channel = "1.84"`); other jobs can float.
- Regenerate intentionally on rustc upgrades: `TRYBUILD=overwrite cargo test --test ui`. Review the diff; commit the new `.stderr`.
- Skip trybuild on nightly: gate the test with `#[cfg(not(nightly))]` via a build-script-set cfg, or use `#[ignore]` and run separately.

Review checks:

- [FILE:LINE] TRYBUILD_NO_PINNED_TOOLCHAIN — `tests/ui/*.stderr` exists but `rust-toolchain.toml` is missing or floats. Stderr format drifts between stable releases; CI breaks for unrelated rustc updates.
- [FILE:LINE] TRYBUILD_ON_NIGHTLY — Trybuild job runs on `nightly`. Nightly stderr format changes weekly. Pin to stable or mark the job as allowed-to-fail.
- [FILE:LINE] TRYBUILD_OVERWRITE_COMMITTED — A `.stderr` file contains placeholders like `# overwrite` or was generated locally without review. Regenerate cleanly and inspect the diff.

## Clippy Lint Group Strategy

Jon's recommended grouping (Ch 6 "Linting"). Library and binary crates should differ: libraries surface lints downstream consumers cannot fix, so be conservative about which groups are denied.

- `clippy::correctness` — `deny` always. These are compiler-suggested fixes for near-certain bugs (broken swaps, `mem::forget` on references, iterating `Option::next`).
- `clippy::suspicious` — `warn` for libraries; consider `deny` if test coverage is thin. Catches code that looks like a typo.
- `clippy::style` — `warn`. Taste; most are obvious wins.
- `clippy::complexity` — `warn`. Real refactor signals (nested closures, redundant binding).
- `clippy::perf` — `warn`. Real wins on hot paths (`String::from` vs `.to_string()`, `clone()` in iterators).
- `clippy::pedantic` — `warn` for libraries; expect false positives. Suppress at the specific site with `#[expect(clippy::lint_name, reason = "...")]` (the `reason` field is required on Rust 2024 edition and surfaces in clippy output).
- `clippy::nursery` — **do not** enable in CI. Experimental lints whose behavior changes between rustc releases; you will get failures from rustc upgrades alone.
- `clippy::restriction` — never enable group-wide. Many lints would flag valid code (e.g., `clippy::shadow_unrelated` flags shadowing across unrelated bindings). Opt in to specific lints only.

Recommended rustc lints for library crates (workspace-wide via `[workspace.lints.rust]`):

```toml
[workspace.lints.rust]
rust_2018_idioms = { level = "warn", priority = -1 }
rust_2024_compatibility = { level = "warn", priority = -1 }
missing_docs = "warn"
missing_debug_implementations = "warn"
unsafe_op_in_unsafe_fn = "deny"

[workspace.lints.clippy]
correctness = { level = "deny", priority = -1 }
suspicious = { level = "warn", priority = -1 }
pedantic = { level = "warn", priority = -1 }
nursery = { level = "allow", priority = -1 }
```

The `priority = -1` lets specific item-level `#[expect]`/`#[allow]` attributes override the group setting.

Review checks:

- [FILE:LINE] CLIPPY_NURSERY_IN_CI — `[workspace.lints.clippy] nursery = "warn"` or `cargo clippy -- -W clippy::nursery` in CI. Nursery lints change between rustc releases; pin or remove.
- [FILE:LINE] CLIPPY_RESTRICTION_GROUP — Crate enables `clippy::restriction` group-wide. Many lints flag valid code. Opt in to specific lints individually.
- [FILE:LINE] PEDANTIC_BLANKET_ALLOWED — `#![allow(clippy::pedantic)]` at crate root masks all pedantic lints including useful ones. Allow specific lints with `#[expect(clippy::lint_name, reason = "...")]` at the offending site.
- [FILE:LINE] MISSING_REASON_ON_EXPECT — `#[expect(clippy::cast_possible_truncation)]` without a `reason = "..."` field. Future readers cannot tell whether the suppression is still justified. Add the reason.
- [FILE:LINE] LIB_MISSING_DOC_LINTS — Public library crate lacks `#![warn(missing_docs)]` and `#![warn(missing_debug_implementations)]`. Undocumented and non-Debug public items ship without signal.

Cross-references: concurrency-specific test gates live in [concurrency-testing.md](concurrency-testing.md); proc-macro test scaffolding details live in [../../macros-code-review/references/procedural-macros.md](../../macros-code-review/references/procedural-macros.md).
