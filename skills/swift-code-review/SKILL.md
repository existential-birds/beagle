---
name: swift-code-review
description: "Reviews Swift code for concurrency safety, error handling, memory management, and common mistakes. Use when reviewing .swift files for async/await patterns, actor isolation, Sendable conformance, or general Swift best practices."
---

# Swift Code Review

## Review Workflow

Follow this sequence **in order**. Do not emit findings until every **Pass** below is satisfied.

1. **Swift / toolchain baseline** — Establish language and tooling context: `Package.swift` `// swift-tools-version` and per-target `swiftSettings` (including `NonisolatedNonsendingByDefault`, `InferIsolatedConformances`, or `MainActor` default isolation); for Xcode, `SWIFT_VERSION` and Swift 6.2 `SWIFT_DEFAULT_ACTOR_ISOLATION` / approachable concurrency build settings; note if review is single-file only.  
   **Pass:** You state a concrete Swift language version or mode (e.g. Swift 6.2 with `MainActor` default isolation, Swift 6 language mode, tools 5.10) *before* advice that depends on strict concurrency, approachable concurrency, migration-only syntax, or SDK availability.

2. **Read surrounding code** — For each changed `.swift` file, read the full enclosing type, function, method, or property that contains the edits, not only the diff hunk.  
   **Pass:** At least one full enclosing symbol (type or member) containing the change was read per changed file.

3. **Scope the checklist** — Using [Quick Reference](#quick-reference), decide which [Review Checklist](#review-checklist) rows and [references](#when-to-load-references) apply; open those reference files; skip rows clearly unrelated to the diff.  
   **Pass:** The review (or working notes) lists which checklist areas you applied, or marks areas N/A with a one-line reason tied to the diff (e.g. “no SwiftUI / @Observable in change”).

4. **Pre-report verification** — Load and follow `review-verification-protocol` at [review-verification-protocol](../review-verification-protocol/SKILL.md).  
   **Pass:** That skill’s **Hard gates (sequenced)** are satisfied for each finding you will report (full symbol read, usage search before “unused”, caller checked before “missing handling”, severity calibrated, `[FILE:LINE]` proof).

## Hard gates (same sequence, shorter)

| Step | Objective pass condition |
| --- | --- |
| 1 | Swift version/mode and default actor isolation settings (or explicit single-file limitation) recorded before version- or SDK-gated advice. |
| 2 | Full enclosing symbol read per changed file, not diff-only. |
| 3 | Checklist areas + references listed or N/A with diff-tied reason. |
| 4 | `review-verification-protocol` completed for every reported issue. |

## Output format

Report findings as:

```text
[FILE:LINE] ISSUE_TITLE
Severity: Critical | Major | Minor | Informational
Description of the issue and why it matters.
```

## Quick Reference

| Issue Type | Reference |
|------------|-----------|
| async/await, actors, Sendable, Task, Swift 6.2 isolation | [references/concurrency.md](references/concurrency.md) |
| @Observable, @ObservationIgnored, observation tracking | [references/observable.md](references/observable.md) |
| throws, typed throws, CancellationError, Result | [references/error-handling.md](references/error-handling.md) |
| Force unwraps, IUOs, retain cycles, unowned traps | [references/common-mistakes.md](references/common-mistakes.md) |

## Review Checklist

- [ ] No force unwraps (`!`) or `try!` on runtime data (network, user input, files)
- [ ] Escaping closures stored as properties (and long-lived `Task` loops) use `[weak self]`; `unowned` only when lifetime is strictly guaranteed
- [ ] Delegate properties are `weak`
- [ ] Independent async operations use `async let` or `TaskGroup`
- [ ] Long-running `Task` loops check cancellation (`try Task.checkCancellation()` or `Task.isCancelled`) and don't swallow `CancellationError`
- [ ] Swift 6.2 isolation settings respected (`@concurrent` for CPU-bound offloads under `NonisolatedNonsendingByDefault`; don't flag missing `@MainActor` if target uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`)
- [ ] Actors have mutable state to protect (no stateless actors) and guard invariants across `await` suspension points
- [ ] `Sendable` / `@unchecked Sendable` types are genuinely thread-safe (backed by real synchronization)
- [ ] Errors handled explicitly (no silent `Task` failures or broad `catch` swallowing `CancellationError`)
- [ ] Non-tracked/injected/Combine properties in `@Observable` classes use `@ObservationIgnored`
- [ ] Nested observed reference types inside `@Observable` models are also `@Observable`

## When to Load References

- Reviewing async/await, actors, `Sendable`, or Swift 6.2 concurrency → [references/concurrency.md](references/concurrency.md)
- Reviewing `@Observable` macro design or `withObservationTracking` → [references/observable.md](references/observable.md)
- Reviewing typed throws, `CancellationError`, or error propagation → [references/error-handling.md](references/error-handling.md)
- Reviewing force unwraps, retain cycles, `unowned`, or IUOs → [references/common-mistakes.md](references/common-mistakes.md)

## Review Questions

1. Are independent async operations running concurrently with `async let` or `TaskGroup`?
2. Could actor state change across suspension points (reentrancy bug)?
3. Under Swift 6.2 Approachable Concurrency, are heavy CPU tasks explicitly marked `@concurrent` instead of blocking the caller's actor?
4. Is `@unchecked Sendable` backed by actual synchronization?
5. Could any broad `catch` block accidentally swallow `CancellationError` or `Task` failure?
6. Could any stored closure, delegate, or long-lived `AsyncSequence` `Task` create a retain cycle?
