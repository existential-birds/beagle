# Common Mistakes

## Unsafe Code

### Missing Safety Comments

Every `unsafe` block must explain why the invariants are upheld. This isn't a style preference — it's how future maintainers verify the code is correct.

```rust
// BAD - no justification
let value = unsafe { &*ptr };

// GOOD - documents the invariant
// SAFETY: `ptr` was allocated by `Box::into_raw` in `new()` and
// is guaranteed to be valid until `drop()` is called. We hold &self,
// which prevents concurrent mutation.
let value = unsafe { &*ptr };
```

### Overly Broad Unsafe Blocks

Only the minimum necessary code should be inside `unsafe`. Surrounding safe code makes it harder to audit.

```rust
// BAD - safe operations inside unsafe block
unsafe {
    let len = data.len();          // safe
    let ptr = data.as_ptr();       // safe
    std::slice::from_raw_parts(ptr, len)  // this is the only unsafe part
}

// GOOD - narrow unsafe boundary
let len = data.len();
let ptr = data.as_ptr();
// SAFETY: ptr and len come from the same slice, which is still alive
unsafe { std::slice::from_raw_parts(ptr, len) }
```

## API Design

### Non-Exhaustive Enums

Public enums should be `#[non_exhaustive]` if variants may be added in the future. Without it, adding a variant is a breaking change.

```rust
// GOOD - allows adding variants without breaking downstream
#[derive(Debug)]
#[non_exhaustive]
pub enum Status {
    Pending,
    Active,
    Complete,
}
```

### Builder Pattern

For types with many optional fields, builders prevent argument confusion and allow incremental construction.

```rust
// Builder takes ownership for chaining
pub struct ServerBuilder {
    port: u16,
    host: String,
    workers: Option<usize>,
}

impl ServerBuilder {
    pub fn new(port: u16) -> Self {
        Self { port, host: "0.0.0.0".into(), workers: None }
    }

    pub fn host(mut self, host: impl Into<String>) -> Self {
        self.host = host.into();
        self
    }

    pub fn workers(mut self, n: usize) -> Self {
        self.workers = Some(n);
        self
    }

    pub fn build(self) -> Result<Server, Error> { ... }
}
```

### Type State Pattern

Use zero-sized marker types to encode state transitions in the type system, making invalid states unrepresentable at compile time.

```rust
// States as zero-sized types
pub struct Draft;
pub struct Published;

pub struct Document<S> {
    content: String,
    _state: std::marker::PhantomData<S>,
}

impl Document<Draft> {
    pub fn publish(self) -> Document<Published> {
        Document {
            content: self.content,
            _state: PhantomData,
        }
    }
}

// Can't call publish() on an already-published document - won't compile
```

## Performance Pitfalls

### Unnecessary Allocations

```rust
// BAD - allocates a String just to compare
if input.to_string() == "hello" { ... }

// GOOD - compare directly
if input == "hello" { ... }

// BAD - collecting then iterating
let items: Vec<_> = source.iter().filter(|x| x.is_valid()).collect();
for item in &items { process(item); }

// GOOD - chain iterators
for item in source.iter().filter(|x| x.is_valid()) {
    process(item);
}
```

### String Formatting in Hot Paths

`format!` allocates a new `String` every call. In hot paths, prefer `write!` to a pre-allocated buffer.

```rust
// BAD in hot path - allocates per iteration
for item in items {
    let msg = format!("processing {}", item.id);
    log(&msg);
}

// GOOD - reuse buffer
let mut buf = String::with_capacity(64);
for item in items {
    buf.clear();
    write!(&mut buf, "processing {}", item.id).unwrap();
    log(&buf);
}
```

### Missing Capacity Hints

When the final size is known or estimable, pre-allocate to avoid repeated reallocations.

```rust
// BAD - grows the vec incrementally
let mut results = Vec::new();
for item in &items {
    results.push(transform(item));
}

// GOOD - allocate upfront
let mut results = Vec::with_capacity(items.len());
for item in &items {
    results.push(transform(item));
}

// BEST - use iterator
let results: Vec<_> = items.iter().map(transform).collect();
```

## Pointer Types Quick Reference

| Type | When to Use | Thread Safe | Notes |
|------|-------------|-------------|-------|
| `Box<T>` | Heap allocation, recursive types, trait objects | Yes (if T: Send) | Single owner |
| `Rc<T>` | Multiple owners, single thread | No | Use `Arc` for multi-thread |
| `Arc<T>` | Multiple owners, multi-thread | Yes | Atomic ref counting overhead |
| `Cell<T>` | Interior mutability for Copy types | Not Sync | No runtime borrow checking |
| `RefCell<T>` | Interior mutability, runtime borrow checking | Not Sync | Panics on double borrow |
| `Mutex<T>` | Shared mutation across threads | Yes | Exclusive access, can deadlock |
| `RwLock<T>` | Shared read OR exclusive write across threads | Yes | Better read throughput than Mutex |
| `OnceCell<T>` | One-time init, single thread | Not Sync | Use `OnceLock` for multi-thread |
| `OnceLock<T>` | One-time init, multi-thread (static values) | Yes | Replaces `lazy_static!` |
| `LazyCell<T>` | Deferred init with closure, single thread | Not Sync | Use `LazyLock` for multi-thread |
| `LazyLock<T>` | Deferred init with closure, multi-thread | Yes | Complex static initialization |
| `*const T` / `*mut T` | FFI, raw memory | No (manual) | Requires `unsafe` to dereference |

Decision guide:
- Need heap? `Box<T>`. Need shared ownership? `Rc`/`Arc`. Need interior mutability? `Cell`/`RefCell`/`Mutex`.
- Single thread? `Rc`, `Cell`, `RefCell`, `OnceCell`. Multi-thread? `Arc`, `Mutex`, `RwLock`, `OnceLock`.
- Common mistake: `Arc<Mutex<T>>` when data is single-threaded — use `Rc<RefCell<T>>` instead.

## Type State Pattern

Encode states as zero-sized types so invalid operations are compile errors, not runtime bugs.

```rust
struct Disconnected;
struct Connected;

struct Client<State> {
    addr: String,
    _state: std::marker::PhantomData<State>,
}

impl Client<Disconnected> {
    fn connect(self) -> Result<Client<Connected>, Error> {
        // ... connect logic ...
        Ok(Client { addr: self.addr, _state: PhantomData })
    }
}

impl Client<Connected> {
    fn send(&self, msg: &[u8]) -> Result<(), Error> { /* ... */ }
}

// client.send(b"hello"); // Won't compile — must connect first
```

### When to Use

- Builders with required fields (name and age must be set before `.build()`)
- Connection/session state machines (connect before send)
- Workflow pipelines (validate before process)
- Replacing runtime booleans/enums with compile-time guarantees

### When to Avoid

- Trivial state (simple enums are clearer)
- Runtime flexibility needed (state determined at runtime)
- Complex generics make the API harder to understand than the safety it provides

## Clippy Configuration

### Workspace-Level Lint Config

Configure in `Cargo.toml` for consistent enforcement across all crates:

```toml
[workspace.lints.clippy]
all = { level = "deny", priority = 10 }
redundant_clone = { level = "deny", priority = 9 }
pedantic = { level = "warn", priority = 3 }

[workspace.lints.rust]
future-incompatible = "warn"
nonstandard_style = "deny"
```

Individual crates inherit with:

```toml
[lints]
workspace = true
```

### `#[expect]` Over `#[allow]`

`#[expect(clippy::lint)]` warns when the suppression is no longer needed. `#[allow]` stays forever unnoticed:

```rust
// BAD - stale suppression goes undetected
#[allow(clippy::large_enum_variant)]
enum Message { /* ... */ }

// GOOD - compiler warns when lint no longer triggers
// Justification: Content variant intentionally large for fast matching
#[expect(clippy::large_enum_variant)]
enum Message { /* ... */ }
```

## Clippy Patterns Worth Flagging

These are patterns that `clippy` warns about but are easy to miss:

- `manual_map` — match arms that just wrap in `Some`/`Ok`; use `.map()` instead
- `needless_borrow` — `&` on values that already implement the trait for references
- `redundant_closure` — closures that just call a function: `|x| foo(x)` → `foo`
- `single_match` — `match` with one arm + wildcard; use `if let` instead
- `or_fun_call` — `.unwrap_or(Vec::new())` allocates even on the happy path; use `.unwrap_or_default()`

## Clippy Lints to Respect

| Lint | Why | Category |
|------|-----|----------|
| `redundant_clone` | Detects unnecessary clones with performance impact | perf |
| `needless_borrow` | Removes redundant `&` borrowing | style |
| `large_enum_variant` | Warns about oversized variants — consider Boxing | perf |
| `unnecessary_wraps` | Function always returns Some/Ok — drop the wrapper | pedantic |
| `clone_on_copy` | Catches `.clone()` on Copy types like `u32` | complexity |
| `needless_collect` | Prevents unnecessary intermediate collection allocation | nursery |
| `manual_ok_or` | Suggests `.ok_or_else()` over match | style |

### `#[expect]` Over `#[allow]`

Prefer `#[expect(clippy::lint)]` over `#[allow(clippy::lint)]`. The `expect` attribute warns when the lint no longer triggers, preventing stale suppressions:

```rust
// BAD - stale allow stays forever unnoticed
#[allow(clippy::large_enum_variant)]
enum Message { ... }

// GOOD - warns when the lint is no longer needed
#[expect(clippy::large_enum_variant)]
enum Message { ... }
```

Always add a justification comment when suppressing lints.

### Workspace Lint Configuration

Configure lints in `Cargo.toml` for consistent enforcement:

```toml
[lints.clippy]
all = { level = "deny", priority = 10 }
redundant_clone = { level = "deny", priority = 9 }
pedantic = { level = "warn", priority = 3 }

[lints.rust]
future-incompatible = "warn"
nonstandard_style = "deny"
```

## Stack vs Heap Size Awareness

- Keep small types (Copy types, usize, bool) on the stack
- Avoid passing types >512 bytes by value — use references
- Heap-allocate recursive data structures with `Box`
- Use `#[inline]` only when benchmarks prove benefit — Rust is already good at inlining
- For large const arrays, consider `smallvec` which auto-promotes to heap

```rust
// BAD - allocates 64KB on stack then boxes
let buffer: Box<[u8; 65536]> = Box::new([0u8; 65536]);

// GOOD - allocates directly on heap
let buffer: Box<[u8]> = vec![0u8; 65536].into_boxed_slice();
```

## Profiling Before Optimizing

> Don't guess, measure.

- Always benchmark with `--release` (debug builds lack optimizations)
- Run `cargo clippy -- -D clippy::perf` for performance hints
- Use `cargo bench` for micro-benchmarks (>5% improvement = worthwhile)
- Use `cargo flamegraph` or `samply` (macOS) for CPU profiling

## Iterator Best Practices

### When to Prefer Iterators

- Transforming collections (`.filter().map().collect()`)
- Composing multiple steps elegantly
- Using `.enumerate()`, `.windows()`, `.chunks()`
- Combining data from multiple sources

### When to Prefer `for` Loops

- Early exits (`break`, `continue`, `return`)
- Simple iteration with side effects (logging, I/O)
- When readability matters more than chaining

### Iterator Anti-Patterns

- Collecting just to iterate again — pass the iterator directly
- Using `.into_iter()` on Copy types — prefer `.iter()`
- Using `.fold()` for summing — prefer `.sum()` (compiler optimizes better)
- Chaining without line breaks — each chained call on its own line

```rust
// BAD - unnecessary intermediate collection
let doubled: Vec<_> = items.iter().map(|x| x * 2).collect();
process(doubled.into_iter());

// GOOD - pass the iterator (fn process(arg: impl Iterator<Item = T>))
let doubled_iter = items.iter().map(|x| x * 2);
process(doubled_iter);
```

## Import Ordering

Follow the standard Rust import convention:

```rust
// 1. std / core / alloc
use std::sync::Arc;

// 2. External crates (from Cargo.toml [dependencies])
use chrono::Utc;
use serde::{Deserialize, Serialize};

// 3. Workspace crates
use shared_types::Config;

// 4. super:: / crate::
use super::schema::Context;
use crate::models::Event;
```

Configure `rustfmt.toml` for automatic enforcement:

```toml
reorder_imports = true
imports_granularity = "Crate"
group_imports = "StdExternalCrate"
```

## Generics and Dispatch

### Static Dispatch (`impl Trait` / `<T: Trait>`)

Prefer for performance-critical code. Zero runtime cost, inlined at compile time.

### Dynamic Dispatch (`dyn Trait`)

Use when you need heterogeneous collections or runtime polymorphism.

| Aspect | Static (`impl Trait`) | Dynamic (`dyn Trait`) |
|--------|----------------------|----------------------|
| Performance | Faster, inlined | Slower, vtable indirection |
| Binary size | Larger (monomorphized) | Smaller (shared code) |
| Flexibility | One type at a time | Mix types in collections |

Rules of thumb:
- Start with generics, switch to `dyn Trait` when flexibility outweighs speed
- Prefer `&dyn Trait` over `Box<dyn Trait>` when you don't need ownership
- Don't box inside structs unless required (recursive types) or at API boundaries
- Trait objects require object safety: no generic methods, no `Self: Sized`

## Documentation Lints

Enable these lints for library crates:

| Lint | Purpose |
|------|---------|
| `missing_docs` | Warn on undocumented public items |
| `broken_intra_doc_links` | Detect broken `[links]` in doc comments |
| `missing_panics_doc` | Require `# Panics` section when function can panic |
| `missing_errors_doc` | Require `# Errors` section for Result-returning functions |
| `missing_safety_doc` | Require `# Safety` section for unsafe public functions |

```rust
// In lib.rs
#![deny(missing_docs)]
```

## Derive Macro Guidelines

| Trait | Derive When |
|-------|-------------|
| `Debug` | Almost always — essential for logging and debugging |
| `Clone` | Type is used in contexts requiring copies (collections, Arc patterns) |
| `PartialEq, Eq` | Type is compared or used as HashMap/HashSet key |
| `Hash` | Type is used as HashMap/HashSet key (requires `Eq`) |
| `Default` | Type has a meaningful default state |
| `Serialize, Deserialize` | Type crosses serialization boundaries (API, DB, config) |
| `Send, Sync` | Auto-derived; manually implement ONLY with unsafe justification |

## Review Questions

1. Does every `unsafe` block have a safety comment?
2. Are `unsafe` blocks as narrow as possible?
3. Are public enums `#[non_exhaustive]` if they may grow?
4. Are there unnecessary allocations in hot paths?
5. Are appropriate derive macros present for each type's usage?
6. Would clippy flag any of these patterns?
7. Is `#[expect]` used instead of `#[allow]` for lint suppression?
8. Are imports ordered (std → external → workspace → crate)?
9. Are iterators preferred over manual loops for collection transforms?
10. Is static dispatch used where performance matters?
11. Are doc lints enabled for library crates?
12. Are pointer types appropriate for the threading model (Rc vs Arc, RefCell vs Mutex)?
13. Could type state pattern replace runtime state checks for compile-time safety?
14. Are workspace-level clippy lints configured in Cargo.toml?
