# Async

## Critical Anti-Patterns

### 1. Blocking I/O in Async Handlers

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

### 2. Blocking Database Calls

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

### 3. Using time.sleep Instead of asyncio.sleep

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

### 4. Sync File I/O in Async Handlers

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

### 5. Not Using Background Tasks

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

### 6. Sequential Instead of Concurrent Calls

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

### 7. Mixing Sync and Async Route Handlers

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

### 8. Not Awaiting Coroutines

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

### 9. Blocking External API Calls

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

## Review Questions

1. Are all route handlers `async def`?
2. Are there any `requests`, `time.sleep`, or `open()` calls?
3. Is the database driver async (AsyncSession, asyncpg, etc.)?
4. Are background tasks used for long operations?
5. Are independent async calls parallelized with `gather()`?
6. Are all coroutines properly awaited?
7. Are external API calls using async HTTP clients?
