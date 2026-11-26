# Rust-Specific Review Verification

Complements the general verification gates in [review-verification-protocol](../../review-verification-protocol/SKILL.md) with Rust-, Tokio-, concurrency-, and testing-specific false-positive guards and calibration rules.

## Verification by Issue Type

### "Unused Variable/Function"

**Before flagging**, you MUST:
1. Search for ALL references in the workspace (`rg` / IDE references).
2. Check if it is `pub` and consumed by other workspace crates or downstream targets.
3. Check if it is used via derive macros, trait implementations, or conditional compilation (`#[cfg]`).
4. Verify it is not a trait method required by a trait definition.

**Common false positives:**
- Trait implementations where the method is required by the trait.
- `#[cfg(test)]` items only built under `cargo test`.
- Derive-generated code consuming struct fields.
- Types constructed or converted via `From` / `Into`.

### "Missing Error Handling"

**Before flagging**, you MUST:
1. Check if the error is propagated via `?` to a caller that handles it.
2. Check if the crate uses a top-level error type wrapping this error.
3. Verify `unwrap()` / `expect()` is not in test code or after an invariant/literal check.

**Common false positives:**
- `unwrap()` in tests and examples.
- `expect("reason")` on compile-time known valid inputs (e.g., literal `regex::Regex::new(...)`).
- Error propagation via `?`.
- `let _ = tx.send(...)` — intentional when receivers may have already dropped.

### "Unnecessary Lifetime" / RPIT Capture (Edition 2024)

**Before flagging**, you MUST:
1. Check the crate's `edition` in `Cargo.toml`.
2. In Edition 2024, `-> impl Trait` captures ALL in-scope generic lifetimes/types by default.
3. A lifetime that appears unused in the trait bound may be implicitly captured — the signature is valid.
4. `+ use<'a, T>` is Edition 2024's precise capture syntax, not a mistake.

### "Missing Unsafe Block" / Unsafe Syntax (Edition 2024)

**Before flagging**, you MUST:
1. Check `Cargo.toml` `edition`.
2. In Edition 2024, `unsafe_op_in_unsafe_fn` is `warn` by default (upgraded from `allow` in 2021; often fails CI under `-D warnings`) — unsafe operations inside `unsafe fn` require explicit `unsafe {}` blocks.
3. `unsafe extern "C" {}`, `#[unsafe(no_mangle)]`, and `#[unsafe(export_name = "...")]` are required in Edition 2024 (do NOT flag as redundant verbosity).

### "Unnecessary Clone"

**Before flagging**, you MUST:
1. Confirm the borrow checker does not require ownership here.
2. Check if the value is moved into a closure, thread, or `'static` async task (`tokio::spawn`).
3. Verify the type is not `Copy` (`.clone()` on `Copy` types is a no-op).
4. Check if the code is on a hot path (setup/initialization/test cloning is fine).

**Common false positives:**
- `Arc::clone(&arc)` — idiomatic explicit refcount increment.
- Cloning before `tokio::spawn` — required for `'static` task bounds.
- Cloning in test setup — clarity over micro-optimization.

### "Potential Race Condition"

**Before flagging**, you MUST:
1. Verify the data is actually shared across threads or concurrent tasks.
2. Check if `Mutex`, `RwLock`, or atomic operations protect all accesses.
3. Confirm the wrapper doesn't already guarantee synchronization (e.g., `Arc<Mutex<T>>`).
4. Check if a benign race is intentional (e.g., relaxed metrics/stop flags).

**Common false positives:**
- `Arc<Mutex<T>>` — already thread-safe (unless guard is held across `.await`).
- Tokio channel operations — inherently synchronized.
- `std::sync::atomic` operations — designed for lock-free concurrent access.

### "Performance Issue"

**Before flagging**, you MUST:
1. Confirm the code runs frequently enough to matter.
2. Verify the optimization would have measurable impact.
3. Check if the compiler already eliminates the cost (inlining, iterator fusion).

**Do NOT flag:**
- Allocations in startup/initialization code.
- String formatting in error paths.
- Cloning in test code.
- `.collect()` on small iterators.

## Concurrency-Specific Verification

### "Memory Ordering Too Weak"

Complements `memory-ordering.md` in the `rust-code-review` skill:

**Before flagging**, you MUST:
1. Verify the atomic is actually shared between threads that depend on happens-before synchronization.
2. Check if `Relaxed` is sufficient (independent counters, metrics, standalone stop flags with no dependent data).
3. Confirm whether `Acquire`/`Release` vs `SeqCst` actually changes correctness (most code does not need `SeqCst`).

**Common false positives:**
- `Relaxed` on simple counters/metrics — no ordering needed for independent values.
- `Relaxed` on boolean stop flags polled in a loop — loop polling achieves eventual visibility when no other data rides on the flag.
- `SeqCst` used defensively — not incorrect, though potentially over-synchronized (downgrade to Informational/Minor unless hot-path contention is proven).

## Context-Sensitive Rules

### Ownership (`.clone()`)

Flag unnecessary `.clone()` **ONLY IF ALL** of these hold:
- [ ] In a hot path (not test/setup/startup code)
- [ ] A borrow or reference compiles under the borrow checker
- [ ] The clone is not required for `Send`/`'static` bounds
- [ ] The type is not `Copy`

### Error Handling

Flag missing error context **ONLY IF ALL** of these hold:
- [ ] Error crosses a module or crate boundary
- [ ] The error type does not already carry context (`thiserror` messages)
- [ ] Not in test code
- [ ] Bare `?` loses meaningful information about what operation failed

### Unsafe Code

Flag `unsafe` **ONLY IF ANY** of these hold:
- [ ] `// SAFETY:` comment is missing or does not explain the invariant
- [ ] The `unsafe` block is broader than necessary
- [ ] The invariant is not actually upheld by surrounding code
- [ ] A safe alternative exists with equivalent performance

## Rust Severity Calibration Notes

- **Major**: Blocking operations in an async runtime, `std::sync::Mutex` (or non-Send) guard held across `.await`, missing DB transaction for multi-statement writes, missing error context across module boundaries.
- **Minor**: Missing `#[must_use]` on functions with important return values, `String` parameters where `&str` suffices, suboptimal iterator patterns.
- **Informational**: Suggestions for newtypes, builders, `#[non_exhaustive]`, or unmeasured micro-optimizations.
- **Do NOT Flag**: Style preferences where both forms are valid (e.g., `if let` vs `match` for a single variant), Clippy lints intentionally suppressed by the project (`#[allow]` / `#[expect]`), or generated macro output.

## Valid Patterns (Do NOT Flag)

### Rust

| Pattern | Why It's Valid |
|---------|----------------|
| `unwrap()` / `expect()` in tests | Standard test behavior — panics on unexpected failures |
| `.clone()` in test setup | Clarity over performance |
| `use super::*` in test modules | Idiomatic access to parent module items |
| `Box<dyn Error>` in binaries | Not every application needs custom error enums |
| `String` fields in structs | Owned data avoids infectious lifetimes |
| `Arc::clone(&x)` | Explicit refcount clone is recommended |
| `#[allow(clippy::...)]` with reason | Intentional suppression is valid |
| `#[expect(lint)]` instead of `#[allow]` | Self-cleaning suppression (stable since 1.81) — warns when lint no longer triggers |
| `unsafe {}` inside `unsafe fn` | Required to avoid `unsafe_op_in_unsafe_fn` warning in Edition 2024 |
| `unsafe extern "C" {}` | Required in Edition 2024 for extern blocks |
| `#[unsafe(no_mangle)]` / `#[unsafe(export_name = "...")]` | Required in Edition 2024 for safety-relevant attributes |
| `+ use<'a, T>` on `impl Trait` returns | Precise capture syntax for Edition 2024 RPIT |
| `r#gen` as identifier | `gen` is a reserved keyword in Edition 2024 |
| `LazyLock` / `LazyCell` | Standard library replacements for `once_cell`/`lazy_static` (stable since 1.80) |
| `async fn` in trait definitions | Native support without `async-trait` (stable since 1.75) |
| `#[diagnostic::on_unimplemented]` | Custom trait error messages (stable since 1.78) |

### Async / Tokio

| Pattern | Why It's Valid |
|---------|----------------|
| `std::sync::Mutex` for short critical sections | Tokio docs recommend this when lock is never held across `.await` |
| `tokio::spawn` without joining | Valid for background tasks with cancellation/shutdown signaling |
| `select!` with `default` (or `biased`) | Intentional non-blocking poll / priority ordering |
| `#[tokio::test]` without `multi_thread` | Default `current_thread` flavor is right for most unit tests |

### Testing

| Pattern | Why It's Valid |
|---------|----------------|
| `expect()` in tests | Acceptable for test setup and assertions |
| `#[should_panic(expected = "...")]` | Valid for verifying expected panic messages |
| Large integration test functions | End-to-end tests can legitimately be long |
| `let _ = ...` in test cleanup | Cleanup errors are often unactionable |

### General

| Pattern | Why It's Valid |
|---------|----------------|
| `todo!()` in WIP/unimplemented stubs | Valid placeholder during development (flag only if reachable in prod PR) |
| Multiple `impl` blocks for one type | Standard organization by trait or concern |
| Type aliases for complex types | Improves readability |
