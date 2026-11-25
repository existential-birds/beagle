# Dependencies

## Critical Anti-Patterns

### 1. Manual Dependency Calls

**Problem**: Calling a dependency function directly bypasses FastAPI's injection system, request caching, and yield cleanup.

```python
# BAD - manually calling dependency
async def get_db_session():
    return AsyncSessionLocal()

@router.get("/users")
async def list_users():
    db = await get_db_session()  # Manual call, never closed!
    result = await db.execute(select(User))
    return result.scalars().all()

# GOOD - using Annotated[..., Depends()]
from collections.abc import AsyncIterator
from typing import Annotated
from fastapi import Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

async def get_db_session() -> AsyncIterator[AsyncSession]:
    async with AsyncSessionLocal() as session:
        yield session

@router.get("/users", response_model=list[UserResponse])
async def list_users(db: Annotated[AsyncSession, Depends(get_db_session)]):
    result = await db.execute(select(User))
    return result.scalars().all()
```

### 2. Missing Cleanup in Yield Dependencies

**Problem**: Resources leak when exceptions occur if yield cleanup is missing `try`/`finally` or context management.

```python
# BAD - no cleanup on exception
async def get_db():
    db = await DatabaseConnection.connect()
    yield db
    await db.close()  # Skipped if endpoint raises!

# GOOD - guaranteed cleanup with try/finally (or async with)
async def get_db():
    db = await DatabaseConnection.connect()
    try:
        yield db
    finally:
        await db.close()
```

### 3. Shared Mutable State & Caching Traps

**Problem**: Module-level mutable state causes cross-request race conditions, and `@functools.lru_cache` on `async def` caches the coroutine object (raising `RuntimeError: cannot reuse already awaited coroutine` on the second call).

```python
# BAD - shared mutable state across requests
cache = {}

async def get_cache():
    return cache

# BAD - @lru_cache on an async def function caches a single coroutine object!
from functools import lru_cache

@lru_cache(maxsize=128)
async def get_item_cached(id: int):  # Second call raises RuntimeError!
    return await fetch_item(id)

# GOOD - @lru_cache on synchronous config/settings dependency
@lru_cache
def get_settings() -> Settings:
    return Settings()

# GOOD - request-scoped state via yield or ContextVar, or async cache (e.g., async-lru / Redis)
from async_lru import alru_cache

@alru_cache(maxsize=128)
async def get_item_cached(item_id: int):
    return await fetch_item(item_id)
```

### 4. Nested Depends Not Utilized

**Problem**: Duplicating token decoding or permission checks across dependencies instead of composing them.

```python
# BAD - duplicated auth logic
async def get_admin_user(token: str):
    user = await verify_and_decode(token)
    if not user.is_admin:
        raise HTTPException(403)
    return user

# GOOD - compose dependencies with Annotated
CurrentUser = Annotated[User, Depends(get_current_user)]

async def get_current_user(
    token: Annotated[str, Depends(oauth2_scheme)],
) -> User:
    user = await verify_token(token)
    if not user:
        raise HTTPException(status_code=401, detail="Invalid token")
    return user

async def get_admin_user(user: CurrentUser) -> User:
    if not user.is_admin:
        raise HTTPException(status_code=403, detail="Admin required")
    return user
```

### 5. Dependencies with Side Effects vs Pure ASGI Middleware

**Problem**: Using dependencies for global side effects hides work; using Starlette's `BaseHTTPMiddleware` breaks `contextvars` propagation, buffers/breaks streaming responses, ignores WebSockets, and adds overhead.

```python
# BAD - dependency performs side effects invisibly
async def log_request(request: Request):
    await audit_log.record(request)

# AVOID for streaming/contextvars/WebSocket apps - BaseHTTPMiddleware caveats
from starlette.middleware.base import BaseHTTPMiddleware

# GOOD - pure ASGI middleware for cross-cutting request/response concerns
from starlette.types import ASGIApp, Receive, Scope, Send

class LoggingMiddleware:
    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] == "http":
            await audit_log.record_scope(scope)
        await self.app(scope, receive, send)

app.add_middleware(LoggingMiddleware)

# GOOD - dependency returns a request-scoped resource
def get_request_logger(request: Request) -> RequestLogger:
    return RequestLogger(request)

@router.get("/users")
async def list_users(
    logger: Annotated[RequestLogger, Depends(get_request_logger)],
):
    logger.info("Listing users")
    return users
```

### 6. Re-Creating Expensive Clients Instead of Using `request.app.state`

**Problem**: Instantiating pools/clients per request leaks connections; referencing a module-global `app` inside `Depends(lambda: app.state...)` breaks router modularity and testability.

```python
# BAD - new pool created on every request!
class DatabaseService:
    def __init__(self):
        self.connection_pool = create_pool()

@router.get("/users")
async def list_users(db: Annotated[DatabaseService, Depends(DatabaseService)]):
    return await db.query_users()

# BAD - couples dependency to global `app`
async def get_db_service(pool=Depends(lambda: app.state.db_pool)): ...

# GOOD - inject Request to read lifespan-managed app.state
from fastapi import Depends, Request

def get_db_pool(request: Request):
    return request.app.state.db_pool

def get_db_service(pool=Depends(get_db_pool)) -> DatabaseService:
    return DatabaseService(pool)

@router.get("/users")
async def list_users(db: Annotated[DatabaseService, Depends(get_db_service)]):
    return await db.query_users()
```

### 7. Security Dependencies Not Applied at Router Level

**Problem**: Easy to forget per-route auth dependencies when adding new endpoints.

```python
# BAD - must remember auth on every route
@router.get("/users", dependencies=[Depends(verify_token)])
async def list_users(): ...

@router.get("/posts")  # Forgot auth!
async def list_posts(): ...

# GOOD - apply at router level
router = APIRouter(
    prefix="/api/v1",
    dependencies=[Depends(verify_token)],
)

@router.get("/users")
async def list_users(): ...

@router.get("/posts")
async def list_posts(): ...
```

## Review Questions

1. Are dependencies injected via `Annotated[..., Depends()]` (not manually called)?
2. Do yield dependencies guarantee cleanup in `finally` or `async with`?
3. Is `@lru_cache` restricted to sync dependencies (never applied to `async def`)?
4. Are nested dependencies composed cleanly instead of duplicating logic?
5. Is pure ASGI middleware used instead of `BaseHTTPMiddleware` where `contextvars`, streaming, or WebSockets apply?
6. Are lifespan-managed pools accessed via `request.app.state` rather than global `app` lambdas or per-request instantiation?
7. Are security dependencies applied at router or app level?
