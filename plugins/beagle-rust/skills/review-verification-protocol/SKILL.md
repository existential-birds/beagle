---
name: review-verification-protocol
description: Mandatory verification steps for all code reviews to reduce false positives. Load this skill before reporting ANY code review findings.
user-invocable: false
---

# Review Verification Protocol

This protocol MUST be followed before reporting any code review finding. Skipping these steps leads to false positives that waste developer time and erode trust in reviews.

## Pre-Report Verification Checklist

Before flagging ANY issue, verify:

- [ ] **I read the actual code** - Not just the diff context, but the full function/impl block
- [ ] **I searched for usages** - Before claiming "unused", searched all references
- [ ] **I checked surrounding code** - The issue may be handled elsewhere (trait impls, error propagation)
- [ ] **I verified syntax against current docs** - Rust edition, crate versions, and API changes
- [ ] **I checked the project's Rust edition** - Edition 2021 vs 2024 changes what is required vs optional (see [Edition-Aware Review](#edition-aware-review))
- [ ] **I distinguished "wrong" from "different style"** - Both approaches may be valid
- [ ] **I considered intentional design** - Checked comments, CLAUDE.md, architectural context

## Verification by Issue Type

### "Unused Variable/Function"

**Before flagging**, you MUST:
1. Search for ALL references in the codebase (grep/find)
2. Check if it's `pub` and used by other crates in the workspace
3. Check if it's used via derive macros, trait implementations, or conditional compilation (`#[cfg]`)
4. Verify it's not a trait method required by the trait definition

**Common false positives:**
- Trait implementations where the method is defined by the trait
- `#[cfg(test)]` items only used in test builds
- Derive-generated code that uses struct fields
- Types used via `From`/`Into` conversions

### "Missing Error Handling"

**Before flagging**, you MUST:
1. Check if the error is handled at a higher level (caller propagates with `?`)
2. Check if the crate has a top-level error type that wraps this error
3. Verify the `unwrap()` isn't in test code or after a safety-ensuring check

**Common false positives:**
- `unwrap()` in tests and examples (expected pattern)
- `expect("reason")` after validation (e.g., `regex::Regex::new` on a literal)
- Error propagation via `?` (the caller handles it)
- `let _ = tx.send(...)` — intentional when receiver may have dropped

### "Unnecessary Lifetime" / RPIT Capture (Edition 2024)

**Before flagging**, you MUST:
1. Check the project's Rust edition in `Cargo.toml`
2. In edition 2024, `-> impl Trait` captures ALL in-scope lifetimes by default
3. A lifetime that appears "unnecessary" may be implicitly captured — the code is correct
4. If the author uses `+ use<'a>` syntax, this is precise capture control, not a mistake

**Common false positives:**
- Lifetime parameters on functions returning `impl Trait` — edition 2024 captures them implicitly
- `+ use<'a, T>` syntax — this is the new precise capturing syntax, not an error
- Removing an explicit lifetime bound that edition 2024 now provides automatically

### "Missing Unsafe Block" (Edition 2024)

**Before flagging**, you MUST:
1. Check if the code is inside an `unsafe fn`
2. In edition 2024, `unsafe_op_in_unsafe_fn` is deny-by-default — unsafe operations inside `unsafe fn` REQUIRE explicit `unsafe {}` blocks
3. This is edition-required behavior, not unnecessary verbosity

**Common false positives:**
- `unsafe {}` blocks inside `unsafe fn` — REQUIRED in edition 2024, not redundant
- `unsafe extern "C" {}` — REQUIRED in edition 2024, not optional
- `#[unsafe(no_mangle)]` / `#[unsafe(export_name)]` — REQUIRED in edition 2024

### "Unnecessary Clone"

**Before flagging**, you MUST:
1. Confirm the clone is actually avoidable (borrow checker may require it)
2. Check if the value needs to be moved into a closure/thread/task
3. Verify the type isn't `Copy` (clone on Copy types is a no-op)
4. Check if the clone is in a hot path (test/setup code cloning is fine)

**Common false positives:**
- `Arc::clone(&arc)` — this is the recommended explicit clone for Arc
- Clone before `tokio::spawn` — required for `'static` bound
- Clone in test setup — clarity over performance

### "Potential Race Condition"

**Before flagging**, you MUST:
1. Verify the data is actually shared across threads/tasks
2. Check if `Mutex`, `RwLock`, or atomic operations protect the access
3. Confirm the type doesn't already guarantee thread safety (e.g., `Arc<Mutex<T>>`)
4. Check if the "race" is actually benign (e.g., logging, metrics)

**Common false positives:**
- `Arc<Mutex<T>>` — already thread-safe
- Tokio channel operations — inherently synchronized
- `std::sync::atomic` operations — designed for concurrent access

### "Performance Issue"

**Before flagging**, you MUST:
1. Confirm the code runs frequently enough to matter
2. Verify the optimization would have measurable impact
3. Check if the compiler already optimizes this (iterator fusion, inlining)

**Do NOT flag:**
- Allocations in startup/initialization code
- String formatting in error paths
- Clone in test code
- `.collect()` on small iterators

## Severity Calibration

### Critical (Block Merge)

**ONLY use for:**
- `unsafe` code with unsound invariants
- SQL injection via string interpolation
- Use-after-free or memory safety violations
- Data races (concurrent mutation without synchronization)
- Panics in production code paths on user input

### Major (Should Fix)

**Use for:**
- Missing error context across module boundaries
- Blocking operations in async runtime
- Mutex guards held across await points
- Missing transaction for multi-statement database writes

### Minor (Consider Fixing)

**Use for:**
- Missing doc comments on public items
- `String` parameters where `&str` would work
- Suboptimal iterator patterns
- Missing `#[must_use]` on functions with important return values

### Informational (No Action Required)

**Use for:**
- Suggestions for newtypes, builder patterns, or type state
- Performance optimizations without measured impact
- Suggestions to add `#[non_exhaustive]`
- Refactoring ideas for trait design

**These are NOT review blockers.**

### Do NOT Flag At All

- Style preferences where both approaches are valid (e.g., `if let` vs `match` for single variant)
- Optimizations with no measurable benefit
- Test code not meeting production standards
- Generated code or macro output
- Clippy lints that the project has intentionally suppressed

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
| `#[allow(clippy::...)]` with reason | Intentional suppression is valid |
| `#[expect(lint)]` instead of `#[allow]` | Self-cleaning suppression (stable since 1.81) — warns when lint no longer triggers |
| `unsafe {}` inside `unsafe fn` | Required in edition 2024 (`unsafe_op_in_unsafe_fn` = deny) |
| `unsafe extern "C" {}` | Required in edition 2024 for extern blocks |
| `#[unsafe(no_mangle)]` | Required in edition 2024 for safety-relevant attributes |
| `#[unsafe(export_name = "...")]` | Required in edition 2024 for safety-relevant attributes |
| `+ use<'a, T>` on `impl Trait` returns | Precise capture syntax for edition 2024 RPIT |
| `r#gen` as identifier | `gen` is reserved in edition 2024 |
| `LazyLock` / `LazyCell` | Standard library replacements for `once_cell`/`lazy_static` (stable since 1.80) |
| `async fn` in trait definitions | No longer needs `async-trait` crate (stable since 1.75) |
| `#[diagnostic::on_unimplemented]` | Custom trait error messages (stable since 1.78) |

### Async/Tokio

| Pattern | Why It's Valid |
|---------|----------------|
| `std::sync::Mutex` for short critical sections | Tokio docs recommend this for non-async locks |
| `tokio::spawn` without join | Valid for background tasks with shutdown signaling |
| `select!` with `default` branch | Non-blocking check, intentional pattern |
| `#[tokio::test]` without multi_thread | Default single-thread is fine for most tests |

### Testing

| Pattern | Why It's Valid |
|---------|----------------|
| `expect()` in tests | Acceptable for test setup/assertions |
| `#[should_panic]` with `expected` | Valid for testing panic behavior |
| Large test functions | Integration tests can be long |
| `let _ = ...` in test cleanup | Cleanup errors are often unactionable |

### General

| Pattern | Why It's Valid |
|---------|----------------|
| `todo!()` in new code | Valid placeholder during development |
| `#[allow(dead_code)]` during development | Common during iteration |
| Multiple `impl` blocks for one type | Organized by trait or concern |
| Type aliases for complex types | Reduces boilerplate, improves readability |

## Context-Sensitive Rules

### Ownership

Flag unnecessary `.clone()` **ONLY IF**:
- [ ] In a hot path (not test/setup code)
- [ ] A borrow or reference would work
- [ ] The clone is not required for `Send`/`'static` bounds
- [ ] The type is not `Copy`

### Error Handling

Flag missing error context **ONLY IF**:
- [ ] Error crosses a module boundary
- [ ] The error type doesn't already carry context (thiserror messages)
- [ ] Not in test code
- [ ] The bare `?` loses meaningful information about what operation failed

### Unsafe Code

Flag unsafe **ONLY IF**:
- [ ] Safety comment is missing or doesn't explain the invariant
- [ ] The unsafe block is broader than necessary
- [ ] The invariant is not actually upheld by surrounding code
- [ ] A safe alternative exists with equivalent performance

**Edition 2024 unsafe changes** — check `Cargo.toml` edition before flagging:
- `unsafe {}` inside `unsafe fn` is **required** (not style) in edition 2024
- `unsafe extern "C" {}` is **required** in edition 2024 — bare `extern "C" {}` is a compile error
- `#[unsafe(no_mangle)]` and `#[unsafe(export_name)]` are **required** in edition 2024
- In edition 2021, these patterns are optional style choices — do not require them

## Edition-Aware Review

**BEFORE flagging any edition-specific pattern**, check `Cargo.toml` for the project's edition:

```toml
[package]
edition = "2024"  # or "2021", "2018"
```

Edition 2024 changes that affect review findings:

| Change | Edition 2021 | Edition 2024 |
|--------|--------------|--------------|
| `unsafe` inside `unsafe fn` | Optional style | Required (`unsafe_op_in_unsafe_fn` = deny) |
| `extern "C" {}` | Valid | Must be `unsafe extern "C" {}` |
| `#[no_mangle]` | Valid | Must be `#[unsafe(no_mangle)]` |
| `#[export_name]` | Valid | Must be `#[unsafe(export_name)]` |
| `-> impl Trait` lifetime capture | Explicit only | Captures all in-scope lifetimes |
| `gen` as identifier | Valid | Reserved keyword (use `r#gen`) |
| `!` type fallback | Falls back to `()` | Falls back to `!` |
| `if let` temporaries | Dropped at end of block | Dropped earlier (end of `if let`) |
| Tail expression temporaries | Dropped after locals | Dropped before local variables |
| `Box<[T]>` iteration | Needs explicit `.iter()` | Has `IntoIterator` impl |

**If edition is not specified**, Rust defaults to edition 2015. Most modern projects use 2021 or later.

**Cross-reference**: The `beagle-rust:rust-code-review` and `beagle-rust:rust-best-practices` skills provide edition-specific code review guidance and idiomatic patterns.

## Before Submitting Review

Final verification:
1. Re-read each finding and ask: "Did I verify this is actually an issue?"
2. For each finding, can you point to the specific line that proves the issue exists?
3. Would a Rust domain expert agree this is a problem, or is it a style preference?
4. Does fixing this provide real value, or is it busywork?
5. Format every finding as: `[FILE:LINE] ISSUE_TITLE`
6. For each finding, ask: "Does this fix existing code, or does it request entirely new code that didn't exist before?" If the latter, downgrade to Informational.
7. If this is a re-review: ONLY verify previous fixes. Do not introduce new findings.

If uncertain about any finding, either:
- Remove it from the review
- Mark it as a question rather than an issue
- Verify by reading more code context
