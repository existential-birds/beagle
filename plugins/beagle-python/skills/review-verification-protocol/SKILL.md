---
name: review-verification-protocol
description: Mandatory verification steps for all code reviews to reduce false positives. Load this skill before reporting ANY code review findings.
user-invocable: false
---

# Review Verification Protocol — Python delta

**Load `beagle-core:review-verification-protocol` first.** It carries the hard gates, the Pre-Report Verification Checklist, Severity Calibration, the imported `beagle-core:verification-budget` vocabulary (risk tiers, loop budgets, the one-echo rule, the prove-a-negative ban), and the language-neutral Verification by Issue Type sections.

This file adds **only** what is specific to Python and its web/data stack. Everything else is in the core; nothing here overrides it.

## Verification by Issue Type — Python specifics

### "Unused Variable/Function"

Run the core's four-pattern reference search. Python reference patterns that plain grep misses:

- Decorator registration (`@app.route`, `@pytest.fixture`, `@celery.task`, `@click.command`)
- `getattr` / `importlib` / plugin-entry-point dispatch and setuptools console scripts
- Names re-exported through `__init__.py` or listed in `__all__`
- Pydantic validators and SQLAlchemy event listeners invoked by the framework, never by a call site

### "Missing Validation/Error Handling"

Check whether FastAPI + Pydantic already validate the payload, whether a dependency (`Depends`) enforces it, or whether an exception handler or middleware catches the error at a higher level.

### "Type Assertion/Unsafe Cast"

An annotation is not a cast, and `isinstance` narrowing is safe:

```python
# Type annotation, NOT a cast
data: UserData = await load_user()

# Type narrowing with isinstance
if isinstance(data, User):
    data.name  # the type checker knows this is User
```

`typing.cast()` after a runtime check that establishes the type is valid.

### "Potential Leak / Race Condition"

- Check for a context manager (`with`, `async with`) or a `finally` block before claiming missing cleanup
- Check whether an `asyncio.Task` is cancelled on shutdown or tracked in a task set
- Confirm the state is genuinely shared across tasks or threads

## Valid Patterns (Do NOT Flag)

### Python

| Pattern | Why It's Valid |
|---------|----------------|
| `dict.get(key, [])` | Returns a default for missing keys, not error suppression |
| `Optional[T]` return type | Standard way to express nullable in Python typing |
| `assert` in test code | pytest uses assertions, not try/except |
| Type annotation on a variable | Not a cast, just a hint for type checkers |
| `typing.cast()` with prior validation | Valid after a runtime check confirms the type |

### FastAPI

| Pattern | Why It's Valid |
|---------|----------------|
| `Depends()` without an explicit type | FastAPI infers the dependency type from the signature |
| `async def` endpoint without `await` | May use sync DB calls or simple returns |
| Response model different from the DB model | Separation of concerns between API and persistence |
| `BackgroundTasks` parameter | Valid for fire-and-forget operations |
| Direct `request.state` access | Standard pattern for middleware-injected data |

### Testing

| Pattern | Why It's Valid |
|---------|----------------|
| `assert` without a message | pytest rewrites assertions to show detailed diffs |
| `@pytest.fixture` without an explicit scope | Default `function` scope is correct for most fixtures |
| `monkeypatch` over `unittest.mock` | Simpler API, pytest-native |
| Fixture returning mutable state | Each test gets a fresh fixture invocation by default |

## Context-Sensitive Rules

Each list below is an enumerated check, evaluated once. If an item is undecidable, drop the finding or ship it as a question — do not open another verification pass.

### Type Annotations

Flag a missing type annotation **ONLY IF ALL** of these hold:
- [ ] The function is public API (not prefixed with `_`)
- [ ] Types are not obvious from context (`x = 5` is clearly `int`)
- [ ] Not a test function or fixture
- [ ] The codebase has existing typing conventions

### Exception Handling

Flag a bare `except` **ONLY IF**:
- [ ] Not in a top-level error boundary or middleware
- [ ] The caught exception is actually swallowed (not logged or re-raised)
- [ ] Specific exception types are known and available
- [ ] Not in cleanup/teardown code where any error should be caught

### Error Handling

Flag a missing try/except **ONLY IF**:
- [ ] No middleware or error handler catches this at a higher level
- [ ] The framework doesn't handle it (FastAPI exception handlers)
- [ ] The error would cause a crash, not just a failed operation
- [ ] The user needs specific feedback for this error type
