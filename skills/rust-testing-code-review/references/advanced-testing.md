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

## Test Harness Customization

Set `harness = false` in `Cargo.toml` for custom test runners (fuzzers, model checkers, criterion benchmarks, WebAssembly targets). Without the harness, `#[test]` attributes are silently ignored -- you write your own `main`.

**Flag when:**
- `harness = false` set but test file still uses `#[test]` attributes
- Custom harness does not handle `--test-threads` or `--nocapture` when needed

## Test Doubles & Mocking Strategies (Stub / Fake / Mock / Spy)

Pick the lightest test double that proves what you need (*Rust for Rustaceans*, Ch 6):

- **Stub** — returns canned values for a fixed input shape. No state, no recording, no expectations. A function `fn now() -> Instant { fixed }` is a stub. Use when the test only needs a deterministic input to a downstream computation.
- **Fake** — a working alternative implementation of the same trait/contract, with simplified internals (in-memory `HashMap` backing a `Repository`, in-memory `VecDeque` backing a `Queue`, a deterministic monotonic clock). Has state and correct end-to-end behavior; just smaller, faster, and process-local. Use when production code is generic over the trait.
- **Mock** — pre-programmed with expectations (`mockall::automock`). The test declares call count (`times()`) and argument expectations up front and asserts them on teardown. Use when the *interaction pattern* itself is the property under test.
- **Spy** — records calls in a `Vec<(method, args)>` field without expectations for after-the-fact inspection when call order is branch-dependent.

**Trait-as-seam pattern.** Make production code generic over traits and substitute fakes/mocks in tests (see [integration-tests.md](integration-tests.md) for async trait mock examples):

```rust
pub trait Repository {
    fn get(&self, id: u64) -> Option<Row>;
    fn put(&self, row: Row);
}

pub struct Service<R: Repository> { repo: R }
// production: Service<PgRepository>
// tests:      Service<InMemoryRepository>  // a fake
```

When using `mockall::#[automock]`, set explicit `times()` constraints on expectations and wrap external dependencies behind your own trait rather than mocking foreign types directly:

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

Review checks:

- `[FILE:LINE] MOCKALL_WHERE_FAKE_FITS` — Test uses `#[automock]` to script many expectations when an in-memory fake implementing the same trait would be smaller and exercise the production path identically.
- `[FILE:LINE] FAKE_DIVERGES_FROM_PROD` — In-memory fake diverges in ordering/semantics from production (e.g., insertion order vs primary-key order).
- `[FILE:LINE] NO_TRAIT_SEAM` — `Service` owns a concrete `PgPool` with no trait boundary to substitute in tests.
- `[FILE:LINE] SPY_PRESENTED_AS_MOCK` — Struct records calls into a `Vec` without expectations but is named `MockFoo`.
- `[FILE:LINE] STUB_LEAKS_TEST_API` — `pub fn for_tests()` reachable from production builds instead of `#[cfg(test)]` or `tests/common/`.

## Test Generation Strategies

Beyond hand-written `#[test] fn` and the `rstest` examples in [integration-tests.md](integration-tests.md), four generation strategies cover most data shapes.

- **`rstest` with `#[case(...)]`** — table-driven tests with descriptive case names. Each `#[case]` becomes a separately-named test in cargo output.
- **`rstest` matrix** — Cartesian product across parameters via `#[values(a, b, c)]` on each argument:

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

- **`paste!` macro** — generates uniquely-named `#[test] fn` for a list of inputs by concatenating identifiers.
- **`build.rs`-generated tests** — for large input corpora (parser fixtures, golden files). The build script writes one `#[test] fn case_<name>` per file in `tests/fixtures/`, included via `include!(concat!(env!("OUT_DIR"), "/generated_tests.rs"))`.

Review checks:

- `[FILE:LINE] HANDROLLED_PARAMETERIZED_TESTS` — 12+ copy-pasted `#[test]` functions varying only in literals; use `#[rstest] #[case(...)]`.
- `[FILE:LINE] MATRIX_EXPANSION_TOO_LARGE` — `#[values]` over 4+ axes generates 10,000+ tests; reduce axes or use `proptest`.
- `[FILE:LINE] PASTE_INSTEAD_OF_RSTEST` — `paste!` used where `rstest` `#[case]` works, losing per-case IDE/CI reporting.
- `[FILE:LINE] BUILD_RS_TESTS_NOT_DETERMINISTIC` — `build.rs` walks `tests/fixtures/` with `read_dir` without sorting.
- `[FILE:LINE] GENERATED_TESTS_NO_RERUN_IF_CHANGED` — `build.rs` reads fixtures without emitting `cargo:rerun-if-changed=tests/fixtures`.

## Benchmarking Rigor (Criterion)

`criterion` (with `harness = false` in `Cargo.toml`) is the de facto Rust benchmark harness, replacing unstable `#[bench]`:

- **Statistical confidence.** Criterion runs many iterations, computes mean and variance, and bootstraps a confidence interval. Reject benchmarks reported as one-shot `Instant::now()` / `start.elapsed()` timings.
- **Baselines.** `cargo bench -- --save-baseline main` saves a named baseline; PR branches compare with `cargo bench -- --baseline main`.
- **`black_box` discipline.** Use `std::hint::black_box` (stable since Rust 1.66; `criterion::black_box` is deprecated in Criterion 0.5+) to prevent constant-folding. For pointer-backed inputs use `black_box(input.as_ptr())` rather than `black_box(&input)` because the compiler can assume `&T` is not mutated.
- **`iter_batched` & I/O isolation.** For mutating benchmarks or per-iteration setup (allocations, file opens), use `bencher.iter_batched(setup, routine, BatchSize::SmallInput)` so `setup` is uncounted and every iteration sees fresh state.
- **`--profile bench`.** Release optimizations with debug symbols (`[profile.bench] debug = true`) for `cargo flamegraph --bench foo`.

```rust
use std::hint::black_box;
use criterion::{criterion_group, criterion_main, BatchSize, Criterion};

fn bench_drain(c: &mut Criterion) {
    c.bench_function("drain_vec", |b| {
        b.iter_batched(
            || (0..1024).collect::<Vec<u32>>(),
            |mut v| {
                for x in v.drain(..) {
                    black_box(x);
                }
            },
            BatchSize::SmallInput,
        );
    });
}
criterion_group!(benches, bench_drain);
criterion_main!(benches);
```

Review checks:

- `[FILE:LINE] BENCH_NO_BLACK_BOX_ON_RESULT` — Benchmark closure drops return value without `std::hint::black_box`.
- `[FILE:LINE] BENCH_IO_IN_MEASURED_CLOSURE` — `File::open`, `println!`, RNG, or network calls inside `b.iter`; move to `iter_batched` setup.
- `[FILE:LINE] BENCH_NO_BASELINE_IN_CI` — `criterion_group!` exists with no CI `--save-baseline` / `--baseline` regression check.
- `[FILE:LINE] BENCH_NO_REGRESSION_THRESHOLD` — CI runs criterion comparison without failing on `Regressed`.
- `[FILE:LINE] ITER_BATCHED_NOT_USED_FOR_MUTATION` — Benchmark mutates captured state across `b.iter` calls instead of using `iter_batched`.

## trybuild & `compile_fail` UI Tests

`compile_fail` doctests verify code rejects invalid usage, though they pass on *any* compile error (always add a comment naming the expected error). For fine-grained diagnostics, `trybuild::TestCases` compiles `.rs` files in `tests/ui/` and diffs stderr against sibling `.stderr` files. See [procedural-macros.md](../../macros-code-review/references/procedural-macros.md) in the `macros-code-review` skill for proc-macro UI test details.

```rust
#[test]
fn ui() {
    let t = trybuild::TestCases::new();
    t.compile_fail("tests/ui/fail/*.rs");
    t.pass("tests/ui/pass/*.rs");
}
```

Because `.stderr` output is **rustc-version-sensitive**, pin a stable rustc for the trybuild CI job, regenerate deliberately with `TRYBUILD=overwrite cargo test --test ui` on toolchain upgrades, and skip trybuild on nightly.

Review checks:

- `[FILE:LINE] TRYBUILD_NO_PINNED_TOOLCHAIN` — `tests/ui/*.stderr` exists without a pinned toolchain; stderr format drifts across rustc releases.
- `[FILE:LINE] TRYBUILD_ON_NIGHTLY` — Trybuild runs on `nightly` where diagnostic wording changes weekly.
- `[FILE:LINE] TRYBUILD_OVERWRITE_COMMITTED` — `.stderr` updated via `TRYBUILD=overwrite` without verifying the diagnostic matches intent.

## Clippy Lint Group Strategy

Recommended grouping (*Rust for Rustaceans*, Ch 6). Libraries should avoid overly noisy groups that break downstream consumers:

- `clippy::correctness` — `deny` always (near-certain bugs).
- `clippy::suspicious` — `warn` for libraries; consider `deny` if test coverage is thin.
- `clippy::style` / `clippy::complexity` / `clippy::perf` — `warn`.
- `clippy::pedantic` — `warn` for libraries; suppress locally with `#[expect(clippy::lint_name, reason = "...")]` (`reason` is optional in Rust 1.81+ and Edition 2024, though strongly recommended so reviewers understand why the suppression is justified).
- `clippy::nursery` — **do not** enable in CI (experimental; changes between rustc releases).
- `clippy::restriction` — never enable group-wide; opt in to specific lints individually.

Recommended workspace lints:

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

The `priority = -1` lets individual lints and `#[expect]`/`#[allow]` attributes override the group setting.

Review checks:

- `[FILE:LINE] CLIPPY_NURSERY_IN_CI` — `nursery = "warn"` or `-W clippy::nursery` in CI.
- `[FILE:LINE] CLIPPY_RESTRICTION_GROUP` — `clippy::restriction` enabled group-wide.
- `[FILE:LINE] PEDANTIC_BLANKET_ALLOWED` — `#![allow(clippy::pedantic)]` at crate root; use site-local `#[expect(...)]` instead.
- `[FILE:LINE] MISSING_REASON_ON_EXPECT` — `#[expect(clippy::...)]` without a `reason = "..."` or comment explaining why the suppression is justified.
- `[FILE:LINE] LIB_MISSING_DOC_LINTS` — Public library crate lacks `missing_docs` / `missing_debug_implementations` lints.

Cross-references: concurrency-specific test gates live in [concurrency-testing.md](concurrency-testing.md); proc-macro test scaffolding details live in [procedural-macros.md](../../macros-code-review/references/procedural-macros.md) in the `macros-code-review` skill.
