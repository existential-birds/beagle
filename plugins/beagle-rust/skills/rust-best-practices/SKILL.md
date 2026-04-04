---
name: rust-best-practices
description: >
  Development guidance for writing idiomatic Rust. Use when:
  (1) writing new Rust functions or modules,
  (2) choosing between borrowing, cloning, or ownership patterns,
  (3) implementing error handling with Result types,
  (4) optimizing Rust code for performance,
  (5) configuring clippy and linting for a project,
  (6) deciding between static and dynamic dispatch,
  (7) writing documentation or doc tests.
---

# Rust Best Practices

Guidance for writing idiomatic, performant, and safe Rust code. This is a development skill, not a review skill -- use it when building, not reviewing.

## Quick Reference

| Topic | Key Rule | Reference |
|-------|----------|-----------|
| Ownership | Borrow by default, clone only when you need a separate owned copy | [references/coding-idioms.md](references/coding-idioms.md) |
| Clippy | Run `cargo clippy -- -D warnings` on every commit; configure workspace lints | [references/clippy-config.md](references/clippy-config.md) |
| Performance | Don't guess, measure. Profile with `--release` first | [references/performance.md](references/performance.md) |
| Generics | Static dispatch by default, dynamic dispatch when you need mixed types | [references/generics-dispatch.md](references/generics-dispatch.md) |
| Type State | Encode state in the type system when invalid operations should be compile errors | [references/type-state-pattern.md](references/type-state-pattern.md) |
| Documentation | `//` for why, `///` for what and how, `//!` for module/crate purpose | [references/documentation.md](references/documentation.md) |
| Pointers | Choose pointer types based on ownership needs and threading model | [references/pointer-types.md](references/pointer-types.md) |

## Coding Idioms

### Borrowing and Ownership

- Prefer `&T` over `.clone()` unless you need a separate owned copy
- Use `&str` over `String`, `&[T]` over `Vec<T>` in function parameters
- Small `Copy` types (<=24 bytes, all-Copy fields) should be passed by value
- Use `Cow<'_, T>` when ownership is ambiguous at the call site
- Take ownership only when the function needs to store or move the data

### Option and Result

- Use `let Ok(x) = expr else { return ... }` for early returns on failure
- Use `match` when pattern matching inner variants (`Ok(Direction::North)`)
- Use `if let` when the else branch needs computation
- Prefer `?` to propagate errors the caller should handle
- Use `_or_else` variants when fallbacks involve allocation

### Iterators

- Prefer iterator chains (`.filter().map().collect()`) over index-based loops
- Use `for` loops when you need `break`/`continue`/`return` or side effects
- Avoid premature `.collect()` -- pass iterators directly when possible
- Use `.sum()` over `.fold()` for summation
- Iterators are lazy: nothing happens until consumed

### Imports

Order: `std` -> external crates -> workspace crates -> `super::`/`crate::`. Configure in `rustfmt.toml`:

```toml
reorder_imports = true
imports_granularity = "Crate"
group_imports = "StdExternalCrate"
```

## Error Handling

- Return `Result<T, E>` for fallible operations; reserve `panic!` for unrecoverable bugs
- Never use `unwrap()`/`expect()` outside tests and provably-safe contexts
- Use `thiserror` for library error types, `anyhow` for binaries only
- Use `?` for error propagation; `inspect_err` for logging, `map_err` for transformation
- Test error paths: check specific variants, not just `.is_err()`

```rust
#[derive(Debug, thiserror::Error)]
pub enum AppError {
    #[error("Network timeout")]
    Timeout,
    #[error("Invalid data: {0}")]
    InvalidData(String),
    #[error(transparent)]
    Serialization(#[from] serde_json::Error),
}
```

## Clippy Discipline

- Run: `cargo clippy --all-targets --all-features -- -D warnings`
- Configure workspace lints in `Cargo.toml` (`[workspace.lints.clippy]`)
- Use `#[expect(clippy::lint)]` over `#[allow]` -- self-cleaning suppression
- Key lints: `redundant_clone`, `large_enum_variant`, `needless_collect`, `perf` group

## Performance Mindset

- Always benchmark with `--release` (debug builds lack optimizations)
- Use `cargo bench` for micro-benchmarks, `cargo flamegraph` or `samply` for profiling
- Avoid cloning in loops; use `.iter()` for Copy types, `.cloned()` for non-Copy
- Avoid intermediate `.collect()` calls; pass iterators directly
- Keep small types on the stack; heap-allocate recursive structures and large buffers

## Generics and Dispatch

- **Static dispatch** (`impl Trait` / `<T: Trait>`): zero-cost, monomorphized at compile time. Use by default.
- **Dynamic dispatch** (`dyn Trait`): vtable indirection at runtime. Use for heterogeneous collections and plugin architectures.
- Start with generics. Switch to `dyn Trait` when flexibility outweighs the performance cost.
- Prefer `&dyn Trait` over `Box<dyn Trait>` when you don't need ownership.
- Don't box inside structs unless required (recursive types, API boundaries).

## Type State Pattern

Encode valid states in the type system so invalid operations are compile errors:

```rust
struct Disconnected;
struct Connected;

struct Client<State> {
    addr: String,
    _state: PhantomData<State>,
}

impl Client<Connected> {
    fn send(&self, data: &[u8]) -> Result<(), Error> { /* ... */ }
}
```

Use when: builders with required fields, protocol state machines, workflow pipelines.
Avoid when: trivial states, runtime flexibility needed, generics complexity outweighs benefit.

## Documentation

- `//` comments explain *why* (safety, workarounds, design rationale)
- `///` doc comments explain *what* and *how* for public APIs
- `//!` doc comments describe module/crate purpose
- Every `TODO` needs a linked issue: `// TODO(#42): ...`
- Enable `#![deny(missing_docs)]` for library crates
- Use `# Examples` sections with runnable doc tests

## Pointer Types

Choose based on ownership and threading needs:

| Need | Single Thread | Multi-Thread |
|------|--------------|--------------|
| Single owner, heap | `Box<T>` | `Box<T>` |
| Shared ownership | `Rc<T>` | `Arc<T>` |
| Interior mutability | `Cell<T>` / `RefCell<T>` | `Mutex<T>` / `RwLock<T>` |
| One-time init | `OnceCell<T>` | `OnceLock<T>` |
| Lazy init with closure | `LazyCell<T>` | `LazyLock<T>` |
