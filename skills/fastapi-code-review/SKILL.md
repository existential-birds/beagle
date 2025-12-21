---
name: fastapi-code-review
description: Reviews FastAPI code for routing patterns, dependency injection, validation, and async handlers. Use when reviewing FastAPI apps, checking APIRouter setup, Depends() usage, or response models.
---

# FastAPI Code Review

## Quick Reference

| Issue Type | Reference |
|------------|-----------|
| APIRouter setup, response_model, status codes | [references/routes.md](references/routes.md) |
| Depends(), yield deps, cleanup, shared deps | [references/dependencies.md](references/dependencies.md) |
| Pydantic models, HTTPException, 422 handling | [references/validation.md](references/validation.md) |
| Async handlers, blocking I/O, background tasks | [references/async.md](references/async.md) |

## Review Checklist

- [ ] APIRouter with proper prefix and tags
- [ ] All routes specify `response_model` for type safety
- [ ] Correct HTTP methods (GET, POST, PUT, DELETE, PATCH)
- [ ] Proper status codes (200, 201, 204, 404, etc.)
- [ ] Dependencies use `Depends()` not manual calls
- [ ] Yield dependencies have proper cleanup
- [ ] Request/Response models use Pydantic
- [ ] HTTPException with status code and detail
- [ ] All route handlers are `async def`
- [ ] No blocking I/O (`requests`, `time.sleep`, `open()`)
- [ ] Background tasks for non-blocking operations
- [ ] No bare `except` in route handlers

## When to Load References

- Reviewing route definitions → routes.md
- Reviewing dependency injection → dependencies.md
- Reviewing Pydantic models/validation → validation.md
- Reviewing async route handlers → async.md

## Review Questions

1. Do all routes have explicit response models and status codes?
2. Are dependencies injected via Depends() with proper cleanup?
3. Do all Pydantic models validate inputs correctly?
4. Are all route handlers async and non-blocking?
