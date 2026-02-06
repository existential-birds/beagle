# Dependencies

## Critical Anti-Patterns

### 1. Manual Dependency Calls

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

### 2. Missing Cleanup in Yield Dependencies

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

### 3. Shared State Without Proper Scope

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

### 4. Nested Depends Not Utilized

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

### 5. Dependencies with Side Effects

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

### 6. Class-Based Dependencies Without Caching

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

### 7. Security Dependencies Not Applied Globally

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

## Review Questions

1. Are all dependencies injected via `Depends()` not manually called?
2. Do yield dependencies have proper `try/finally` cleanup?
3. Is there any shared mutable state across requests?
4. Are nested dependencies used to compose common patterns?
5. Do dependencies provide resources, not perform side effects?
6. Are security dependencies applied at router or app level?
