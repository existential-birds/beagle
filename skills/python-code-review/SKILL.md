---
name: python-code-review
description: Reviews Python code for type safety, async patterns, error handling, and common mistakes. Use when reviewing .py files, checking type hints, async/await usage, or exception handling.
---

# Python Code Review

## Quick Reference

| Issue Type | Reference |
|------------|-----------|
| Missing/wrong type hints, Any usage | [references/type-safety.md](references/type-safety.md) |
| Blocking calls in async, missing await | [references/async-patterns.md](references/async-patterns.md) |
| Bare except, missing context, logging | [references/error-handling.md](references/error-handling.md) |
| Mutable defaults, print statements | [references/common-mistakes.md](references/common-mistakes.md) |

## Review Checklist

- [ ] Type hints on all function parameters and return types
- [ ] No `Any` unless necessary (with comment explaining why)
- [ ] Proper `T | None` syntax (Python 3.10+)
- [ ] No blocking calls (`time.sleep`, `requests`) in async functions
- [ ] Proper `await` on all coroutines
- [ ] No bare `except:` clauses
- [ ] Specific exception types with context
- [ ] `raise ... from` to preserve stack traces
- [ ] No mutable default arguments
- [ ] Using `logger` not `print()` for output
- [ ] f-strings preferred over `.format()` or `%`

## When to Load References

- Reviewing function signatures → type-safety.md
- Reviewing `async def` functions → async-patterns.md
- Reviewing try/except blocks → error-handling.md
- General Python review → common-mistakes.md

## Review Questions

1. Are all function signatures fully typed?
2. Are async functions truly non-blocking?
3. Do exceptions include meaningful context?
4. Are there any mutable default arguments?
