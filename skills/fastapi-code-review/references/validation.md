# Validation

## Critical Anti-Patterns

### 1. Manual Validation Instead of Pydantic

**Problem**: Duplicate validation logic, inconsistent errors.

```python
# BAD - manual validation
@router.post("/users")
async def create_user(request: Request):
    data = await request.json()
    if "email" not in data:
        raise HTTPException(400, "Email required")
    if "@" not in data["email"]:
        raise HTTPException(400, "Invalid email")
    return await db.create_user(data)

# GOOD - Pydantic validation
from pydantic import BaseModel, EmailStr

class UserCreate(BaseModel):
    email: EmailStr
    name: str
    age: int | None = None

@router.post("/users", response_model=UserResponse, status_code=201)
async def create_user(user: UserCreate):
    return await db.create_user(user)
```

### 2. Missing Field Validators

**Problem**: Unconstrained fields let invalid values (negative age, empty strings) pass through.

```python
# BAD - no validation on age
class UserCreate(BaseModel):
    name: str
    age: int

# GOOD - field constraints
from pydantic import BaseModel, EmailStr, Field

class UserCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    age: int = Field(..., ge=0, le=150)
    email: EmailStr
```

### 3. Generic HTTPException Messages

**Problem**: Omitting `detail` leaves clients without actionable error context.

```python
# BAD - vague error
@router.get("/users/{user_id}")
async def get_user(user_id: int):
    user = await db.get_user(user_id)
    if not user:
        raise HTTPException(404)
    return user

# GOOD - specific error
@router.get("/users/{user_id}", response_model=UserResponse)
async def get_user(user_id: int):
    user = await db.get_user(user_id)
    if not user:
        raise HTTPException(
            status_code=404,
            detail=f"User {user_id} not found",
        )
    return user
```

### 4. Using Deprecated Pydantic v1 `Config` Classes Instead of `ConfigDict`

**Problem**: Inner Pydantic v1 `Config` classes are deprecated in Pydantic v2 (`PydanticDeprecatedSince20`, removed in v3), and omitting `extra="forbid"` / `from_attributes=True` can accept unexpected payload keys or fail on ORM models.

```python
# BAD - accepts unknown fields (or uses deprecated Pydantic v1 Config class)
class UserCreate(BaseModel):
    name: str
    email: str

# GOOD - Pydantic v2 ConfigDict
from pydantic import BaseModel, ConfigDict, EmailStr

class UserCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str
    email: EmailStr

class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    email: str
```

### 5. Missing Custom Validators

**Problem**: Cross-field business rules not enforced at schema boundaries.

```python
# BAD - passwords might not match
class PasswordReset(BaseModel):
    password: str
    confirm_password: str

# GOOD - Pydantic v2 model_validator
from pydantic import BaseModel, Field, model_validator

class PasswordReset(BaseModel):
    password: str = Field(..., min_length=8)
    confirm_password: str

    @model_validator(mode="after")
    def passwords_match(self):
        if self.password != self.confirm_password:
            raise ValueError("Passwords do not match")
        return self
```

### 6. Customizing 422 Validation Error Responses

**Problem**: Returning non-standard formats or using deprecated `HTTP_422_UNPROCESSABLE_ENTITY`.

```python
# GOOD - custom 422 handler using HTTP_422_UNPROCESSABLE_CONTENT (RFC 9110)
from fastapi import Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(
    request: Request,
    exc: RequestValidationError,
):
    errors = [
        {
            "field": ".".join(str(x) for x in error["loc"][1:]),
            "message": error["msg"],
            "type": error["type"],
        }
        for error in exc.errors()
    ]

    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
        content={"detail": errors},
    )
```

*(Note: `status.HTTP_422_UNPROCESSABLE_ENTITY` is deprecated in Starlette/FastAPI in favor of `status.HTTP_422_UNPROCESSABLE_CONTENT`.)*

### 7. Using `dict` Instead of Pydantic Response Models

**Problem**: Unvalidated `dict` responses lack type safety and can leak extra keys.

```python
# BAD - untyped dict response
@router.get("/users/{id}")
async def get_user(id: int) -> dict:
    return {"id": id, "name": "Alice", "secret": "oops"}

# GOOD - Pydantic response model (via response_model= or -> UserResponse)
class UserResponse(BaseModel):
    id: int
    name: str
    email: str

@router.get("/users/{id}")
async def get_user(id: int) -> UserResponse:
    user = await db.get_user(id)
    if not user:
        raise HTTPException(404, detail="User not found")
    return user
```

### 8. Missing Query Parameter Validation

**Problem**: Unconstrained pagination/filter query parameters allow negative offsets or huge limits.

```python
# BAD - no validation
@router.get("/users")
async def list_users(page: int = 1, size: int = 10):
    return await db.get_users(page, size)

# GOOD - Annotated with Query constraints
from typing import Annotated
from fastapi import Query

@router.get("/users", response_model=list[UserResponse])
async def list_users(
    page: Annotated[int, Query(ge=1)] = 1,
    size: Annotated[int, Query(ge=1, le=100)] = 10,
):
    return await db.get_users(page, size)
```

## Review Questions

1. Are request bodies defined as Pydantic v2 models with `ConfigDict`?
2. Do fields have appropriate `Field(...)` constraints (`min_length`, `ge`, `EmailStr`)?
3. Do `HTTPException`s include informative `detail` messages?
4. Are cross-field rules checked with `@model_validator(mode="after")`?
5. Are query parameters validated with `Annotated[..., Query(...)]`?
6. Are Pydantic response models (or return-type annotations) used instead of plain `dict`?
