# Unsafe Code, API Design, and Derive Patterns

> For performance, pointer types, clippy config, iterators, generics, and documentation guidance, see the `beagle-rust:rust-best-practices` skill.

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

### Unsafe Operations in `unsafe fn` (Edition 2024)

In edition 2024, `unsafe_op_in_unsafe_fn` is deny by default. Being inside an `unsafe fn` no longer implicitly permits unsafe operations — each one needs its own `unsafe {}` block with a safety comment.

```rust
// BAD in edition 2024 — unsafe ops without explicit blocks
unsafe fn process_raw(ptr: *const u8, len: usize) -> &[u8] {
    std::slice::from_raw_parts(ptr, len) // ERROR: requires unsafe block
}

// GOOD — explicit unsafe block inside unsafe fn
unsafe fn process_raw(ptr: *const u8, len: usize) -> &[u8] {
    // SAFETY: caller guarantees ptr is valid for len bytes and
    // the resulting slice does not outlive the allocation.
    unsafe { std::slice::from_raw_parts(ptr, len) }
}
```

This makes `unsafe fn` bodies auditable at the same granularity as regular functions. Every unsafe operation gets its own safety justification.

### `unsafe extern` Blocks (Edition 2024)

In edition 2024, `extern` blocks must be marked `unsafe` because declaring foreign functions is inherently unsafe (the compiler cannot verify the signatures are correct).

```rust
// BAD in edition 2024
extern "C" {
    fn strlen(s: *const c_char) -> usize;
}

// GOOD in edition 2024
unsafe extern "C" {
    fn strlen(s: *const c_char) -> usize;
}
```

### `unsafe` Attributes (Edition 2024)

Attributes that affect ABI or symbol names are now safety-sensitive and must be wrapped in `unsafe(...)`:

```rust
// BAD in edition 2024
#[no_mangle]
pub extern "C" fn my_func() {}

#[export_name = "custom_name"]
pub fn another_func() {}

// GOOD in edition 2024
#[unsafe(no_mangle)]
pub extern "C" fn my_func() {}

#[unsafe(export_name = "custom_name")]
pub fn another_func() {}
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

## Clippy Patterns Worth Flagging

These are patterns that `clippy` warns about but are easy to miss during review:

- `manual_map` — match arms that just wrap in `Some`/`Ok`; use `.map()` instead
- `needless_borrow` — `&` on values that already implement the trait for references
- `redundant_closure` — closures that just call a function: `|x| foo(x)` -> `foo`
- `single_match` — `match` with one arm + wildcard; use `if let` instead
- `or_fun_call` — `.unwrap_or(Vec::new())` allocates even on the happy path; use `.unwrap_or_default()`

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

Always add a justification comment when suppressing lints.

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

## `LazyCell` / `LazyLock` (Stable Since 1.80)

`std::cell::LazyCell` and `std::sync::LazyLock` replace the `once_cell` and `lazy_static` crates for lazy initialization. Prefer the std types in new code.

```rust
// BAD — external dependency for something std now provides
use once_cell::sync::Lazy;
static CONFIG: Lazy<Config> = Lazy::new(|| load_config());

// BAD — macro-based, no longer needed
lazy_static::lazy_static! {
    static ref CONFIG: Config = load_config();
}

// GOOD — std::sync::LazyLock for thread-safe global lazy init
use std::sync::LazyLock;
static CONFIG: LazyLock<Config> = LazyLock::new(|| load_config());

// GOOD — std::cell::LazyCell for single-threaded lazy init
use std::cell::LazyCell;
let value: LazyCell<String> = LazyCell::new(|| expensive_compute());
```

**When to flag**: New code (or code with MSRV >= 1.80) using `once_cell` or `lazy_static` when `LazyCell`/`LazyLock` would work. Existing code using these crates is fine if the MSRV prevents migration.

## Review Questions

1. Does every `unsafe` block have a safety comment?
2. Are `unsafe` blocks as narrow as possible?
3. Are public enums `#[non_exhaustive]` if they may grow?
4. Are appropriate derive macros present for each type's usage?
5. Is `#[expect]` used instead of `#[allow]` for lint suppression?
6. Would clippy flag any of these patterns?
7. Are builders used for types with many optional fields?
8. **Edition 2024**: Do `unsafe fn` bodies use explicit `unsafe {}` blocks?
9. **Edition 2024**: Are `extern` blocks marked `unsafe extern`?
10. **Edition 2024**: Are `#[no_mangle]` / `#[export_name]` wrapped in `#[unsafe(...)]`?
11. Is `LazyLock`/`LazyCell` used instead of `once_cell`/`lazy_static` when MSRV allows?
