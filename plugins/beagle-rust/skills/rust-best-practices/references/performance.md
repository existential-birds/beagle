# Performance

## Golden Rule

> Don't guess, measure.

Rust code is fast by default. Optimize only after finding bottlenecks with real profiling data.

## First Steps

1. **Build with `--release`** -- debug builds lack optimizations. Most "Rust is slow" complaints come from debug builds.
2. **Run `cargo clippy -- -D clippy::perf`** -- catches common performance anti-patterns.
3. **Benchmark before and after** -- use `cargo bench` to verify improvements (>5% = worthwhile).
4. **Profile with flamegraphs** -- `cargo flamegraph` or `samply` (macOS) to find real hotspots.

## Profiling Tools

### cargo bench

Built-in micro-benchmarking. Write scenarios and compare:

```shell
cargo bench
```

### cargo flamegraph

Visualize CPU time per function:

```shell
cargo install flamegraph
cargo flamegraph --release  # always profile with --release
```

Reading flamegraphs:
- **Width** = time spent (wider = more CPU time)
- **Y-axis** = stack depth (main at bottom, called functions stacked up)
- **Color** = random (not meaningful)
- **Thick stacks** = heavy CPU usage, investigate these

### samply (macOS alternative)

Better developer experience on macOS:

```shell
cargo install samply
samply record cargo run --release
```

## Avoid Redundant Cloning

Clone at the last possible moment, if at all:

```rust
// BAD - clone in loop
for item in &items {
    process(item.clone()); // clone per iteration
}

// GOOD - borrow
for item in &items {
    process(item); // just borrow
}
```

### When to Pass Ownership

- API requires owned data
- Sending data to another thread (`Arc::clone` is cheap)
- Operator overloads that consume `self`
- Modeling business logic transitions (`Validate::try_from(raw_input)`)

### When NOT to Pass Ownership

- Function only reads the data: use `&T` or `&[T]`
- Iteration: use `&some_vec` or `.iter()`
- Mutation: use `&mut T`

### Cow for Maybe-Owned Data

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

## Stack vs Heap

### Keep on the Stack

- Small types: primitives, `Copy` types, `usize`, `bool`
- Types returned by value that are cheap to copy

### Move to the Heap

- Recursive data structures: `Box<Node>`, `Box<[Node; 8]>`
- Large buffers (>512 bytes)
- Types behind trait objects: `Box<dyn Trait>`

```rust
// BAD - allocates 64KB on stack then moves to heap
let buffer: Box<[u8; 65536]> = Box::new([0u8; 65536]);

// GOOD - allocates directly on heap
let buffer: Box<[u8]> = vec![0u8; 65536].into_boxed_slice();
```

### Be Cautious With

- `#[inline]` -- only use when benchmarks prove benefit. Rust already inlines well.
- Large stack arrays -- consider `smallvec` for arrays that might grow.
- Large stack-allocated arrays (`let buf: [u8; 65536]`) -- they live on the stack and can overflow it. Use `Box<[T; N]>` or `Vec<T>` for large data.

## Iterator Optimization

Iterators compile to tight loops (zero-cost abstractions):

```rust
// GOOD - compiler optimizes this into a single loop
let total: i32 = items.iter()
    .filter(|x| x.is_valid())
    .map(|x| x.value())
    .sum();
```

### `IntoIterator` for `Box<[T]>` (Edition 2024)

Rust 2024 adds `IntoIterator` for `Box<[T]>`, so boxed slices can be iterated directly:

```rust
// Previously required converting to Vec first
let boxed: Box<[i32]> = vec![1, 2, 3].into_boxed_slice();

// BAD (pre-2024) -- convert to Vec to iterate by value
let items: Vec<i32> = boxed.into_vec();
for item in items { /* ... */ }

// GOOD (edition 2024) -- iterate directly
let boxed: Box<[i32]> = vec![1, 2, 3].into_boxed_slice();
for item in boxed { /* ... */ }
```

### Avoid Intermediate Collections

```rust
// BAD - allocates a Vec just to iterate again
let valid: Vec<_> = items.iter().filter(|x| x.is_valid()).collect();
process(valid.into_iter());

// GOOD - pass the iterator (fn process(iter: impl Iterator<Item = &T>))
process(items.iter().filter(|x| x.is_valid()));
```

### Prefer .sum() Over .fold()

`.sum()` is specialized and the compiler can optimize it better:

```rust
// DO
let total: i32 = values.iter().sum();

// DON'T (unless you need a different initial value or accumulator)
let total = values.iter().fold(0, |acc, x| acc + x);
```

### Use Capacity Hints

```rust
// DO - pre-allocate when size is known
let mut results = Vec::with_capacity(items.len());

// DON'T - grow incrementally
let mut results = Vec::new();
```

## String Performance

```rust
// BAD in hot path - format! allocates every call
for item in items {
    log(&format!("processing {}", item.id));
}

// GOOD - reuse buffer
let mut buf = String::with_capacity(64);
for item in items {
    buf.clear();
    use std::fmt::Write;
    write!(&mut buf, "processing {}", item.id).unwrap();
    log(&buf);
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

Cross-ref: see [../../rust-code-review/references/types-layout.md](../../rust-code-review/references/types-layout.md)
for wide-pointer and `repr(align)` review checks, and
[../../rust-code-review/references/concurrency-primitives.md](../../rust-code-review/references/concurrency-primitives.md)
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
- **`black_box` discipline.** `criterion::black_box` prevents the
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
use criterion::{black_box, criterion_group, BatchSize, Criterion};

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
  for crypto, regex, image-codec, and other CPU-bound dependencies that
  are otherwise painfully slow in debug.
- **`cargo-bloat`, `cargo-llvm-lines`, `cargo-show-asm`** for diagnosing
  generic-instantiation cost. `cargo llvm-lines` ranks functions by IR
  output volume -- the worst offenders are usually generics worth
  extracting into non-generic inner functions (see Monomorphization
  Budgets above).
- **`RUSTFLAGS="-Zthreads=8"`** on nightly enables the parallel rustc
  frontend, which can halve clean-build times on multi-core machines.
