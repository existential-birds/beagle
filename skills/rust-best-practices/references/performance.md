# Performance

## Profiling Workflow

> Don't guess, measure. Always benchmark and profile with `--release`.

1. **Run `cargo clippy -- -D clippy::perf`** — catches common performance anti-patterns.
2. **Benchmark with Criterion (`cargo bench`)** — verify improvements (>5% = worthwhile).
3. **Profile with flamegraphs** — `samply record cargo run --release` (macOS/Linux) or `cargo flamegraph --release`.

## Stack vs Heap & Boxed Slices

### Direct Heap Allocation for Large Buffers

```rust
// BAD - allocates 64KB on stack then copies to heap
let buffer: Box<[u8; 65536]> = Box::new([0u8; 65536]);

// GOOD - allocates directly on heap
let buffer: Box<[u8]> = vec![0u8; 65536].into_boxed_slice();
```

### `IntoIterator` for `Box<[T]>` (Edition 2024)

Rust 2024 adds `IntoIterator` for `Box<[T]>`, so boxed slices can be iterated directly without `.into_vec()`:

```rust
let boxed: Box<[i32]> = vec![1, 2, 3].into_boxed_slice();
for item in boxed { /* ... */ }
```

### `Cow` for Maybe-Owned Data

```rust
use std::borrow::Cow;

fn normalize(input: Cow<'_, str>) -> Cow<'_, str> {
    if input.contains('\t') {
        Cow::Owned(input.replace('\t', "    "))
    } else {
        input // no allocation needed
    }
}
```

## Monomorphization Budgets

Generic functions are compiled separately for each concrete instantiation.
A large generic body instantiated for 20 types becomes 20 copies in the
binary. Costs compound across three dimensions:

- **Compile time** -- significant in workspaces with many generic-heavy
  crates; each downstream user pays again for their own instantiations.
- **Binary size** -- megabytes of duplicated code from a single popular
  generic.
- **Instruction-cache pressure** -- the CPU's L1i is small (typically
  32KB). Bloated code paths evict hot inner loops.

Mitigations, in order of preference:

- **Extract type-independent inner functions.** Push the
  type-parameterized work to the boundary and dispatch into a non-generic
  body compiled once:

  ```rust
  pub fn process<T: Serialize>(items: &[T]) -> Vec<u8> {
      let bytes: Vec<Vec<u8>> = items.iter().map(serialize_one).collect();
      process_bytes(bytes)  // non-generic, compiled once
  }
  fn process_bytes(bytes: Vec<Vec<u8>>) -> Vec<u8> { /* ... */ }
  ```

- **Switch internal generics to `dyn Trait`** for binary internals where
  peak inlining is not required. The vtable indirection is cheap compared
  to icache misses from duplicated generic bodies.
- **Bound generics in libraries** with `impl Trait` in argument position
  to keep the generic surface small and let callers' compilers
  monomorphize only at the public boundary.

Diagnose with `cargo llvm-lines` to see which generic functions emit the
most LLVM IR lines per crate.

## Cache-Line Alignment and False Sharing

When two CPUs access different values that share a cache line, the cache
coherency protocol serializes the accesses. Two logically independent
atomic operations become a sequential pair as the line ping-pongs
between cores. The symptom is scaling tests that show worse-than-linear
speedup -- or even slowdown -- as you add cores.

Fixes:

- `#[repr(align(64))]` on per-thread counters or hot atomic structs.
- On Apple Silicon (M1+) and some server CPUs, cache lines are 128 bytes
  -- prefer `align(128)` if you target those platforms.
- `crossbeam::utils::CachePadded<T>` as a portable wrapper that picks a
  sensible alignment per target.

```rust
#[repr(align(64))]
struct PerThreadCounter(AtomicU64);

let counters: Vec<PerThreadCounter> = (0..num_cpus::get())
    .map(|_| PerThreadCounter(AtomicU64::new(0)))
    .collect();
```

Cross-ref in the `rust-code-review` skill: see [types-layout.md](../../rust-code-review/references/types-layout.md)
for wide-pointer and `repr(align)` review checks, and
[concurrency-primitives.md](../../rust-code-review/references/concurrency-primitives.md)
for atomic ordering and contention patterns.

## Criterion Benchmarking Discipline

`criterion` is the de facto Rust benchmark harness; it replaces the
unstable nightly `#[bench]` attribute.

- **Statistical confidence.** Criterion runs each benchmark many times,
  reports mean plus standard deviation, and compares against prior
  baselines with a confidence interval. Single-shot timings are noise --
  variance from CPU frequency scaling, ASLR, and kernel scheduling
  dwarfs sub-microsecond differences.
- **Baseline persistence.** `cargo bench -- --save-baseline main` stores
  a baseline named `main`. On a feature branch,
  `cargo bench -- --baseline main` compares against it. CI integrates
  this for regression detection.
- **Regression detection in CI.** Fail the build on greater-than-X%
  regression (typically 5-10%) on hot paths. Treat performance
  regressions as test failures, not warnings.
- **`black_box` discipline.** Use `std::hint::black_box` (stable since Rust 1.66; `criterion::black_box` is deprecated in Criterion 0.5+) to prevent the
  optimizer from constant-folding the benchmark away. Use
  `black_box(input.as_ptr())` for pointer-flavored inputs -- the
  optimizer cannot reason about pointer-derived state. `black_box(&input)`
  is sometimes insufficient because the optimizer can see through `&`
  and assume the value is not mutated.
- **`--profile bench`.** Builds benchmarks with release optimizations
  plus debug symbols so flamegraph correlation lines up with source.
- **Keep I/O outside the measurement loop.** File and network setup
  belongs in `bench_function`'s setup closure (or `iter_batched`'s
  routine closure), not the measurement closure. Otherwise you are
  benchmarking I/O.

```rust
use std::hint::black_box;
use criterion::{criterion_group, BatchSize, Criterion};

fn bench_parse(c: &mut Criterion) {
    c.bench_function("parse_url", |b| {
        b.iter_batched(
            || generate_input(),                    // setup, untimed
            |input| black_box(parse(input.as_ptr())), // measured
            BatchSize::SmallInput,
        );
    });
}
criterion_group!(benches, bench_parse);
```

## Compile-Time as a Performance Concern

At workspace scale (10+ crates, 100k+ LOC), compile time is a real
developer-productivity tax. Treat it as a perf budget:

- **Split feature flags** so dev iteration disables expensive deps.
  Procedural macros (`syn` with `features = ["full"]`, `serde_derive`,
  `tokio-macros`) are the biggest cost; gate non-essential ones behind
  `#[cfg(feature = "...")]`.
- **`[profile.dev.package.<slow-dep>]` with `opt-level = 3`** makes slow
  deps build once in release and stay cached across dev rebuilds. Useful
  for proc-macro deps (`serde_derive`, `tokio-macros`) and CPU-bound
  dependencies (crypto, regex, image codecs) that are slow in debug.
- **`cargo-bloat`, `cargo-llvm-lines`, `cargo-show-asm`** for diagnosing
  generic-instantiation cost. `cargo llvm-lines` ranks functions by IR
  output volume -- the worst offenders are usually generics worth
  extracting into non-generic inner functions (see Monomorphization
  Budgets above).
- **`RUSTFLAGS="-Zthreads=8"`** on nightly enables the parallel rustc
  frontend, which can halve clean-build times on multi-core machines.
