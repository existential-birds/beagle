---
name: fastapi-code-review
description: Reviews FastAPI code for routing patterns, dependency injection, Pydantic v2 validation, and async/sync handler safety. Use when reviewing FastAPI apps, checking APIRouter setup, Depends()/Annotated usage, or response models.
---

# FastAPI Code Review

## Quick Reference

| Issue Type | Reference |
|------------|-----------|
| APIRouter setup, response_model, status codes, lifespan | [references/routes.md](references/routes.md) |
| `Annotated[..., Depends()]`, yield deps, pure ASGI middleware | [references/dependencies.md](references/dependencies.md) |
| Pydantic v2 `ConfigDict`, `HTTPException`, 422 handling | [references/validation.md](references/validation.md) |
| `def` vs `async def`, blocking I/O, `asyncio.to_thread`, background tasks | [references/async.md](references/async.md) |

## Review Checklist

- [ ] `APIRouter` with proper prefix and tags
- [ ] All routes specify `response_model=` or a typed return annotation (`-> UserResponse`) for validation/OpenAPI
- [ ] Correct HTTP methods (`GET`, `POST`, `PUT`, `DELETE`, `PATCH`) and status codes (`201`, `204`, etc.)
- [ ] Dependencies use `Annotated[T, Depends(...)]` (or `Depends(...)`), not manual calls
- [ ] Yield dependencies clean up resources in `finally` (or via `async with`)
- [ ] Request/Response models use Pydantic v2 (`ConfigDict`, `@model_validator`, `@field_validator`)
- [ ] `HTTPException` includes explicit status code and `detail`
- [ ] `async def` handlers contain no blocking I/O (`requests`, `time.sleep`, sync `open()`, sync DB); sync `def` handlers are used for sync I/O (run in AnyIO threadpool)
- [ ] `BackgroundTasks` used for fire-and-forget post-response work
- [ ] App startup/shutdown uses `lifespan` context manager (not deprecated `on_event`)
- [ ] Middleware uses pure ASGI (`__call__(scope, receive, send)`) rather than `BaseHTTPMiddleware` where `contextvars`, streaming, or WebSockets matter

## Valid Patterns (Do NOT Flag)

These are idiomatic FastAPI patterns that may appear problematic but are correct:

- **Pydantic validates request body automatically** — No manual validation needed when using typed Pydantic models as parameters
- **Sync `def` route handlers for sync I/O** — FastAPI runs `def` handlers in an AnyIO worker threadpool so they do not block the event loop
- **`async def` endpoint without `await`** — Valid for non-blocking computations or simple returns
- **Dependency injection via `Depends()`** — Sessions and services come from `Depends()`, with type inferred from the callable if unannotated
- **Response model different from DB model** — Intentional separation between API schemas and persistence models
- **`BackgroundTasks` parameter** — Standard pattern for fire-and-forget post-response operations
- **Direct `request.state` access** — Standard pattern for middleware-injected or lifespan-initialized state
- **`Query`/`Path`/`Body` in `Annotated[...]` or defaults** — FastAPI processes these at runtime
- **Returning `dict` or ORM object from endpoint** — Pydantic validates and serializes automatically when `response_model=` or a return-type annotation is set

## Context-Sensitive Rules

Only flag issues when the context warrants it:

- **Flag missing validation** ONLY IF the field isn't already in a Pydantic model or constrained via `Query`/`Path`/`Body`
- **Flag missing auth** ONLY IF neither the endpoint nor its `APIRouter`/`FastAPI` app applies an auth dependency
- **Flag missing error handling** ONLY IF no `HTTPException` or app exception handler handles the failure case
- **Flag blocking in async** ONLY IF an actually blocking operation (sync network I/O, `time.sleep`, heavy file/CPU work, sync DB driver) runs directly inside an `async def` handler or dependency (not inside a `def` handler)

## Gates (FastAPI-specific)

Run **once per FastAPI-related finding**, after anchoring **`file:line`** for the handler per `review-verification-protocol` ([review-verification-protocol](../review-verification-protocol/SKILL.md)) and **before** the finding ships. If a step's pass condition is not met, **do not** assert the finding as written—gather evidence, withdraw, downgrade severity, or rephrase as a question.

### Gate 1 — Route decorator and response surface

| Step | Action | **Pass condition** |
|------|--------|---------------------|
| 1a | Open the handler's route decorator in the repo (not from memory). | **`file:line`** for `@router.*` / `@app.*` (or the site that registers this handler). |
| 1b | Record HTTP method, `response_model=`, return-type annotation, and `status_code=` on that decorator/signature (or note they are absent). | **Snippet from those lines** or **explicit absent** with the same **`file:line`**. |

### Gate 2 — Blocking I/O in `async def`

| Step | Action | **Pass condition** |
|------|--------|---------------------|
| 2a | Confirm the handler/dependency is `async def` and read its full body. | **`file:line` range** covering the `async def` body. |
| 2b | Name each blocking call inside `async def` (e.g., `requests.`, `open(`, `time.sleep`, sync DB/ORM). Do not flag `def` handlers merely for being sync. | **Each** blocking call has **`file:line`**, or withdraw the finding if **none** after the read. |

### Gate 3 — Depends, validation, auth

| Step | Action | **Pass condition** |
|------|--------|---------------------|
| 3a | List parameters: `Annotated[..., Depends]` / `Depends`, Pydantic models, `Body`/`Query`/`Path`, `Request`/`Response`. | **Names + mechanism** tied to **`file:line`** on the signature. |
| 3b | If claiming missing auth: search the handler file (and its `APIRouter` / `app` registration) for `Depends`, `Security`, `HTTPBearer`, or project auth dependencies. | **Citation** to an existing hook, or **search result**: paths searched + **N matches** (zero is allowed). |
| 3c | If claiming missing validation: confirm the argument is not already a Pydantic model or constrained `Query`/`Path`/`Body`. | **Type/source** with **`file:line`**, or withdraw if validation already applies. |

## FastAPI Framework Behaviors

FastAPI + Pydantic handle many concerns automatically:
- Request validation via Pydantic models and `Annotated` parameters
- Response serialization/filtering via `response_model=` or return-type annotations
- Dependency injection (`Depends`) for cross-cutting concerns
- Exception handling via `@app.exception_handler`

Before flagging "missing" functionality, verify FastAPI isn't handling it.

## When to Load References

- Reviewing route definitions or lifespan → `references/routes.md`
- Reviewing dependency injection or middleware → `references/dependencies.md`
- Reviewing Pydantic v2 models/validation → `references/validation.md`
- Reviewing `async def` vs `def` handlers → `references/async.md`

## Review Questions

1. Do all routes specify explicit response models (via `response_model=` or return-type annotation) and status codes?
2. Are dependencies injected via `Annotated[..., Depends()]` with proper cleanup?
3. Do all Pydantic v2 models use `ConfigDict` and validate inputs properly?
4. Are `async def` route handlers free of blocking I/O (or using `def` / `asyncio.to_thread()` for sync work)?

## Before Submitting Findings

1. For each FastAPI-related finding, complete **Gates (FastAPI-specific)** above.
2. Load and follow `review-verification-protocol` ([review-verification-protocol](../review-verification-protocol/SKILL.md)) before reporting any issue.
