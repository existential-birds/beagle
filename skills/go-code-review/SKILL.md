---
name: go-code-review
description: Reviews Go code for idiomatic patterns, error handling, concurrency safety, and common mistakes. Use when reviewing .go files, checking error handling, goroutine usage, or interface design.
---

# Go Code Review

## Quick Reference

| Issue Type | Reference |
|------------|-----------|
| Missing error checks, wrapped errors | [references/error-handling.md](references/error-handling.md) |
| Race conditions, channel misuse | [references/concurrency.md](references/concurrency.md) |
| Interface pollution, naming | [references/interfaces.md](references/interfaces.md) |
| Resource leaks, defer misuse | [references/common-mistakes.md](references/common-mistakes.md) |

## Review Checklist

- [ ] All errors are checked (no `_ = err`)
- [ ] Errors wrapped with context (`fmt.Errorf("...: %w", err)`)
- [ ] Resources closed with `defer` immediately after creation
- [ ] No goroutine leaks (channels closed, contexts canceled)
- [ ] Interfaces defined by consumers, not producers
- [ ] Interface names end in `-er` (Reader, Writer, Handler)
- [ ] Exported names have doc comments
- [ ] No naked returns in functions > 5 lines
- [ ] Context passed as first parameter
- [ ] Mutexes protect shared state, not methods

## When to Load References

- Reviewing error return patterns → error-handling.md
- Reviewing goroutines/channels → concurrency.md
- Reviewing type definitions → interfaces.md
- General Go review → common-mistakes.md

## Review Questions

1. Are all error returns checked and wrapped?
2. Are goroutines properly managed with context cancellation?
3. Are resources (files, connections) closed with defer?
4. Are interfaces minimal and defined where used?
