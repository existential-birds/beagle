# Routes

## Critical Anti-Patterns

### 1. Missing response_model

**Problem**: No type safety, documentation unclear, response not validated.

```python
# BAD
@router.get("/users/{user_id}")
async def get_user(user_id: int):
    return {"id": user_id, "name": "Alice"}

# GOOD
@router.get("/users/{user_id}", response_model=UserResponse)
async def get_user(user_id: int):
    return {"id": user_id, "name": "Alice"}
```

### 2. No APIRouter Prefix/Tags

**Problem**: Routes not organized, duplicated path prefixes, unclear docs.

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

**Problem**: Violates REST conventions, confusing semantics.

```python
# BAD - using GET for mutations
@router.get("/users/{id}/delete")
async def delete_user(id: int): ...

# BAD - using POST for retrieval
@router.post("/users/{id}")
async def get_user(id: int): ...

# GOOD
@router.delete("/users/{id}", status_code=204)
async def delete_user(id: int): ...

@router.get("/users/{id}", response_model=UserResponse)
async def get_user(id: int): ...
```

### 4. Missing Status Codes

**Problem**: Always returns 200, even for creates/deletes.

```python
# BAD - creates should return 201
@router.post("/users")
async def create_user(user: UserCreate):
    return created_user

# BAD - deletes should return 204
@router.delete("/users/{id}")
async def delete_user(id: int):
    return {"message": "deleted"}

# GOOD
@router.post("/users", response_model=UserResponse, status_code=201)
async def create_user(user: UserCreate):
    return created_user

@router.delete("/users/{id}", status_code=204)
async def delete_user(id: int):
    # 204 returns no content
    return None
```

### 5. Direct Exception Raising

**Problem**: Returns generic 500 errors instead of proper HTTP status codes.

```python
# BAD
@router.get("/users/{id}")
async def get_user(id: int):
    user = await db.get_user(id)
    if not user:
        raise ValueError("User not found")
    return user

# GOOD
from fastapi import HTTPException

@router.get("/users/{id}", response_model=UserResponse)
async def get_user(id: int):
    user = await db.get_user(id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user
```

### 6. Multiple Response Models

**Problem**: Same endpoint returns different schemas.

```python
# BAD
@router.get("/users/{id}")
async def get_user(id: int, full: bool = False):
    if full:
        return UserDetailResponse(...)
    return UserSummaryResponse(...)

# GOOD - use separate endpoints
@router.get("/users/{id}", response_model=UserSummaryResponse)
async def get_user(id: int):
    return UserSummaryResponse(...)

@router.get("/users/{id}/full", response_model=UserDetailResponse)
async def get_user_full(id: int):
    return UserDetailResponse(...)

# ALTERNATIVE - use response_model with Union
from typing import Union

@router.get("/users/{id}", response_model=Union[UserSummaryResponse, UserDetailResponse])
async def get_user(id: int, full: bool = False):
    if full:
        return UserDetailResponse(...)
    return UserSummaryResponse(...)
```

### 7. Path Parameter Validation

**Problem**: No validation on path parameters.

```python
# BAD
@router.get("/users/{user_id}")
async def get_user(user_id: int):
    # What if user_id is negative or zero?
    return await db.get_user(user_id)

# GOOD
from fastapi import Path

@router.get("/users/{user_id}", response_model=UserResponse)
async def get_user(user_id: int = Path(..., gt=0)):
    return await db.get_user(user_id)
```

## Review Questions

1. Does every route have an explicit `response_model`?
2. Are routes organized with APIRouter using prefix and tags?
3. Are HTTP methods semantically correct (GET for read, POST for create, etc.)?
4. Do create operations return 201? Do deletes return 204?
5. Are HTTPExceptions used instead of generic exceptions?
6. Are path parameters validated?
