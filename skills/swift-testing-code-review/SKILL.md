---
name: swift-testing-code-review
description: "Reviews Swift Testing code for proper use of #expect/#require, parameterized tests, async testing, and suite organization. Use when reviewing .swift files with import Testing, @Test, #expect, @Suite, or confirmation patterns."
---

# Swift Testing Code Review

## Hard gates

Complete **in order** before recording Swift Testing review findings. Stack with `review-verification-protocol` at [review-verification-protocol](../review-verification-protocol/SKILL.md) for universal review rules.

1. **Scope:** You have an explicit list of `.swift` paths under review (or a user-named single file). **Pass:** Paths captured in working notes **or** one line: `No Swift files in scope` — then stop with no findings.
2. **Swift Testing surface:** For each path you treat as Swift Testing code, confirm `import Testing` **or** `@Test` / `#expect` / `#require` / `@Suite` appears in that file (open or search). **Pass:** At least one match per critiqued file, or you exclude that file from Swift Testing review with a one-line reason (e.g. XCTest-only).
3. **Evidence + protocol:** Load `review-verification-protocol` at [review-verification-protocol](../review-verification-protocol/SKILL.md) before asserting any issue. **Pass:** Each finding meets that skill’s anchor rules; any violated [Review Checklist](#review-checklist) item cites `[FILE:LINE]` evidence. If you report zero issues, state `Protocol applied; no Swift Testing issues` (or equivalent) in the review summary.

## Quick Reference

| Issue Type | Reference |
|------------|-----------|
| `#expect` vs `#require`, expression capture, error testing | [references/expect-macro.md](references/expect-macro.md) |
| `@Test` with arguments, traits, `zip()` pitfalls | [references/parameterized.md](references/parameterized.md) |
| `confirmation`, async sequences, continuations, exit tests | [references/async-testing.md](references/async-testing.md) |
| `@Suite`, tags, parallel execution, `.serialized`, `TestScoping` | [references/organization.md](references/organization.md) |

## Review Checklist

- [ ] Expressions embedded directly in `#expect` (not pre-computed booleans)
- [ ] `#require` used only for preconditions, `#expect` for assertions
- [ ] Error tests check specific types (`try #require(throws: ErrorType.self)` + `#expect`, not generic `(any Error).self` or deprecated `throws:` closure)
- [ ] Parameterized tests with pairs use `zip()` (not accidental Cartesian product)
- [ ] No logic mirroring implementation in parameterized expected values
- [ ] Async sequences tested with `confirmation(expectedCount:)`
- [ ] Completion handlers use `withCheckedContinuation` (never `confirmation` or XCTest `expectation`/`fulfillment` inside `@Test`)
- [ ] Process crashes (`precondition`/`fatalError`) tested with `#expect(processExitsWith:)` (Swift 6.2+), not skipped or untested
- [ ] `.serialized` applied only where necessary (shared resources); sibling serialized suites nested under a parent
- [ ] Custom setup/teardown or task-local bindings use `init`/`deinit` or `TestScoping` traits (Swift 6.1+), with no shared mutable static state
- [ ] Disabled tests have explanations and `.bug(...)` links

## When to Load References

- Reviewing `#expect` or `#require` usage -> [references/expect-macro.md](references/expect-macro.md)
- Reviewing `@Test` with arguments or traits -> [references/parameterized.md](references/parameterized.md)
- Reviewing `confirmation`, async testing, or exit tests -> [references/async-testing.md](references/async-testing.md)
- Reviewing `@Suite`, `TestScoping`, or test organization -> [references/organization.md](references/organization.md)

## Review Questions

1. Could pre-computed booleans in `#expect` lose diagnostic context?
2. Is `#require` stopping tests prematurely instead of revealing all failures?
3. Are multi-argument parameterized tests creating accidental Cartesian products?
4. Could `zip()` silently drop test cases due to unequal array lengths?
5. Are completion handlers or unstructured `Task`s incorrectly tested with `confirmation` or XCTest `fulfillment`?
