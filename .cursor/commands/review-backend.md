# Backend Code Review

Comprehensive Python/FastAPI backend code review with optional parallel agents.

## Arguments

- `--parallel`: Spawn specialized subagents per technology area
- Path: Target directory (default: current working directory)

## Step 1: Identify Changed Files

```bash
git diff --name-only $(git merge-base HEAD main)..HEAD | grep -E '\.py$'
```

## Step 2: Detect Technologies

```bash
# Detect Pydantic-AI
grep -r "pydantic_ai\|@agent\.tool\|RunContext" --include="*.py" -l | head -3

# Detect SQLAlchemy
grep -r "from sqlalchemy\|Session\|relationship" --include="*.py" -l | head -3

# Detect Postgres-specific
grep -r "psycopg\|asyncpg\|JSONB\|GIN" --include="*.py" -l | head -3

# Check for test files
git diff --name-only $(git merge-base HEAD main)..HEAD | grep -E 'test.*\.py$'
```

## Step 3: Apply Technology-Specific Reviews

Review code using the technology-specific guidelines below based on what was detected:

- **Python**: Always apply Python code review guidelines
- **FastAPI**: Always apply FastAPI code review guidelines
- **Tests**: If test files detected, apply pytest guidelines
- **Pydantic-AI**: If detected, apply Pydantic-AI pitfalls guide
- **SQLAlchemy**: If detected, apply SQLAlchemy guidelines
- **PostgreSQL**: If detected, apply PostgreSQL guidelines

## Step 4: Review Process

**Sequential (default):**
1. Review Python quality issues first
2. Review FastAPI patterns
3. Review detected technology areas
4. Consolidate findings

**Parallel (--parallel flag):**
1. Detect all technologies upfront
2. Spawn one subagent per technology area with `Task` tool
3. Each agent reviews its domain
4. Wait for all agents
5. Consolidate findings

## Output Format

```markdown
## Review Summary

[1-2 sentence overview of findings]

## Issues

### Critical (Blocking)

1. [FILE:LINE] ISSUE_TITLE
   - Issue: Description of what's wrong
   - Why: Why this matters (bug, type safety, security)
   - Fix: Specific recommended fix

### Major (Should Fix)

2. [FILE:LINE] ISSUE_TITLE
   - Issue: ...
   - Why: ...
   - Fix: ...

### Minor (Nice to Have)

N. [FILE:LINE] ISSUE_TITLE
   - Issue: ...
   - Why: ...
   - Fix: ...

## Good Patterns

- [FILE:LINE] Pattern description (preserve this)

## Verdict

Ready: Yes | No | With fixes 1-N
Rationale: [1-2 sentences]
```

## Post-Fix Verification

After fixes are applied, run:

```bash
ruff check .
mypy .
pytest
```

All checks must pass before approval.

## Rules

- Number every issue sequentially (1, 2, 3...)
- Include FILE:LINE for each issue
- Separate Issue/Why/Fix clearly
- Categorize by actual severity
- Run verification after fixes

---

# Technology-Specific Review Guidelines

## Python Code Review

### Quick Reference

| Issue Type | Review Focus |
|------------|--------------|
| Missing/wrong type hints, Any usage | Type safety |
| Blocking calls in async, missing await | Async patterns |
| Bare except, missing context, logging | Error handling |
| Mutable defaults, print statements | Common mistakes |

### Review Checklist

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

### Review Questions

1. Are all function signatures fully typed?
2. Are async functions truly non-blocking?
3. Do exceptions include meaningful context?
4. Are there any mutable default arguments?

---

## Type Safety

### Critical Anti-Patterns

#### 1. Missing Return Type

**Problem**: Callers don't know what to expect.

```python
# BAD
def get_user(id: int):
    return User.query.get(id)

# GOOD
def get_user(id: int) -> User | None:
    return User.query.get(id)
```

#### 2. Using Any Without Justification

**Problem**: Defeats the purpose of type checking.

```python
# BAD
def process(data: Any) -> Any:
    return data

# GOOD - with justification
def process(data: Any) -> dict:  # Any: accepts JSON from external API
    return json.loads(data)

# BETTER - use proper types
def process(data: str | bytes) -> dict:
    return json.loads(data)
```

#### 3. Optional vs Union Syntax

**Problem**: Inconsistent syntax, less readable.

```python
# OLD (pre-3.10)
from typing import Optional, Union
def find(id: int) -> Optional[User]: ...
def parse(val: Union[str, int]) -> str: ...

# GOOD (3.10+)
def find(id: int) -> User | None: ...
def parse(val: str | int) -> str: ...
```

#### 4. Missing Generic Types

**Problem**: Loses type information in collections.

```python
# BAD
def get_items() -> list:
    return [Item(...)]

# GOOD
def get_items() -> list[Item]:
    return [Item(...)]

# BAD
def get_config() -> dict:
    return {"key": "value"}

# GOOD
def get_config() -> dict[str, str]:
    return {"key": "value"}
```

#### 5. TypedDict for Structured Dicts

**Problem**: Plain dict loses key/value type information.

```python
# BAD
def get_user_data() -> dict:
    return {"name": "Alice", "age": 30}

# GOOD
from typing import TypedDict

class UserData(TypedDict):
    name: str
    age: int

def get_user_data() -> UserData:
    return {"name": "Alice", "age": 30}
```

---

## Async Patterns

### Critical Anti-Patterns

#### 1. Blocking Calls in Async Functions

**Problem**: Blocks the event loop, defeats async benefits.

```python
# BAD - blocks event loop
async def fetch_data():
    response = requests.get(url)  # BLOCKING!
    time.sleep(1)  # BLOCKING!
    return response.json()

# GOOD - non-blocking
async def fetch_data():
    async with httpx.AsyncClient() as client:
        response = await client.get(url)
    await asyncio.sleep(1)
    return response.json()
```

#### 2. Missing await on Coroutines

**Problem**: Coroutine never executes.

```python
# BAD - coroutine created but never awaited
async def process():
    fetch_data()  # Returns coroutine, doesn't execute!

# GOOD
async def process():
    await fetch_data()
```

#### 3. Sequential Instead of Concurrent

**Problem**: Misses parallelization opportunity.

```python
# BAD - sequential (slow)
async def get_all():
    user = await get_user()
    posts = await get_posts()
    comments = await get_comments()
    return user, posts, comments

# GOOD - concurrent (fast)
async def get_all():
    user, posts, comments = await asyncio.gather(
        get_user(),
        get_posts(),
        get_comments()
    )
    return user, posts, comments
```

#### 4. Missing async with for Async Context Managers

**Problem**: Resource not properly managed.

```python
# BAD
async def query():
    session = aiosqlite.connect(db)  # Not entered!
    return await session.execute(sql)

# GOOD
async def query():
    async with aiosqlite.connect(db) as session:
        return await session.execute(sql)
```

#### 5. Sync File I/O in Async Context

**Problem**: File operations block event loop.

```python
# BAD - blocks event loop
async def read_config():
    with open("config.json") as f:
        return json.load(f)

# GOOD - use aiofiles
import aiofiles

async def read_config():
    async with aiofiles.open("config.json") as f:
        content = await f.read()
        return json.loads(content)

# ACCEPTABLE - for small files, run in executor
async def read_config():
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, load_config_sync)
```

---

## Error Handling

### Critical Anti-Patterns

#### 1. Bare Except Clause

**Problem**: Catches everything including KeyboardInterrupt, SystemExit.

```python
# BAD
try:
    process()
except:
    pass

# GOOD - specific exception
try:
    process()
except ValueError as e:
    logger.error(f"Invalid value: {e}")
    raise

# ACCEPTABLE - if you must catch all
try:
    process()
except Exception as e:  # Still allows KeyboardInterrupt
    logger.error(f"Unexpected error: {e}")
    raise
```

#### 2. Swallowing Exceptions

**Problem**: Hides errors, makes debugging impossible.

```python
# BAD
try:
    result = risky_operation()
except Exception:
    pass  # Error silently ignored!

# GOOD - log and handle
try:
    result = risky_operation()
except OperationError as e:
    logger.warning(f"Operation failed: {e}")
    result = default_value
```

#### 3. Losing Exception Context

**Problem**: Original stack trace lost.

```python
# BAD - loses original traceback
try:
    parse_config()
except ValueError:
    raise ConfigError("Invalid config")

# GOOD - preserves chain
try:
    parse_config()
except ValueError as e:
    raise ConfigError("Invalid config") from e
```

#### 4. Missing Context in Error Messages

**Problem**: Can't diagnose issue from logs.

```python
# BAD
except KeyError:
    raise ValueError("Missing key")

# GOOD - include context
except KeyError as e:
    raise ValueError(f"Missing required key: {e.args[0]}") from e
```

#### 5. Not Logging Before Re-raising

**Problem**: Exception might be caught elsewhere without logging.

```python
# BAD - no record if caught upstream
try:
    process(item)
except ProcessError:
    raise

# GOOD - log before re-raising
try:
    process(item)
except ProcessError as e:
    logger.error(f"Failed to process item {item.id}: {e}")
    raise
```

### Logging Best Practices

```python
from loguru import logger

# BAD
print(f"Processing {item}")
print(f"Error: {e}")

# GOOD
logger.debug(f"Processing item {item.id}")
logger.info(f"Completed batch of {count} items")
logger.warning(f"Retry {attempt}/3 for {operation}")
logger.error(f"Failed to process {item.id}: {e}")

# With exception info
logger.exception(f"Unexpected error processing {item.id}")
```

---

## Common Mistakes

### Critical Anti-Patterns

#### 1. Mutable Default Arguments

**Problem**: Default value is shared across all calls.

```python
# BAD - same list reused!
def add_item(item, items=[]):
    items.append(item)
    return items

add_item("a")  # ["a"]
add_item("b")  # ["a", "b"] - unexpected!

# GOOD
def add_item(item, items=None):
    if items is None:
        items = []
    items.append(item)
    return items

# BETTER - using dataclass
from dataclasses import dataclass, field

@dataclass
class Container:
    items: list = field(default_factory=list)
```

#### 2. Using print() for Logging

**Problem**: No log levels, no timestamps, hard to filter.

```python
# BAD
print(f"Processing {item}")
print(f"Error: {e}")

# GOOD
from loguru import logger

logger.info(f"Processing {item}")
logger.error(f"Error: {e}")
```

#### 3. String Formatting Inconsistency

**Problem**: Mixing formats reduces readability.

```python
# BAD - mixed formats
msg = "Hello %s" % name
msg = "Hello {}".format(name)
msg = f"Hello {name}"

# GOOD - f-strings consistently
msg = f"Hello {name}"
total = f"Count: {count:,}"  # with formatting
path = f"{base}/{sub}/{file}"
```

#### 4. Unused Variables

**Problem**: Dead code, confusing to readers.

```python
# BAD
result = process()  # never used

# GOOD - use underscore for intentionally ignored
_, second, _ = get_triple()

# Or just don't assign
process()  # if result not needed
```

#### 5. Import Order

**Problem**: Hard to scan, may cause issues.

```python
# BAD - random order
from myapp.utils import helper
import os
from typing import Optional
import sys
from myapp.models import User

# GOOD - standard order
import os
import sys
from typing import Optional

from myapp.models import User
from myapp.utils import helper
```

#### 6. Magic Numbers

**Problem**: Unclear intent, hard to maintain.

```python
# BAD
if len(items) > 100:
    paginate()
time.sleep(3600)

# GOOD
MAX_PAGE_SIZE = 100
CACHE_TTL_SECONDS = 3600

if len(items) > MAX_PAGE_SIZE:
    paginate()
time.sleep(CACHE_TTL_SECONDS)
```

#### 7. Nested Conditionals

**Problem**: Hard to read and maintain.

```python
# BAD
def process(user):
    if user:
        if user.active:
            if user.verified:
                return do_work(user)
    return None

# GOOD - early returns
def process(user):
    if not user:
        return None
    if not user.active:
        return None
    if not user.verified:
        return None
    return do_work(user)
```

---

## FastAPI Code Review

### Quick Reference

| Issue Type | Review Focus |
|------------|--------------|
| APIRouter setup, response_model, status codes | Routes |
| Depends(), yield deps, cleanup, shared deps | Dependencies |
| Pydantic models, HTTPException, 422 handling | Validation |
| Async handlers, blocking I/O, background tasks | Async |

### Review Checklist

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

### Review Questions

1. Do all routes have explicit response models and status codes?
2. Are dependencies injected via Depends() with proper cleanup?
3. Do all Pydantic models validate inputs correctly?
4. Are all route handlers async and non-blocking?

---

## Routes

### Critical Anti-Patterns

#### 1. Missing response_model

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

#### 2. No APIRouter Prefix/Tags

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

#### 3. Wrong HTTP Methods

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

#### 4. Missing Status Codes

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

#### 5. Direct Exception Raising

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

#### 6. Multiple Response Models

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

#### 7. Path Parameter Validation

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

---

## Dependencies

### Critical Anti-Patterns

#### 1. Manual Dependency Calls

**Problem**: Bypasses FastAPI's injection system, no automatic cleanup.

```python
# BAD - manually calling dependency
async def get_db_session():
    session = SessionLocal()
    return session

@router.get("/users")
async def list_users():
    db = await get_db_session()  # Manual call!
    users = await db.query(User).all()
    return users

# GOOD - using Depends()
from fastapi import Depends

async def get_db_session():
    session = SessionLocal()
    try:
        yield session
    finally:
        await session.close()

@router.get("/users", response_model=list[UserResponse])
async def list_users(db: Session = Depends(get_db_session)):
    users = await db.query(User).all()
    return users
```

#### 2. Missing Cleanup in Yield Dependencies

**Problem**: Resources leak, connections not closed.

```python
# BAD - no cleanup
async def get_db():
    db = DatabaseConnection()
    yield db
    # Connection never closed!

# GOOD - proper cleanup
async def get_db():
    db = DatabaseConnection()
    try:
        yield db
    finally:
        await db.close()
```

#### 3. Shared State Without Proper Scope

**Problem**: Dependencies create shared mutable state across requests.

```python
# BAD - shared mutable state
cache = {}  # Shared across all requests!

async def get_cache():
    return cache

@router.get("/items/{id}")
async def get_item(id: int, cache: dict = Depends(get_cache)):
    # Multiple requests share same dict - race conditions!
    if id not in cache:
        cache[id] = await fetch_item(id)
    return cache[id]

# GOOD - request-scoped state
from contextvars import ContextVar

request_cache: ContextVar[dict] = ContextVar('request_cache')

async def get_cache():
    cache = {}
    request_cache.set(cache)
    return cache

# BETTER - use proper caching library
from functools import lru_cache

@lru_cache(maxsize=128)
async def get_item_cached(id: int):
    return await fetch_item(id)
```

#### 4. Nested Depends Not Utilized

**Problem**: Duplicate code, no composition of dependencies.

```python
# BAD - duplicated logic
async def get_current_user(token: str):
    # Verify token, decode, fetch user
    return user

async def get_admin_user(token: str):
    # Same verification, then check admin
    user = await verify_and_decode(token)
    if not user.is_admin:
        raise HTTPException(403)
    return user

# GOOD - compose dependencies
async def get_current_user(token: str = Depends(oauth2_scheme)):
    user = await verify_token(token)
    if not user:
        raise HTTPException(401, detail="Invalid token")
    return user

async def get_admin_user(user: User = Depends(get_current_user)):
    if not user.is_admin:
        raise HTTPException(403, detail="Admin required")
    return user
```

#### 5. Dependencies with Side Effects

**Problem**: Dependencies modify state instead of providing resources.

```python
# BAD - dependency has side effects
async def log_request(request: Request):
    # Side effect: writes to database
    await db.log_request(request)
    return None

@router.get("/users")
async def list_users(_: None = Depends(log_request)):
    return users

# GOOD - use middleware for cross-cutting concerns
from starlette.middleware.base import BaseHTTPMiddleware

class LoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        await db.log_request(request)
        response = await call_next(request)
        return response

app.add_middleware(LoggingMiddleware)

# OR - dependency returns resource
async def get_logger(request: Request):
    logger = RequestLogger(request)
    return logger

@router.get("/users")
async def list_users(logger: RequestLogger = Depends(get_logger)):
    logger.info("Listing users")
    return users
```

#### 6. Class-Based Dependencies Without Caching

**Problem**: New instance created unnecessarily.

```python
# BAD - new instance every time
class DatabaseService:
    def __init__(self):
        self.connection_pool = create_pool()  # Expensive!

@router.get("/users")
async def list_users(db: DatabaseService = Depends(DatabaseService)):
    return await db.query_users()

# GOOD - use singleton or app state
class DatabaseService:
    def __init__(self, pool):
        self.pool = pool

async def get_db_service(
    pool = Depends(lambda: app.state.db_pool)
) -> DatabaseService:
    return DatabaseService(pool)

# OR - use dependency with cache
async def get_db_service() -> DatabaseService:
    return app.state.db_service

@router.get("/users")
async def list_users(db: DatabaseService = Depends(get_db_service)):
    return await db.query_users()
```

#### 7. Security Dependencies Not Applied Globally

**Problem**: Easy to forget security on new routes.

```python
# BAD - must remember to add auth to every route
@router.get("/users", dependencies=[Depends(verify_token)])
async def list_users(): ...

@router.get("/posts")  # Forgot auth!
async def list_posts(): ...

# GOOD - apply at router level
router = APIRouter(
    prefix="/api/v1",
    dependencies=[Depends(verify_token)]
)

@router.get("/users")
async def list_users(): ...

@router.get("/posts")
async def list_posts(): ...
```

---

## Validation

### Critical Anti-Patterns

#### 1. Manual Validation Instead of Pydantic

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

#### 2. Missing Field Validators

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

#### 3. Generic HTTPException Messages

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

#### 4. Not Using Pydantic Config

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

#### 5. Missing Custom Validators

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

#### 6. Not Handling 422 Validation Errors

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

#### 7. Using Dict Instead of Models

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

#### 8. Missing Query Parameter Validation

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

---

## Async

### Critical Anti-Patterns

#### 1. Blocking I/O in Async Handlers

**Problem**: Blocks the event loop, prevents concurrent request handling.

```python
# BAD - blocking HTTP client
import requests

@router.get("/external")
async def fetch_external():
    response = requests.get("https://api.example.com")  # BLOCKS!
    return response.json()

# GOOD - async HTTP client
import httpx

@router.get("/external")
async def fetch_external():
    async with httpx.AsyncClient() as client:
        response = await client.get("https://api.example.com")
    return response.json()
```

#### 2. Blocking Database Calls

**Problem**: Synchronous DB driver blocks event loop.

```python
# BAD - sync SQLAlchemy
from sqlalchemy.orm import Session

@router.get("/users", response_model=list[UserResponse])
async def list_users(db: Session = Depends(get_db)):
    users = db.query(User).all()  # BLOCKS!
    return users

# GOOD - async SQLAlchemy
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

@router.get("/users", response_model=list[UserResponse])
async def list_users(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User))
    users = result.scalars().all()
    return users
```

#### 3. Using time.sleep Instead of asyncio.sleep

**Problem**: Blocks event loop during sleep.

```python
# BAD - blocking sleep
import time

@router.post("/jobs")
async def create_job():
    time.sleep(5)  # BLOCKS for 5 seconds!
    return {"status": "done"}

# GOOD - async sleep
import asyncio

@router.post("/jobs")
async def create_job():
    await asyncio.sleep(5)  # Yields control
    return {"status": "done"}

# BETTER - use background tasks for long operations
from fastapi import BackgroundTasks

async def process_job():
    await asyncio.sleep(5)
    # Do actual work

@router.post("/jobs")
async def create_job(background_tasks: BackgroundTasks):
    background_tasks.add_task(process_job)
    return {"status": "processing"}
```

#### 4. Sync File I/O in Async Handlers

**Problem**: File operations block event loop.

```python
# BAD - blocking file I/O
@router.get("/config")
async def get_config():
    with open("config.json") as f:  # BLOCKS!
        return json.load(f)

# GOOD - async file I/O
import aiofiles

@router.get("/config")
async def get_config():
    async with aiofiles.open("config.json") as f:
        content = await f.read()
    return json.loads(content)

# ACCEPTABLE - small files in executor
import asyncio

def read_config_sync():
    with open("config.json") as f:
        return json.load(f)

@router.get("/config")
async def get_config():
    loop = asyncio.get_event_loop()
    config = await loop.run_in_executor(None, read_config_sync)
    return config
```

#### 5. Not Using Background Tasks

**Problem**: Long operations block response, timeout issues.

```python
# BAD - blocks response
@router.post("/emails")
async def send_email(email: EmailCreate):
    await send_email_via_smtp(email)  # Takes 5 seconds!
    await log_email_sent(email)  # Takes 1 second!
    return {"status": "sent"}

# GOOD - use background tasks
from fastapi import BackgroundTasks

async def send_email_background(email: EmailCreate):
    await send_email_via_smtp(email)
    await log_email_sent(email)

@router.post("/emails", status_code=202)
async def send_email(
    email: EmailCreate,
    background_tasks: BackgroundTasks
):
    background_tasks.add_task(send_email_background, email)
    return {"status": "queued"}
```

#### 6. Sequential Instead of Concurrent Calls

**Problem**: Misses parallelization opportunity.

```python
# BAD - sequential (slow)
@router.get("/dashboard")
async def get_dashboard(user_id: int):
    user = await get_user(user_id)
    posts = await get_user_posts(user_id)
    stats = await get_user_stats(user_id)
    return {"user": user, "posts": posts, "stats": stats}

# GOOD - concurrent (fast)
import asyncio

@router.get("/dashboard")
async def get_dashboard(user_id: int):
    user, posts, stats = await asyncio.gather(
        get_user(user_id),
        get_user_posts(user_id),
        get_user_stats(user_id)
    )
    return {"user": user, "posts": posts, "stats": stats}
```

#### 7. Mixing Sync and Async Route Handlers

**Problem**: Inconsistent patterns, sync handlers block thread pool.

```python
# BAD - mixing sync and async
@router.get("/sync-route")
def sync_handler():  # Blocks thread pool
    return db.query(User).all()

@router.get("/async-route")
async def async_handler():
    return await db.query_async(User)

# GOOD - all async
@router.get("/route1")
async def handler1():
    result = await db.execute(select(User))
    return result.scalars().all()

@router.get("/route2")
async def handler2():
    result = await db.execute(select(Post))
    return result.scalars().all()
```

#### 8. Not Awaiting Coroutines

**Problem**: Coroutine never executes, silent failures.

```python
# BAD - missing await
@router.post("/users")
async def create_user(user: UserCreate):
    db.create_user(user)  # Returns coroutine, doesn't execute!
    return {"status": "created"}  # User not actually created!

# GOOD - await coroutines
@router.post("/users", response_model=UserResponse, status_code=201)
async def create_user(user: UserCreate):
    created_user = await db.create_user(user)
    return created_user
```

#### 9. Blocking External API Calls

**Problem**: Synchronous requests library blocks event loop.

```python
# BAD - requests blocks
import requests

@router.get("/weather")
async def get_weather(city: str):
    response = requests.get(f"https://api.weather.com/{city}")  # BLOCKS!
    return response.json()

# GOOD - httpx async
import httpx

@router.get("/weather")
async def get_weather(city: str):
    async with httpx.AsyncClient() as client:
        response = await client.get(f"https://api.weather.com/{city}")
    return response.json()

# GOOD - with timeout
@router.get("/weather")
async def get_weather(city: str):
    async with httpx.AsyncClient(timeout=5.0) as client:
        try:
            response = await client.get(f"https://api.weather.com/{city}")
            return response.json()
        except httpx.TimeoutException:
            raise HTTPException(504, detail="Weather API timeout")
```

---

## Pytest Code Review

### Quick Reference

| Issue Type | Review Focus |
|------------|--------------|
| async def test_*, AsyncMock, await patterns | Async testing |
| conftest.py, factory fixtures, scope, cleanup | Fixtures |
| @pytest.mark.parametrize, DRY patterns | Parametrize |
| AsyncMock tracking, patch patterns, when to mock | Mocking |

### Review Checklist

- [ ] Test functions are `async def test_*` for async code under test
- [ ] AsyncMock used for async dependencies, not Mock
- [ ] All async mocks and coroutines are awaited
- [ ] Fixtures in conftest.py for shared setup
- [ ] Fixture scope appropriate (function, class, module, session)
- [ ] Yield fixtures have proper cleanup in finally block
- [ ] @pytest.mark.parametrize for similar test cases
- [ ] No duplicated test logic across multiple test functions
- [ ] Mocks track calls properly (assert_called_once_with)
- [ ] patch() targets correct location (where used, not defined)
- [ ] No mocking of internals that should be tested
- [ ] Test isolation (no shared mutable state between tests)

### Review Questions

1. Are all async functions tested with async def test_*?
2. Are fixtures properly scoped with appropriate cleanup?
3. Can similar test cases be parametrized to reduce duplication?
4. Are mocks tracking calls and used at the right locations?

---

*Note: Detailed pytest anti-patterns for async testing, fixtures, parametrize, and mocking are extensive. Apply these guidelines when reviewing test files.*

---

## SQLAlchemy Code Review

### Quick Reference

| Issue Type | Review Focus |
|------------|--------------|
| Session lifecycle, context managers, async sessions | Sessions |
| relationship(), lazy loading, N+1, joinedload | Relationships |
| select() vs query(), ORM overhead, bulk ops | Queries |
| Alembic patterns, reversible migrations, data migrations | Migrations |

### Review Checklist

- [ ] Sessions use context managers (`with`, `async with`)
- [ ] No session sharing across requests or threads
- [ ] Sessions closed/cleaned up properly
- [ ] `relationship()` uses appropriate `lazy` strategy
- [ ] Explicit `joinedload`/`selectinload` to avoid N+1
- [ ] No lazy loading in loops (N+1 queries)
- [ ] Using SQLAlchemy 2.0 `select()` syntax, not legacy `query()`
- [ ] Bulk operations use bulk_insert/bulk_update, not ORM loops
- [ ] Async sessions use proper async context managers
- [ ] Migrations are reversible with `downgrade()`
- [ ] Data migrations use `op.execute()` not ORM models
- [ ] Migration dependencies properly ordered

### Review Questions

1. Are all sessions properly managed with context managers?
2. Are relationships configured to avoid N+1 queries?
3. Are queries using SQLAlchemy 2.0 `select()` syntax?
4. Are all migrations reversible and properly tested?

---

*Note: Detailed SQLAlchemy anti-patterns for sessions, relationships, queries, and migrations are extensive. Apply these guidelines when reviewing database code.*

---

## PostgreSQL Code Review

### Quick Reference

| Issue Type | Review Focus |
|------------|--------------|
| Missing indexes, wrong index type, query performance | Indexes |
| JSONB queries, operators, GIN indexes | JSONB |
| Connection leaks, pool configuration, timeouts | Connections |
| Isolation levels, deadlocks, advisory locks | Transactions |

### Review Checklist

- [ ] WHERE/JOIN columns have appropriate indexes
- [ ] Composite indexes match query patterns (column order matters)
- [ ] JSONB columns use GIN indexes when queried
- [ ] Using proper JSONB operators (`->`, `->>`, `@>`, `?`)
- [ ] Connection pool configured with appropriate limits
- [ ] Connections properly released (context managers, try/finally)
- [ ] Appropriate transaction isolation level for use case
- [ ] No long-running transactions holding locks
- [ ] Advisory locks used for application-level coordination
- [ ] Queries use parameterized statements (no SQL injection)

### Review Questions

1. Will this query use an index or perform a sequential scan?
2. Are JSONB operations using appropriate operators and indexes?
3. Are database connections properly managed and released?
4. Is the transaction isolation level appropriate for this operation?
5. Could this cause deadlocks or long-running locks?

---

*Note: Detailed PostgreSQL anti-patterns for indexes, JSONB, connections, and transactions are extensive. Apply these guidelines when reviewing database code.*

---

## Pydantic-AI Common Pitfalls

### Tool Decorator Errors

#### Wrong: RunContext in tool_plain

```python
# ERROR: RunContext not allowed in tool_plain
@agent.tool_plain
async def bad_tool(ctx: RunContext[MyDeps]) -> str:
    return "oops"
# UserError: RunContext annotations can only be used with tools that take context
```

**Fix**: Use `@agent.tool` if you need context:
```python
@agent.tool
async def good_tool(ctx: RunContext[MyDeps]) -> str:
    return "works"
```

#### Wrong: Missing RunContext in tool

```python
# ERROR: First param must be RunContext
@agent.tool
def bad_tool(user_id: int) -> str:
    return "oops"
# UserError: First parameter of tools that take context must be annotated with RunContext[...]
```

**Fix**: Add RunContext as first parameter:
```python
@agent.tool
def good_tool(ctx: RunContext[MyDeps], user_id: int) -> str:
    return "works"
```

#### Wrong: RunContext not first

```python
# ERROR: RunContext must be first parameter
@agent.tool
def bad_tool(user_id: int, ctx: RunContext[MyDeps]) -> str:
    return "oops"
```

**Fix**: RunContext must always be the first parameter.

### Dependency Type Mismatches

#### Wrong: Missing deps at runtime

```python
agent = Agent('openai:gpt-4o', deps_type=MyDeps)

# ERROR: deps required but not provided
result = agent.run_sync('Hello')  # Missing deps!
```

**Fix**: Always provide deps when deps_type is set:
```python
result = agent.run_sync('Hello', deps=MyDeps(...))
```

#### Wrong: Wrong deps type

```python
@dataclass
class AppDeps:
    db: Database

@dataclass
class WrongDeps:
    api: ApiClient

agent = Agent('openai:gpt-4o', deps_type=AppDeps)

# Type error: WrongDeps != AppDeps
result = agent.run_sync('Hello', deps=WrongDeps(...))
```

### Output Type Issues

#### Pydantic validation fails

```python
class Response(BaseModel):
    count: int
    items: list[str]

agent = Agent('openai:gpt-4o', output_type=Response)
result = agent.run_sync('List items')
# May fail if LLM returns wrong structure
```

**Fix**: Increase retries or improve prompt:
```python
agent = Agent(
    'openai:gpt-4o',
    output_type=Response,
    retries=3,  # More attempts
    instructions='Return JSON with count (int) and items (list of strings).'
)
```

#### Complex nested types

```python
# May cause schema issues with some models
class Complex(BaseModel):
    nested: dict[str, list[tuple[int, str]]]
```

**Fix**: Simplify or use intermediate models:
```python
class Item(BaseModel):
    id: int
    name: str

class Simple(BaseModel):
    items: list[Item]
```

### Async vs Sync Mistakes

#### Wrong: Calling async in sync context

```python
# ERROR: Can't await in sync function
def handler():
    result = await agent.run('Hello')  # SyntaxError!
```

**Fix**: Use run_sync or make handler async:
```python
def handler():
    result = agent.run_sync('Hello')

# Or
async def handler():
    result = await agent.run('Hello')
```

#### Wrong: Blocking in async tools

```python
@agent.tool
async def slow_tool(ctx: RunContext[Deps]) -> str:
    time.sleep(5)  # WRONG: Blocks event loop!
    return "done"
```

**Fix**: Use async I/O:
```python
@agent.tool
async def slow_tool(ctx: RunContext[Deps]) -> str:
    await asyncio.sleep(5)  # Correct
    return "done"
```

### Model Configuration Errors

#### Missing API key

```python
# ERROR: OPENAI_API_KEY not set
agent = Agent('openai:gpt-4o')
result = agent.run_sync('Hello')
# ModelAPIError: Authentication failed
```

**Fix**: Set environment variable or use defer_model_check:
```python
# For testing
agent = Agent('openai:gpt-4o', defer_model_check=True)
with agent.override(model=TestModel()):
    result = agent.run_sync('Hello')
```

#### Invalid model string

```python
# ERROR: Unknown provider
agent = Agent('unknown:model')
# ValueError: Unknown model provider
```

**Fix**: Use valid provider:model format.

### Streaming Issues

#### Wrong: Using result before stream completes

```python
async with agent.run_stream('Hello') as response:
    # DON'T access .output before streaming completes
    print(response.output)  # May be incomplete!

# Correct: access after context manager
print(response.output)  # Complete result
```

#### Wrong: Not iterating stream

```python
async with agent.run_stream('Hello') as response:
    pass  # Never consumed!

# Stream was never read - output may be incomplete
```

**Fix**: Always consume the stream:
```python
async with agent.run_stream('Hello') as response:
    async for chunk in response.stream_output():
        print(chunk, end='')
```

### Tool Return Issues

#### Wrong: Returning non-serializable

```python
@agent.tool_plain
def bad_return() -> object:
    return CustomObject()  # Can't serialize!
```

**Fix**: Return serializable types (str, dict, Pydantic model):
```python
@agent.tool_plain
def good_return() -> dict:
    return {"key": "value"}
```

### Debugging Tips

#### Enable tracing

```python
import logfire
logfire.configure()
logfire.instrument_pydantic_ai()

# Or per-agent
agent = Agent('openai:gpt-4o', instrument=True)
```

#### Capture messages

```python
from pydantic_ai import capture_run_messages

with capture_run_messages() as messages:
    result = agent.run_sync('Hello')

for msg in messages:
    print(type(msg).__name__, msg)
```

#### Check model responses

```python
result = agent.run_sync('Hello')
print(result.all_messages())  # Full message history
print(result.response)  # Last model response
print(result.usage())  # Token usage
```

### Common Error Messages

| Error | Cause | Fix |
|-------|-------|-----|
| `First parameter... RunContext` | @agent.tool missing ctx | Add `ctx: RunContext[...]` |
| `RunContext... only... context` | @agent.tool_plain has ctx | Remove ctx or use @agent.tool |
| `Unknown model provider` | Invalid model string | Use valid `provider:model` |
| `ModelAPIError` | API auth/quota | Check API key, limits |
| `RetryPromptPart` in messages | Validation failed | Check output_type, increase retries |
