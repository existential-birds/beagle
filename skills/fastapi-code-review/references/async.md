# Async

## Critical Anti-Patterns

### 1. Blocking External HTTP Calls in Async Handlers

**Problem**: Synchronous HTTP libraries (`requests`, `urllib`) inside `async def` block the event loop and stall all concurrent requests.

```python
# BAD - blocking HTTP client inside async def
import requests

@router.get("/weather")
async def get_weather(city: str):
    response = requests.get(f"https://api.weather.com/{city}")  # BLOCKS event loop!
    return response.json()

# GOOD - async httpx client with timeout and error handling
import httpx
from fastapi import HTTPException

@router.get("/weather")
async def get_weather(city: str):
    async with httpx.AsyncClient(timeout=5.0) as client:
        try:
            response = await client.get(f"https://api.weather.com/{city}")
            response.raise_for_status()
            return response.json()
        except httpx.TimeoutException as exc:
            raise HTTPException(status_code=504, detail="Weather API timeout") from exc
```

### 2. Blocking Database Calls in Async Handlers

**Problem**: Synchronous DB drivers inside `async def` block the event loop. (If you intentionally use a sync DB driver, use a sync `def` handler instead so FastAPI runs it in the AnyIO threadpool.)

```python
# BAD - sync SQLAlchemy inside async def
from sqlalchemy.orm import Session

@router.get("/users", response_model=list[UserResponse])
async def list_users(db: Annotated[Session, Depends(get_db)]):
    return db.query(User).all()  # BLOCKS event loop!

# GOOD - async SQLAlchemy in async def
from typing import Annotated
from fastapi import Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

@router.get("/users", response_model=list[UserResponse])
async def list_users(db: Annotated[AsyncSession, Depends(get_db)]):
    result = await db.execute(select(User))
    return result.scalars().all()
```

### 3. Using `time.sleep` Instead of `asyncio.sleep`

**Problem**: `time.sleep()` inside `async def` blocks the event loop.

```python
# BAD - blocking sleep in async handler
import time

@router.post("/jobs")
async def create_job():
    time.sleep(5)  # BLOCKS event loop for 5 seconds!
    return {"status": "done"}

# GOOD - non-blocking sleep or BackgroundTasks for long work
import asyncio
from fastapi import BackgroundTasks

async def process_job():
    await asyncio.sleep(5)
    # Do actual work

@router.post("/jobs", status_code=202)
async def create_job(background_tasks: BackgroundTasks):
    background_tasks.add_task(process_job)
    return {"status": "processing"}
```

### 4. Sync File I/O in Async Context

**Problem**: Synchronous `open()` blocks the event loop for large or slow filesystem reads.

```python
# BAD - blocking file I/O in async handler
@router.get("/config")
async def get_config():
    with open("config.json") as f:  # BLOCKS!
        return json.load(f)

# GOOD - async file I/O with aiofiles
import aiofiles

@router.get("/config")
async def get_config():
    async with aiofiles.open("config.json") as f:
        content = await f.read()
    return json.loads(content)

# GOOD - offload sync function with asyncio.to_thread (Python 3.9+)
import asyncio

def read_config_sync():
    with open("config.json") as f:
        return json.load(f)

@router.get("/config")
async def get_config():
    return await asyncio.to_thread(read_config_sync)
```

*(Note: Avoid legacy loop-lookup APIs deprecated when no loop is running in Python 3.12+ and raising `RuntimeError` in 3.14+; use `asyncio.to_thread()` or `asyncio.get_running_loop()`.)*

### 5. Not Using Background Tasks for Slow Side Effects

**Problem**: Awaiting non-critical slow operations (sending email, webhooks) delays the HTTP response.

```python
# BAD - blocks response on slow email delivery
@router.post("/emails")
async def send_email(email: EmailCreate):
    await send_email_via_smtp(email)  # Takes 5 seconds!
    await log_email_sent(email)
    return {"status": "sent"}

# GOOD - offload post-response work to BackgroundTasks
from fastapi import BackgroundTasks

async def send_email_background(email: EmailCreate):
    await send_email_via_smtp(email)
    await log_email_sent(email)

@router.post("/emails", status_code=202)
async def send_email(
    email: EmailCreate,
    background_tasks: BackgroundTasks,
):
    background_tasks.add_task(send_email_background, email)
    return {"status": "queued"}
```

### 6. Sequential Instead of Concurrent Awaits

**Problem**: Awaiting independent async operations sequentially wastes wall-clock latency.

```python
# BAD - sequential
@router.get("/dashboard")
async def get_dashboard(user_id: int):
    user = await get_user(user_id)
    posts = await get_user_posts(user_id)
    stats = await get_user_stats(user_id)
    return {"user": user, "posts": posts, "stats": stats}

# GOOD - concurrent
import asyncio

@router.get("/dashboard")
async def get_dashboard(user_id: int):
    user, posts, stats = await asyncio.gather(
        get_user(user_id),
        get_user_posts(user_id),
        get_user_stats(user_id),
    )
    return {"user": user, "posts": posts, "stats": stats}
```

### 7. Putting Blocking I/O in `async def` vs Using `def` Properly

**Problem**: FastAPI intentionally runs synchronous `def` handlers in an AnyIO worker threadpool—so a `def` handler using a sync DB driver does **not** block the event loop. The bug is putting synchronous blocking calls inside `async def`, or starving the default threadpool (40 tokens) with long-running blocking operations that should be async or offloaded.

```python
# VALID - sync def handler with sync SQLAlchemy (FastAPI runs in AnyIO threadpool)
@router.get("/sync-route", response_model=list[UserResponse])
def sync_handler(db: Annotated[Session, Depends(get_sync_db)]):
    return db.execute(select(User)).scalars().all()

# BAD - sync blocking call inside async def (stalls entire event loop!)
@router.get("/broken-async")
async def broken_handler(db: Annotated[Session, Depends(get_sync_db)]):
    return db.execute(select(User)).scalars().all()

# GOOD - async def with async DB driver
@router.get("/async-route", response_model=list[UserResponse])
async def async_handler(db: Annotated[AsyncSession, Depends(get_async_db)]):
    result = await db.execute(select(User))
    return result.scalars().all()
```

### 8. Not Awaiting Coroutines

**Problem**: Calling an `async def` function without `await` creates an unawaited coroutine object and silently skips execution.

```python
# BAD - missing await
@router.post("/users")
async def create_user(user: UserCreate):
    db.create_user(user)  # Returns coroutine, never runs!
    return {"status": "created"}

# GOOD - await coroutines
@router.post("/users", response_model=UserResponse, status_code=201)
async def create_user(user: UserCreate):
    return await db.create_user(user)
```

## Review Questions

1. Are `async def` handlers free of blocking calls (`requests`, `time.sleep`, sync `open()`, sync DB drivers), or appropriately defined as `def` for sync I/O?
2. Is `asyncio.to_thread()` (or `asyncio.get_running_loop()`) used instead of deprecated Python 3.12+ loop-lookup APIs?
3. Is the database driver async (`AsyncSession`, `asyncpg`, `psycopg` async) when used inside `async def`?
4. Are `BackgroundTasks` used for slow non-critical post-response operations?
5. Are independent async calls parallelized with `asyncio.gather()` or `asyncio.TaskGroup`?
6. Are all coroutines properly awaited?
