---
name: rust-testing-code-review
description: Reviews Rust test code for unit test patterns, integration test structure, async testing, mocking approaches, and property-based testing. Use when reviewing _test.rs files, #[cfg(test)] modules, or test infrastructure in Rust projects. Covers tokio::test, test fixtures, and assertion patterns.
---

# Rust Testing Code Review

## Review Workflow

1. **Check test organization** — Unit tests in `#[cfg(test)]` modules, integration tests in `tests/` directory
2. **Check async test setup** — `#[tokio::test]` for async tests, proper runtime configuration
3. **Check assertions** — Meaningful messages, correct assertion type
4. **Check test isolation** — No shared mutable state between tests, proper setup/teardown
5. **Check coverage patterns** — Error paths tested, edge cases covered

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
| Unit test structure, assertions, test organization | [references/unit-tests.md](references/unit-tests.md) |
| Integration tests, async testing, fixtures, test databases | [references/integration-tests.md](references/integration-tests.md) |

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

### Assertions
- [ ] `assert_eq!` / `assert_ne!` used for value comparisons (better error messages than `assert!`)
- [ ] Custom messages on assertions that aren't self-documenting
- [ ] `matches!` macro used for enum variant checking
- [ ] Error types checked with `matches!` or pattern matching, not string comparison
- [ ] One assertion per test where practical (easier to diagnose failures)

### Mocking and Test Doubles
- [ ] Traits used as seams for dependency injection (not concrete types)
- [ ] Mock implementations kept minimal — only what the test needs
- [ ] No mocking of types you don't own (wrap external dependencies behind your own trait)
- [ ] Test fixtures as helper functions, not global state

### Error Path Testing
- [ ] `Result::Err` variants tested, not just happy paths
- [ ] Specific error variants checked (not just "is error")
- [ ] `#[should_panic]` used sparingly — prefer `Result`-returning tests

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

### Minor
- Missing assertion messages on complex comparisons
- `assert!(x == y)` instead of `assert_eq!(x, y)` (worse error messages)
- Test names that don't describe the scenario
- Redundant setup code that could be extracted to a helper

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

## Before Submitting Findings

Load and follow `beagle-rust:review-verification-protocol` before reporting any issue.
