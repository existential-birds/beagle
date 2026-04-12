---
name: rust-code-review
description: Reviews Rust code for ownership, borrowing, lifetime, error handling, trait design, unsafe usage, and common mistakes. Use when reviewing .rs files, checking borrow checker issues, error handling patterns, or trait implementations. Covers Rust 2024 edition patterns and modern idioms.
---

# Rust Code Review

## Review Workflow

Follow this sequence to avoid false positives and catch edition-specific issues:

1. **Check `Cargo.toml`** — Note the Rust edition (2018, 2021, 2024) and MSRV if set. Edition 2024 introduces breaking changes to unsafe semantics, RPIT lifetime capture, temporary scoping, and `!` type fallback. This determines which patterns apply. Check workspace structure if present.
2. **Check dependencies** — Note key crates (thiserror vs anyhow, tokio features, serde features). These inform which patterns are expected.
3. **Scan changed files** — Read full functions, not just diffs. Many Rust bugs hide in ownership flow across a function.
4. **Check each category** — Work through the checklist below, loading references as needed.
5. **Verify before reporting** — Load beagle-rust:review-verification-protocol before submitting findings.

## Output Format

Report findings as:

```text
[FILE:LINE] ISSUE_TITLE
Severity: Critical | Major | Minor | Informational
Description of the issue and why it matters.
```

## Quick Reference

| Issue Type | Reference |
|------------|-----------|
| Ownership transfers, borrowing, lifetimes, clone traps, iterators | [references/ownership-borrowing.md](references/ownership-borrowing.md) |
| Lifetime variance, covariance/invariance, memory regions | [references/lifetime-variance.md](references/lifetime-variance.md) |
| Result/Option handling, thiserror, anyhow, error context, Error trait | [references/error-handling.md](references/error-handling.md) |
| Async pitfalls, Send/Sync bounds, runtime blocking | [references/async-concurrency.md](references/async-concurrency.md) |
| Send/Sync semantics, atomics, memory ordering, lock patterns | [references/concurrency-primitives.md](references/concurrency-primitives.md) |
| Type layout, alignment, repr, PhantomData, generics vs dyn Trait | [references/types-layout.md](references/types-layout.md) |
| Unsafe code, API design, derive patterns, clippy patterns | [references/common-mistakes.md](references/common-mistakes.md) |
| Safety contracts, raw pointers, MaybeUninit, soundness, Miri | [references/unsafe-deep.md](references/unsafe-deep.md) |

> For development guidance on performance, pointer types, type state, clippy config, iterators, generics, and documentation, use the `beagle-rust:rust-best-practices` skill.

## Review Checklist

### Ownership and Borrowing
- [ ] No unnecessary `.clone()` to silence the borrow checker (hiding design issues)
- [ ] No `.clone()` inside loops — prefer `.cloned()` or `.copied()` on iterators
- [ ] No cloning to avoid lifetime annotations (take ownership explicitly or restructure)
- [ ] References have appropriate lifetimes (not overly broad `'static` when shorter lifetime works)
- [ ] **Edition 2024**: RPIT (`-> impl Trait`) captures all in-scope lifetimes by default; use `+ use<'a>` for precise capture control
- [ ] `&str` preferred over `String`, `&[T]` over `Vec<T>` in function parameters
- [ ] `impl AsRef<T>` or `Into<T>` used for flexible API parameters
- [ ] No dangling references or use-after-move
- [ ] Interior mutability (`Cell`, `RefCell`, `Mutex`) used only when shared mutation is genuinely needed
- [ ] Small types (≤24 bytes) derive `Copy` and are passed by value
- [ ] `Cow<'_, T>` used when ownership is ambiguous
- [ ] Iterator chains preferred over index-based loops for collection transforms
- [ ] No premature `.collect()` — pass iterators directly when the consumer accepts them
- [ ] `.sum()` preferred over `.fold()` for summation (compiler optimizes better)
- [ ] `_or_else` variants used when fallbacks involve allocation
- [ ] **Edition 2024**: `if let` temporaries drop at end of the `if let` — code relying on temporaries living through the else branch needs restructuring
- [ ] **Edition 2024**: `Box<[T]>` implements `IntoIterator` — prefer direct iteration over `into_vec()` first

### Error Handling
- [ ] `Result<T, E>` used for recoverable errors, not `panic!`/`unwrap`/`expect`
- [ ] Error types provide context (thiserror with `#[error("...")]` or manual `Display`)
- [ ] `?` operator used with proper `From` implementations or `.map_err()`
- [ ] `unwrap()` / `expect()` only in tests, examples, or provably-safe contexts
- [ ] Error variants are specific enough to be actionable by callers
- [ ] `anyhow` used in applications, `thiserror` in libraries (or clear rationale for alternatives)
- [ ] `_or_else` variants used when fallbacks involve allocation (`ok_or_else`, `unwrap_or_else`)
- [ ] `let-else` used for early returns on failure (`let Ok(x) = expr else { return ... }`)
- [ ] `inspect_err` used for error logging, `map_err` for error transformation

### Traits and Types
- [ ] Traits are minimal and cohesive (single responsibility)
- [ ] `derive` macros appropriate for the type (`Clone`, `Debug`, `PartialEq` used correctly)
- [ ] Newtypes used to prevent primitive obsession (e.g., `struct UserId(Uuid)` not bare `Uuid`)
- [ ] `From`/`Into` implementations are lossless and infallible; `TryFrom` for fallible conversions
- [ ] Sealed traits used when external implementations shouldn't be allowed
- [ ] Default implementations provided where they make sense
- [ ] `Send + Sync` bounds verified for types shared across threads
- [ ] `#[diagnostic::on_unimplemented]` used on public traits to provide clear error messages when users forget to implement them

### Unsafe Code
- [ ] `unsafe` blocks have safety comments explaining invariants
- [ ] `unsafe` is minimal — only the truly unsafe operation is inside the block
- [ ] Safety invariants are documented and upheld by surrounding safe code
- [ ] No undefined behavior (null pointer deref, data races, invalid memory access)
- [ ] `unsafe` trait implementations justify why the contract is upheld
- [ ] **Edition 2024**: `unsafe fn` bodies use explicit `unsafe {}` blocks around unsafe ops (`unsafe_op_in_unsafe_fn` is deny)
- [ ] **Edition 2024**: `extern "C" {}` blocks written as `unsafe extern "C" {}`
- [ ] **Edition 2024**: `#[no_mangle]` and `#[export_name]` written as `#[unsafe(no_mangle)]` and `#[unsafe(export_name)]`

### Naming and Style
- [ ] Types are `PascalCase`, functions/methods `snake_case`, constants `SCREAMING_SNAKE_CASE`
- [ ] Modules use `snake_case`
- [ ] `is_`, `has_`, `can_` prefixes for boolean-returning methods
- [ ] Builder pattern methods take and return `self` (not `&mut self`) for chaining
- [ ] Public items have doc comments (`///`)
- [ ] `#[must_use]` on functions where ignoring the return value is likely a bug
- [ ] Imports ordered: std → external crates → workspace → crate/super
- [ ] `#[expect(clippy::...)]` preferred over `#[allow(...)]` for lint suppression

### Performance
> Detailed guidance: `beagle-rust:rust-best-practices` skill (references/performance.md)
- [ ] No unnecessary allocations in hot paths (prefer `&str` over `String`, `&[T]` over `Vec<T>`)
- [ ] `collect()` type is specified or inferable
- [ ] Iterators preferred over indexed loops for collection transforms
- [ ] `Vec::with_capacity()` used when size is known
- [ ] No redundant `.to_string()` / `.to_owned()` chains
- [ ] No intermediate `.collect()` when passing iterators directly works
- [ ] `.sum()` preferred over `.fold()` for summation
- [ ] Static dispatch (`impl Trait`) used over dynamic (`dyn Trait`) unless flexibility required

### Clippy Configuration
> Detailed guidance: `beagle-rust:rust-best-practices` skill (references/clippy-config.md)
- [ ] Workspace-level lints configured in `Cargo.toml` (`[workspace.lints.clippy]` or `[lints.clippy]`)
- [ ] `#[expect(clippy::lint)]` used over `#[allow(...)]` — warns when suppression becomes stale
- [ ] Justification comment present when suppressing any lint
- [ ] Key lints enforced: `redundant_clone`, `large_enum_variant`, `needless_collect`, `perf` group
- [ ] `cargo clippy --all-targets --all-features -- -D warnings` passes
- [ ] Doc lints enabled for library crates (`missing_docs`, `broken_intra_doc_links`)

### Type State Pattern
> Detailed guidance: `beagle-rust:rust-best-practices` skill (references/type-state-pattern.md)
- [ ] `PhantomData<State>` used for zero-cost compile-time state machines (not runtime enums/booleans)
- [ ] State transitions consume `self` and return new state type (prevents reuse of old state)
- [ ] Only applicable methods available per state (invalid operations are compile errors)
- [ ] Pattern used where it adds safety value (builders with required fields, connection states, workflows)
- [ ] Not overused for trivial state (simple enums are fine when runtime flexibility needed)

## Severity Calibration

### Critical (Block Merge)
- `unsafe` code with unsound invariants or undefined behavior
- Use-after-free or dangling reference patterns
- `unwrap()` on user input or external data in production code
- Data races (concurrent mutation without synchronization)
- Memory leaks via circular `Arc<Mutex<...>>` without weak references

### Major (Should Fix)
- Errors returned without context (bare `return err` equivalent)
- `.clone()` masking ownership design issues in hot paths
- Missing `Send`/`Sync` bounds on types used across threads
- `panic!` for recoverable errors in library code
- Overly broad `'static` lifetimes hiding API design issues

### Minor (Consider Fixing)
- Missing doc comments on public items
- `String` parameter where `&str` or `impl AsRef<str>` would work
- Derive macros missing for types that should have them
- Unused feature flags in `Cargo.toml`
- Suboptimal iterator chains (multiple allocations where one suffices)

### Informational (Note Only)
- Suggestions to introduce newtypes for domain modeling
- Refactoring ideas for trait design
- Performance optimizations without measured impact
- Suggestions to add `#[must_use]` or `#[non_exhaustive]`

## When to Load References

- Reviewing ownership, borrows, lifetimes, clone traps → ownership-borrowing.md
- Reviewing lifetime variance, covariance/invariance, multiple lifetime params → lifetime-variance.md
- Reviewing Result/Option handling, error types, Error trait impls → error-handling.md
- Reviewing async code, tokio usage, task management → async-concurrency.md
- Reviewing Send/Sync, atomics, memory ordering, mutexes, lock patterns → concurrency-primitives.md
- Reviewing type layout, alignment, repr, PhantomData, generics vs dyn → types-layout.md
- Reviewing unsafe code, API design, derive macros, clippy patterns → common-mistakes.md
- Reviewing safety contracts, raw pointers, MaybeUninit, soundness → unsafe-deep.md
- Reviewing performance, pointer types, type state, generics, iterators, documentation → `beagle-rust:rust-best-practices` skill

## Valid Patterns (Do NOT Flag)

These are acceptable Rust patterns — reporting them wastes developer time:

- **`.clone()` in tests** — Clarity over performance in test code
- **`unwrap()` in tests and examples** — Acceptable where panicking on failure is intentional
- **`Box<dyn Error>` in simple binaries** — Not every application needs custom error types
- **`String` fields in structs** — Owned data in structs is correct; `&str` fields require lifetime parameters
- **`#[allow(dead_code)]` during development** — Common during iteration
- **`todo!()` / `unimplemented!()` in new code** — Valid placeholder during active development
- **`.expect("reason")` with clear message** — Self-documenting and acceptable for invariants
- **`use super::*` in test modules** — Standard pattern for `#[cfg(test)]` modules
- **Type aliases for complex types** — `type Result<T> = std::result::Result<T, MyError>` is idiomatic
- **`impl Trait` in return position** — Zero-cost abstraction, standard pattern
- **Turbofish syntax** — `collect::<Vec<_>>()` is idiomatic when type inference needs help
- **`_` prefix for intentionally unused variables** — Compiler convention
- **`#[expect(clippy::...)]` with justification** — Self-cleaning lint suppression
- **`Arc::clone(&arc)`** — Explicit Arc cloning is idiomatic and recommended
- **`std::sync::Mutex` for short critical sections in async** — Tokio docs recommend this
- **`for` loops over iterators** — When early exit or side effects are needed
- **`async fn` in trait definitions** — Stable since 1.75; `async-trait` crate only needed for `dyn Trait` or pre-1.75 MSRV
- **`LazyCell` / `LazyLock` from std** — Stable since 1.80; replaces `once_cell` and `lazy_static` for new code
- **`+ use<'a, T>` precise capture syntax** — Edition 2024 syntax for controlling RPIT lifetime capture

## Context-Sensitive Rules

Only flag these issues when the specific conditions apply:

| Issue | Flag ONLY IF |
|-------|--------------|
| Missing error context | Error crosses module boundary without context |
| Unnecessary `.clone()` | In hot path or repeated call, not test/setup code |
| Missing doc comments | Item is `pub` and not in a `#[cfg(test)]` module |
| `unwrap()` usage | In production code path, not test/example/provably-safe |
| Missing `Send + Sync` | Type is actually shared across thread/task boundaries |
| Overly broad lifetime | A shorter lifetime would work AND the API is public |
| Missing `#[must_use]` | Function returns a value that callers commonly ignore |
| Stale `#[allow]` suppression | Should be `#[expect]` for self-cleaning lint management |
| Missing `Copy` derive | Type is ≤24 bytes with all-Copy fields and used frequently |
| **Edition 2024**: `!` type fallback | Match on `Result<T, !>` or diverging expressions where `()` fallback was assumed — `!` now falls back to `!` not `()` |
| **Edition 2024**: `r#gen` identifier | Code uses `gen` as an identifier — must be `r#gen` in edition 2024 (reserved keyword) |

## Before Submitting Findings

Load and follow `beagle-rust:review-verification-protocol` before reporting any issue.
