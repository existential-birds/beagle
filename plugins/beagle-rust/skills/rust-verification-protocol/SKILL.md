---
name: rust-verification-protocol
description: Rust-specific verification delta that extends the shared core protocol in `beagle-core:review-verification-protocol`. Adds the edition gate, Rust verification steps by issue type (borrow/lifetime, RPIT capture, unsafe blocks, clones, races), macro/FFI/concurrency-specific checks, Rust severity notes, valid Rust patterns not to flag, and context-sensitive ownership, error-handling, and unsafe rules. Load the core protocol first, then this delta, before reporting any Rust code review findings.
user-invocable: false
---

# Review Verification Protocol — Rust delta

**Load `beagle-core:review-verification-protocol` first.** It carries the hard gates, the Pre-Report Verification Checklist, Severity Calibration, the imported `beagle-core:verification-budget` vocabulary (risk tiers, loop budgets, the one-echo rule, the prove-a-negative ban), and the language-neutral Verification by Issue Type sections.

This file adds **only** what is specific to Rust. Everything else is in the core; nothing here overrides it.

## Rust-specific gate: edition

Add one gate to the core's sequence, before any edition-sensitive finding:

**Edition gate** — **Pass:** you opened the `Cargo.toml` for the crate under review and either quote its `[package] edition = "..."` line or name the manifest path and state that the default edition applies. This gate runs once per crate, not once per finding.

If the edition is not specified, Rust defaults to edition 2015. Most modern projects use 2021 or later.

| Change | Edition 2021 | Edition 2024 |
|--------|--------------|--------------|
| `unsafe` inside `unsafe fn` | Optional style | Required (`unsafe_op_in_unsafe_fn` = deny) |
| `extern "C" {}` | Valid | Must be `unsafe extern "C" {}` |
| `#[no_mangle]` | Valid | Must be `#[unsafe(no_mangle)]` |
| `#[export_name]` | Valid | Must be `#[unsafe(export_name)]` |
| `-> impl Trait` lifetime capture | Explicit only | Captures all in-scope lifetimes |
| `gen` as identifier | Valid | Reserved keyword (use `r#gen`) |
| `!` type fallback | Falls back to `()` | Falls back to `!` |
| `if let` temporaries | Dropped at end of block | Dropped at end of the `if let` |
| Tail expression temporaries | Dropped after locals | Dropped before local variables |
| `Box<[T]>` iteration | Needs explicit `.iter()` | Has an `IntoIterator` impl |

**Cross-reference:** [rust-code-review](../rust-code-review/SKILL.md) and [rust-best-practices](../rust-best-practices/SKILL.md) carry the edition-specific review guidance and idiomatic patterns.

## Verification by Issue Type — Rust specifics

### "Unused Variable/Function"

Run the core's four-pattern reference search. Rust reference patterns that plain grep misses:

- `pub` items used by other crates in the workspace
- Derive macros and trait implementations that consume struct fields
- `#[cfg(...)]`-gated items compiled only in some configurations
- Trait methods required by the trait definition, and `From`/`Into` conversions used implicitly

### "Missing Error Handling"

Check whether the caller propagates with `?`, whether a crate-level error type wraps this error, and whether the `unwrap()` sits in test code or after a safety-establishing check.

**Common false positives:** `unwrap()` in tests and examples; `expect("reason")` after validation (e.g. `Regex::new` on a literal); propagation via `?`; `let _ = tx.send(...)` when the receiver may have dropped.

### "Unnecessary Lifetime" / RPIT capture (edition 2024)

1. Check the crate's edition first
2. In edition 2024, `-> impl Trait` captures ALL in-scope lifetimes by default
3. A lifetime that looks unnecessary may be implicitly captured — the code is correct
4. `+ use<'a, T>` is precise capture syntax, not a mistake

### "Missing Unsafe Block" (edition 2024)

`unsafe {}` inside an `unsafe fn`, `unsafe extern "C" {}`, and `#[unsafe(no_mangle)]` / `#[unsafe(export_name)]` are **required** in edition 2024 — not redundant verbosity. In edition 2021 they are optional style choices; do not require them.

### "Unnecessary Clone"

1. Confirm the clone is actually avoidable (the borrow checker may require it)
2. Check whether the value must move into a closure, thread, or task
3. Verify the type is not `Copy` (clone on `Copy` is a no-op)
4. Check whether it is in a hot path — clones in test/setup code are fine

**Common false positives:** `Arc::clone(&arc)` (the recommended explicit form); a clone before `tokio::spawn` (required for `'static`); clones in test setup.

### "Potential Race Condition"

1. Verify the data is actually shared across threads or tasks
2. Check whether `Mutex`, `RwLock`, or atomics protect the access
3. Confirm the type does not already guarantee thread safety (`Arc<Mutex<T>>`)
4. Check whether the race is benign (logging, metrics)

### "Performance Issue"

**Do NOT flag:** allocations in startup/init code, string formatting in error paths, clones in test code, `.collect()` on small iterators. The compiler already handles iterator fusion and inlining.

## Macro-specific verification

### "Macro Hygiene Issue"

1. Verify the identifier actually leaks — types, modules, and functions are NOT hygienic in `macro_rules!`
2. Check `$crate` is used correctly for exported macros (not `crate` or `self`)
3. Confirm `::core::` / `::alloc::` paths are needed (only for no_std contexts)
4. Check whether the macro is internal-only or `#[macro_export]`

**Common false positives:** non-hygienic type names in internal macros; `$crate` absent from `pub(crate)`-only macros; `::std::` in std-only crates.

### "Procedural Macro Performance"

1. Verify the crate really is a proc-macro crate (`proc-macro = true` in `Cargo.toml`)
2. Check whether `syn` features are minimized (full `"full"` feature vs selective)
3. Confirm the compile-time impact is meaningful (used across many files vs one-off)

### "Wrong Fragment Type"

1. Verify the suggested fragment type actually works in that position
2. Check whether `:tt` is intentional for flexibility (common in TT-munching)
3. Confirm `:expr` greediness issues actually manifest at the macro's real call sites

## FFI-specific verification

### "Missing repr(C)"

1. Confirm the type actually crosses the FFI boundary
2. Check whether it is only used on the Rust side of the wrapper
3. Verify there is no `#[repr(transparent)]` wrapper instead

**Common false positives:** internal types converted before the FFI call; `repr(transparent)` newtypes; opaque pointer types (`*mut c_void`).

### "FFI Safety"

1. Check whether the unsafe FFI call has a SAFETY comment documenting the invariants
2. Verify ownership transfer is genuinely ambiguous (look for `Box::into_raw`/`Box::from_raw` pairs)
3. Confirm CString lifetime issues are real — the `CString` must outlive the pointer passed to C
4. Check whether callback unwinding is actually possible

**Common false positives:** `extern "C" fn` callbacks that cannot panic (no `catch_unwind` needed); `*const c_char` from `CStr::as_ptr()` held in the same scope; bindgen output, which is unsafe-heavy by design.

## Concurrency-specific verification

### "Memory Ordering Too Weak"

1. Verify the atomic is actually shared between threads that need synchronization
2. Check whether `Relaxed` is sufficient (counters, flags with no dependent data)
3. Confirm the `Acquire`/`Release` vs `SeqCst` choice matters — most code does not need `SeqCst`

**Common false positives:** `Relaxed` on counters/metrics; `Relaxed` on boolean flags polled in a loop; `SeqCst` used "for safety" — over-synchronized, not wrong.

## Rust severity notes

The core's Severity Calibration applies. Rust-specific placements:

- **Critical:** `unsafe` with unsound invariants; SQL injection via string interpolation; use-after-free or other memory-safety violations; data races; panics on user input in production paths.
- **Major:** missing error context across module boundaries; blocking operations in an async runtime; mutex guards held across await points; missing transaction for multi-statement writes.
- **Minor:** missing doc comments on public items; `String` parameters where `&str` works; suboptimal iterator patterns; missing `#[must_use]`.
- **Informational:** newtype/builder/typestate suggestions; unmeasured performance ideas; `#[non_exhaustive]` suggestions; trait-design refactors.
- **Do NOT flag:** `if let` vs `match` for a single variant and similar style choices; generated code or macro output; clippy lints the project intentionally suppressed.

## Valid Patterns (Do NOT Flag)

### Rust

| Pattern | Why It's Valid |
|---------|----------------|
| `unwrap()` in tests | Standard test behavior — panics on unexpected errors |
| `.clone()` in test setup | Clarity over performance |
| `use super::*` in test modules | Standard pattern for accessing parent items |
| `Box<dyn Error>` in binaries | Not every app needs custom error types |
| `String` fields in structs | Owned data is correct for struct fields |
| `Arc::clone(&x)` | Explicit Arc cloning is idiomatic and recommended |
| `#[allow(clippy::...)]` with a reason | Intentional suppression is valid |
| `#[expect(lint)]` instead of `#[allow]` | Self-cleaning suppression — warns when the lint stops triggering |
| `unsafe {}` inside `unsafe fn` | Required in edition 2024 |
| `unsafe extern "C" {}` | Required in edition 2024 for extern blocks |
| `#[unsafe(no_mangle)]` / `#[unsafe(export_name = "...")]` | Required in edition 2024 for safety-relevant attributes |
| `+ use<'a, T>` on `impl Trait` returns | Precise capture syntax for edition 2024 RPIT |
| `r#gen` as an identifier | `gen` is reserved in edition 2024 |
| `LazyLock` / `LazyCell` | Standard library replacements for `once_cell`/`lazy_static` |
| `async fn` in trait definitions | No longer needs the `async-trait` crate |
| `#[diagnostic::on_unimplemented]` | Custom trait error messages |

### Async / Tokio

| Pattern | Why It's Valid |
|---------|----------------|
| `std::sync::Mutex` for short critical sections | Tokio docs recommend this for non-async locks |
| `tokio::spawn` without join | Valid for background tasks with shutdown signaling |
| `select!` with a `default` branch | Non-blocking check, intentional pattern |
| `#[tokio::test]` without `multi_thread` | Default single-thread is fine for most tests |

### Testing

| Pattern | Why It's Valid |
|---------|----------------|
| `expect()` in tests | Acceptable for test setup/assertions |
| `#[should_panic]` with `expected` | Valid for testing panic behavior |
| Large test functions | Integration tests can be long |
| `let _ = ...` in test cleanup | Cleanup errors are often unactionable |

### General Rust idioms

| Pattern | Why It's Valid |
|---------|----------------|
| `todo!()` in new code | Valid placeholder during development |
| `#[allow(dead_code)]` during development | Common during iteration |
| Multiple `impl` blocks for one type | Organized by trait or concern |
| Type aliases for complex types | Reduces boilerplate, improves readability |

## Context-Sensitive Rules

Each list below is an enumerated check, evaluated once. If an item is undecidable, drop the finding or ship it as a question — do not open another verification pass.

### Ownership

Flag an unnecessary `.clone()` **ONLY IF**:
- [ ] In a hot path (not test/setup code)
- [ ] A borrow or reference would work
- [ ] The clone is not required for `Send`/`'static` bounds
- [ ] The type is not `Copy`

### Error Handling

Flag missing error context **ONLY IF**:
- [ ] The error crosses a module boundary
- [ ] The error type does not already carry context (thiserror messages)
- [ ] Not in test code
- [ ] The bare `?` loses meaningful information about what operation failed

### Unsafe Code

Flag `unsafe` **ONLY IF**:
- [ ] The safety comment is missing or does not explain the invariant
- [ ] The unsafe block is broader than necessary
- [ ] The invariant is not actually upheld by the surrounding code
- [ ] A safe alternative exists with equivalent performance

Check the edition gate first: in edition 2024 several `unsafe` spellings are required, not stylistic.
