---
name: rust-testing-code-review
description: Reviews Rust test code for unit test patterns, integration test structure, async testing, mocking approaches, and property-based testing. Covers Rust 2024 edition changes including async fn in traits for mocks, #[expect] lint suppression, LazyLock test fixtures, and temporary scope changes affecting test assertions. Use when reviewing _test.rs files, #[cfg(test)] modules, or test infrastructure in Rust projects. Covers tokio::test, test fixtures, and assertion patterns.
---

# Rust Testing Code Review

## Review Workflow

1. **Check Rust edition** — Note edition in `Cargo.toml` (2021 vs 2024). Edition 2024 changes temporary scoping in `if let` and tail expressions, and makes `#[expect]` the preferred lint suppression
2. **Check test organization** — Unit tests in `#[cfg(test)]` modules, integration tests in `tests/` directory
3. **Check async test setup** — `#[tokio::test]` for async tests, proper runtime configuration. Check for `async-trait` on mocks that could use native `async fn` in traits
4. **Check assertions** — Meaningful messages, correct assertion type. Review `if let` assertions for edition 2024 temporary scope changes
5. **Check test isolation** — No shared mutable state between tests, proper setup/teardown. Prefer `LazyLock` over `lazy_static!`/`once_cell` for shared fixtures
6. **Check coverage patterns** — Error paths tested, edge cases covered

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
| Unit tests, assertions, naming, snapshots, rstest, doc tests, `#[expect]`, `LazyLock` fixtures, tail expression scope | [references/unit-tests.md](references/unit-tests.md) |
| Integration tests, async testing, fixtures, test databases, native `async fn` mocks, `if let` temporary scope | [references/integration-tests.md](references/integration-tests.md) |
| Fuzzing, property-based testing, Miri, Loom, benchmarking, compile_fail, custom harness, mocking strategies | [references/advanced-testing.md](references/advanced-testing.md) |

## Review Checklist

### Test Structure
- [ ] Unit tests in `#[cfg(test)] mod tests` within source files
- [ ] Integration tests in `tests/` directory (one file per module or feature)
- [ ] `use super::*` in test modules to access parent module items
- [ ] Test function names describe the scenario: `test_<function>_<scenario>_<expected>`
- [ ] Tests are independent — no reliance on execution order

### Async Tests
- [ ] `#[tokio::test]` used for async test functions
- [ ] `#[tokio::test(flavor = "multi_thread")]` when testing multi-threaded behavior
- [ ] No `block_on` inside async tests (use `.await` directly)
- [ ] Test timeouts set for tests that could hang
- [ ] Mock traits use native `async fn` instead of `async-trait` crate (stable since Rust 1.75)

### Assertions
- [ ] `assert_eq!` / `assert_ne!` used for value comparisons (better error messages than `assert!`)
- [ ] Custom messages on assertions that aren't self-documenting
- [ ] `matches!` macro used for enum variant checking
- [ ] Error types checked with `matches!` or pattern matching, not string comparison
- [ ] One assertion per test where practical (easier to diagnose failures)
- [ ] `if let` assertions reviewed for edition 2024 temporary scope — temporaries in conditions drop earlier, may invalidate borrows
- [ ] Tail expression returns reviewed for edition 2024 — temporaries in tail expressions drop before local variables

### Mocking and Test Doubles
- [ ] Traits used as seams for dependency injection (not concrete types)
- [ ] Mock implementations kept minimal — only what the test needs
- [ ] No mocking of types you don't own (wrap external dependencies behind your own trait)
- [ ] Test fixtures as helper functions, not global state
- [ ] `std::sync::LazyLock` used for shared test fixtures instead of `lazy_static!` or `once_cell` (stable since Rust 1.80)

### Error Path Testing
- [ ] `Result::Err` variants tested, not just happy paths
- [ ] Specific error variants checked (not just "is error")
- [ ] `#[should_panic]` used sparingly — prefer `Result`-returning tests

### Lint Suppression in Tests
- [ ] `#[expect(lint)]` used instead of `#[allow(lint)]` for test-specific suppressions (stable since Rust 1.81)
- [ ] Justification comment on every `#[expect]` or `#[allow]` in test code
- [ ] Stale `#[allow]` attributes migrated to `#[expect]` for self-cleaning behavior

### Test Naming
- [ ] Test names read like sentences describing behavior (not `test_happy_path`)
- [ ] Related tests grouped in nested `mod` blocks for organization
- [ ] Test names follow pattern: `<function>_should_<behavior>_when_<condition>`

### Snapshot Testing
- [ ] `cargo insta` used for complex structural output (JSON, YAML, HTML, CLI output)
- [ ] Snapshots are small and focused (not huge objects)
- [ ] Redactions used for unstable fields (timestamps, UUIDs)
- [ ] Snapshots committed to git in `snapshots/` directory
- [ ] Simple values use `assert_eq!`, not snapshots

### Parametrized Testing
- [ ] `rstest` used to avoid duplicated test functions for similar inputs
- [ ] `#[rstest]` with `#[case::name]` attributes for descriptive parametrized tests
- [ ] `#[fixture]` used for shared test setup when multiple tests need same construction
- [ ] Parametrized tests still have descriptive case names (not just `#[case(1)]`)
- [ ] Combined with async: `#[rstest] #[tokio::test]` for async parametrized tests

### Doc Tests
- [ ] Public API functions have `/// # Examples` with runnable code
- [ ] Doc tests serve as both documentation and correctness checks
- [ ] Hidden setup lines prefixed with `#` to keep examples clean
- [ ] `cargo test --doc` passes (nextest doesn't run doc tests)

## Severity Calibration

### Critical
- Tests that pass but don't actually verify behavior (assertions on wrong values)
- Shared mutable state between tests causing flaky results
- Missing error path tests for security-critical code

### Major
- `#[should_panic]` without `expected` message (catches any panic, including wrong ones)
- `unwrap()` in test setup that hides the real failure location
- Tests that depend on execution order
- `if let` with inline temporary in assertion that breaks under edition 2024 temporary scoping
- `async-trait` on mock traits when native `async fn` in traits is available and project targets edition 2024

### Minor
- Missing assertion messages on complex comparisons
- `assert!(x == y)` instead of `assert_eq!(x, y)` (worse error messages)
- Test names that don't describe the scenario
- Redundant setup code that could be extracted to a helper
- `#[allow]` used where `#[expect]` would provide self-cleaning suppression
- `lazy_static!` or `once_cell` used for test fixtures when `LazyLock` is available

### Informational
- Suggestions to add property-based tests via `proptest` or `quickcheck`
- Suggestions to add snapshot testing for complex output
- Coverage improvement opportunities

## Valid Patterns (Do NOT Flag)

- **`unwrap()` / `expect()` in tests** — Panicking on unexpected errors is the correct test behavior
- **`use super::*` in test modules** — Standard pattern for accessing parent items
- **`#[allow(dead_code)]` on test helpers** — Helper functions may not be used in every test
- **`clone()` in tests** — Clarity over performance
- **Large test functions** — Integration tests can be long; extracting helpers isn't always clearer
- **`assert!` for boolean checks** — Fine when the expression is clearly boolean (`.is_some()`, `.is_empty()`)
- **Multiple assertions testing one logical behavior** — Sometimes one behavior needs multiple checks
- **`unwrap()` on `Result`-returning test functions** — Propagating with `?` is also fine but not required
- **`async-trait` on mock traits requiring `dyn` dispatch** — Native `async fn` in traits doesn't support `dyn Trait`; `async-trait` is still needed there
- **`#[expect]` with justification on test helpers** — Self-cleaning lint suppression is correct in test code
- **`LazyLock` for expensive shared test fixtures** — Thread-safe lazy init is appropriate for test globals

## Before Submitting Findings

Load and follow `beagle-rust:review-verification-protocol` before reporting any issue.
