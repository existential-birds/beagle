# Routes

## Critical Anti-Patterns

### 1. Missing Response Model or Return Type Annotation

**Problem**: Unvalidated responses can leak internal fields and omit OpenAPI schema generation.

```python
# BAD - no response_model or return type
@router.get("/users/{user_id}")
async def get_user(user_id: int):
    return {"id": user_id, "name": "Alice"}

# GOOD - explicit response_model or return-type annotation
@router.get("/users/{user_id}", response_model=UserResponse)
async def get_user(user_id: int):
    return {"id": user_id, "name": "Alice"}

# ALSO GOOD - FastAPI validates & serializes from the return-type annotation
@router.get("/users/{user_id}")
async def get_user(user_id: int) -> UserResponse:
    return UserResponse(id=user_id, name="Alice")
```

### 2. No APIRouter Prefix/Tags

**Problem**: Routes scattered on `app` with duplicated prefixes and ungrouped OpenAPI docs.

```python
# BAD
@app.get("/api/v1/users")
async def list_users(): ...

@app.get("/api/v1/users/{id}")
async def get_user(id: int): ...

# GOOD
router = APIRouter(prefix="/api/v1/users", tags=["users"])

@router.get("")
async def list_users(): ...

@router.get("/{id}")
async def get_user(id: int): ...

app.include_router(router)
```

### 3. Wrong HTTP Methods

**Problem**: Violates HTTP/REST semantics (e.g., `GET` for mutations, `POST` for reads).

```python
# BAD
@router.get("/users/{id}/delete")
async def delete_user(id: int): ...

@router.post("/users/{id}")
async def get_user(id: int): ...

# GOOD
@router.delete("/users/{id}", status_code=204)
async def delete_user(id: int): ...

@router.get("/users/{id}", response_model=UserResponse)
async def get_user(id: int): ...
```

### 4. Missing Status Codes

**Problem**: Returns 200 for resource creation (`201`) or empty deletions (`204`).

```python
# BAD
@router.post("/users")
async def create_user(user: UserCreate):
    return created_user

@router.delete("/users/{id}")
async def delete_user(id: int):
    return {"message": "deleted"}

# GOOD
@router.post("/users", response_model=UserResponse, status_code=201)
async def create_user(user: UserCreate):
    return created_user

@router.delete("/users/{id}", status_code=204)
async def delete_user(id: int) -> None:
    return None
```

### 5. Unhandled Domain Exceptions Returning 500

**Problem**: Raising `ValueError` or `KeyError` without an exception handler yields generic 500 errors.

```python
# BAD
@router.get("/users/{id}")
async def get_user(id: int):
    user = await db.get_user(id)
    if not user:
        raise ValueError("User not found")
    return user

# GOOD - raise HTTPException (or register an app exception handler for domain errors)
from fastapi import HTTPException

@router.get("/users/{id}", response_model=UserResponse)
async def get_user(id: int):
    user = await db.get_user(id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user
```

### 6. Inconsistent Multiple Response Models

**Problem**: Returning incompatible schemas without declaring a union type.

```python
# BAD - undeclared mixed return schemas
@router.get("/users/{id}")
async def get_user(id: int, full: bool = False):
    if full:
        return UserDetailResponse(...)
    return UserSummaryResponse(...)

# GOOD - separate endpoints
@router.get("/users/{id}", response_model=UserSummaryResponse)
async def get_user(id: int):
    return UserSummaryResponse(...)

@router.get("/users/{id}/full", response_model=UserDetailResponse)
async def get_user_full(id: int):
    return UserDetailResponse(...)

# ALTERNATIVE - union response type (Python 3.10+ syntax)
@router.get("/users/{id}")
async def get_user(
    id: int,
    full: bool = False,
) -> UserSummaryResponse | UserDetailResponse:
    if full:
        return UserDetailResponse(...)
    return UserSummaryResponse(...)
```

### 7. Missing Path Parameter Validation

**Problem**: Unconstrained path parameters allow negative or out-of-range values into handlers.

```python
# BAD
@router.get("/users/{user_id}")
async def get_user(user_id: int):
    return await db.get_user(user_id)

# GOOD - Annotated with Path constraint
from typing import Annotated
from fastapi import Path

@router.get("/users/{user_id}", response_model=UserResponse)
async def get_user(user_id: Annotated[int, Path(gt=0)]):
    return await db.get_user(user_id)
```

### 8. Deprecated `@app.on_event` Instead of `lifespan`

**Problem**: `@app.on_event("startup")` / `@app.on_event("shutdown")` is deprecated in FastAPI in favor of the `lifespan` async context manager.

```python
# BAD - deprecated on_event hooks
@app.on_event("startup")
async def startup():
    app.state.pool = await create_pool()

@app.on_event("shutdown")
async def shutdown():
    await app.state.pool.close()

# GOOD - lifespan async context manager
from contextlib import asynccontextmanager
from fastapi import FastAPI

@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.pool = await create_pool()
    try:
        yield
    finally:
        await app.state.pool.close()

app = FastAPI(lifespan=lifespan)
```

## Review Questions

1. Does every route declare an explicit `response_model=` or typed return annotation?
2. Are routes organized with `APIRouter` using prefix and tags?
3. Are HTTP methods and status codes (`201`, `204`) semantically accurate?
4. Are `HTTPException` or custom `@app.exception_handler` hooks used instead of unhandled domain exceptions?
5. Are path parameters validated with `Annotated[..., Path(...)]`?
6. Is `lifespan` used instead of deprecated `on_event`?
