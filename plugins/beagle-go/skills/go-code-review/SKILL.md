---
name: go-code-review
description: Reviews Go code for idiomatic patterns, error handling, concurrency safety, and common mistakes. Use when reviewing .go files, checking error handling, goroutine usage, or interface design. Covers generics (Go 1.18+), errors.Join and slog (Go 1.21+), and Go 1.22 loop variable semantics.
---

# Go Code Review

## Review Workflow

Follow this sequence to avoid false positives and catch version-specific issues:

1. **Check `go.mod`** — Note the Go version. This determines which patterns apply (loop variable capture is only an issue pre-1.22, `slog` is available from 1.21, `errors.Join` from 1.20). Skip version-gated checks that don't apply.
2. **Scan changed files** — Read full functions, not just diffs. Many Go bugs hide in what surrounds the change.
3. **Check each category** — Work through the checklist below, loading references as needed.
4. **Verify before reporting** — Load beagle-go:review-verification-protocol before submitting findings.

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
| Missing error checks, wrapping, errors.Join | [references/error-handling.md](references/error-handling.md) |
| Race conditions, channel misuse, goroutine lifecycle | [references/concurrency.md](references/concurrency.md) |
| Interface pollution, naming, generics | [references/interfaces.md](references/interfaces.md) |
| Resource leaks, defer misuse, slog, naming | [references/common-mistakes.md](references/common-mistakes.md) |

## Review Checklist

### Error Handling
- [ ] All errors checked (no `_ = err` without justifying comment)
- [ ] Errors wrapped with context (`fmt.Errorf("...: %w", err)`)
- [ ] `errors.Is`/`errors.As` used instead of string matching
- [ ] `errors.Join` used for aggregating multiple errors (Go 1.20+)
- [ ] Zero values returned alongside errors

### Concurrency
- [ ] No goroutine leaks (context cancellation or shutdown signal exists)
- [ ] Channels closed by sender only, exactly once
- [ ] Shared state protected by mutex or sync types
- [ ] WaitGroups used to wait for goroutine completion
- [ ] Context propagated through call chain
- [ ] Loop variable capture handled (pre-Go 1.22 codebases only)

### Interfaces and Types
- [ ] Interfaces defined by consumers, not producers
- [ ] Interface names follow `-er` convention
- [ ] Interfaces minimal (1-3 methods)
- [ ] Concrete types returned from constructors
- [ ] `any` preferred over `interface{}` (Go 1.18+)
- [ ] Generics used where appropriate instead of `any` or code generation

### Resources and Lifecycle
- [ ] Resources closed with `defer` immediately after creation
- [ ] HTTP response bodies always closed
- [ ] No `defer` in loops without closure wrapping
- [ ] `init()` functions avoided in favor of explicit initialization

### Naming and Style
- [ ] Exported names have doc comments
- [ ] No stuttering names (`user.UserService` → `user.Service`)
- [ ] No naked returns in functions > 5 lines
- [ ] Context passed as first parameter
- [ ] `slog` used over `log` for structured logging (Go 1.21+)

## Severity Calibration

### Critical (Block Merge)
- Unchecked errors on I/O, network, or database operations
- Goroutine leaks (no shutdown path)
- Race conditions on shared state (concurrent map access without sync)
- Unbounded resource accumulation (defer in loop, unclosed connections)

### Major (Should Fix)
- Errors returned without context (bare `return err`)
- Missing WaitGroup for spawned goroutines
- `panic` for recoverable errors
- Context not propagated to downstream calls

### Minor (Consider Fixing)
- `interface{}` instead of `any` in Go 1.18+ codebases
- Missing doc comments on exports
- Stuttering names
- Slice not preallocated when size is known

### Informational (Note Only)
- Suggestions to add generics where code generation exists
- Refactoring ideas for interface design
- Performance optimizations without measured impact

## When to Load References

- Reviewing error return patterns → error-handling.md
- Reviewing goroutines, channels, or sync types → concurrency.md
- Reviewing type definitions, interfaces, or generics → interfaces.md
- General review (resources, naming, init, performance) → common-mistakes.md

## Valid Patterns (Do NOT Flag)

These are acceptable Go patterns — reporting them wastes developer time:

- **`_ = err` with reason comment** — Intentionally ignored errors with explanation
- **Empty interface / `any`** — For truly generic code or interop with untyped APIs
- **Naked returns in short functions** — Acceptable in functions < 5 lines with named returns
- **Channel without close** — When consumer stops via context cancellation, not channel close
- **Mutex protecting struct fields** — Even if accessed only via methods, this is correct encapsulation
- **`//nolint` directives with reason** — Acceptable when accompanied by explanation
- **Defer in loop** — When function scope cleanup is intentional (e.g., processing files in batches)
- **Functional options pattern** — `type Option func(*T)` with `With*` constructors is idiomatic
- **`sync.Pool` for hot paths** — Acceptable for reducing allocation pressure in performance-critical code
- **`context.Background()` in main/tests** — Valid root context for top-level calls
- **`select` with `default`** — Non-blocking channel operation, intentional pattern
- **Short variable names in small scope** — `i`, `err`, `ctx`, `ok` are idiomatic Go

## Context-Sensitive Rules

Only flag these issues when the specific conditions apply:

| Issue | Flag ONLY IF |
|-------|--------------|
| Missing error check | Error return is actionable (can retry, log, or propagate) |
| Goroutine leak | No context cancellation path exists for the goroutine |
| Missing defer | Resource isn't explicitly closed before next acquisition or return |
| Interface pollution | Interface has > 1 method AND only one consumer exists |
| Loop variable capture | `go.mod` specifies Go < 1.22 |
| Missing slog | `go.mod` specifies Go >= 1.21 AND code uses `log` package for structured output |

## Before Submitting Findings

Load and follow [review-verification-protocol](../review-verification-protocol/SKILL.md) before reporting any issue.
