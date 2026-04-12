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
