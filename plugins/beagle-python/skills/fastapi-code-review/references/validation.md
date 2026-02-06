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

**Problem**: Invalid data passes through.

```python
# BAD - no validation on age
class UserCreate(BaseModel):
    name: str
    age: int  # Can be negative!

# GOOD - field validation
from pydantic import BaseModel, Field

class UserCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    age: int = Field(..., ge=0, le=150)
    email: EmailStr
```

### 3. Generic HTTPException Messages

**Problem**: Users don't know what's wrong.

```python
# BAD - vague error
@router.get("/users/{user_id}")
async def get_user(user_id: int):
    user = await db.get_user(user_id)
    if not user:
        raise HTTPException(404)  # No detail!
    return user

# GOOD - specific error
@router.get("/users/{user_id}", response_model=UserResponse)
async def get_user(user_id: int):
    user = await db.get_user(user_id)
    if not user:
        raise HTTPException(
            status_code=404,
            detail=f"User {user_id} not found"
        )
    return user
```

### 4. Not Using Pydantic Config

**Problem**: Models accept extra fields, expose internal fields.

```python
# BAD - accepts any extra fields
class UserCreate(BaseModel):
    name: str
    email: str
    # {"name": "Alice", "email": "a@b.com", "is_admin": true} accepted!

# GOOD - strict validation
class UserCreate(BaseModel):
    name: str
    email: EmailStr

    class Config:
        extra = "forbid"  # Reject unknown fields

# GOOD - control ORM exposure
class UserResponse(BaseModel):
    id: int
    name: str
    email: str
    # Don't expose password_hash, created_at, etc.

    class Config:
        from_attributes = True  # Formerly orm_mode
```

### 5. Missing Custom Validators

**Problem**: Business rules not enforced.

```python
# BAD - no validation
class PasswordReset(BaseModel):
    password: str
    confirm_password: str
    # Passwords might not match!

# GOOD - custom validator
from pydantic import BaseModel, model_validator

class PasswordReset(BaseModel):
    password: str = Field(..., min_length=8)
    confirm_password: str

    @model_validator(mode='after')
    def passwords_match(self):
        if self.password != self.confirm_password:
            raise ValueError('Passwords do not match')
        return self
```

### 6. Not Handling 422 Validation Errors

**Problem**: Default 422 responses unclear to clients.

```python
# BAD - default 422 response is verbose and unclear
# (No custom handler)

# GOOD - custom 422 handler
from fastapi import Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(
    request: Request,
    exc: RequestValidationError
):
    errors = []
    for error in exc.errors():
        errors.append({
            "field": ".".join(str(x) for x in error["loc"][1:]),
            "message": error["msg"],
            "type": error["type"]
        })

    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={"detail": errors}
    )
```

### 7. Using Dict Instead of Models

**Problem**: No validation, no type safety, unclear API.

```python
# BAD - dict responses
@router.get("/users/{id}")
async def get_user(id: int) -> dict:
    return {
        "id": id,
        "name": "Alice",
        "extra_field": "oops"  # Inconsistent!
    }

# GOOD - Pydantic response model
class UserResponse(BaseModel):
    id: int
    name: str
    email: str

@router.get("/users/{id}", response_model=UserResponse)
async def get_user(id: int):
    user = await db.get_user(id)
    if not user:
        raise HTTPException(404, detail="User not found")
    return user  # Auto-validates and filters fields
```

### 8. Missing Query Parameter Validation

**Problem**: Invalid query parameters not validated.

```python
# BAD - no validation
@router.get("/users")
async def list_users(page: int = 1, size: int = 10):
    # What if page is 0 or negative?
    # What if size is 10000?
    return await db.get_users(page, size)

# GOOD - validated query params
from fastapi import Query

@router.get("/users", response_model=list[UserResponse])
async def list_users(
    page: int = Query(1, ge=1),
    size: int = Query(10, ge=1, le=100)
):
    return await db.get_users(page, size)
```

## Review Questions

1. Are all request bodies defined as Pydantic models?
2. Do fields have proper validators (min_length, ge, EmailStr, etc.)?
3. Do HTTPExceptions include detailed error messages?
4. Are models configured with `extra = "forbid"` to reject unknown fields?
5. Are custom validators used for business rules?
6. Are query parameters validated with `Query()`?
7. Are response models used instead of plain dicts?
