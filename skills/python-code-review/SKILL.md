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

## Valid Patterns (Do NOT Flag)

These patterns are intentional and correct - do not report as issues:

- **`|| []` or `or []` fallback for dict.get()** - `dict.get()` returns value or None, the fallback handles None correctly
- **Type annotation vs type assertion** - Annotations declare types but are not runtime assertions; don't confuse with missing validation
- **Using `Any` when interacting with untyped libraries** - Required when external libraries lack type stubs
- **Empty `__init__.py` files** - Valid for package structure, no code required
- **`# type: ignore` comments** - Acceptable when type checker is incorrect or overly strict
- **`noqa` comments** - Valid when linter rule doesn't apply to specific case
- **Using `cast()` after runtime type check** - Correct pattern to inform type checker of narrowed type

## Context-Sensitive Rules

Only flag these issues when the specific conditions apply:

| Issue | Flag ONLY IF |
|-------|--------------|
| Mutable default arguments | The default is actually modified in the function body |
| Missing type hints | Function is public API (no leading underscore) or has complex logic |
| Generic exception handling | Specific exception types are available and meaningful |
| Unused variables | Variable isn't used in f-strings, logging, debugging, or `_` prefix |

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

## Before Submitting Findings

Load and follow [review-verification-protocol](../review-verification-protocol/SKILL.md) before reporting any issue.
