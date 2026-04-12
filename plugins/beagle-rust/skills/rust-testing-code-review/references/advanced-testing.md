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
