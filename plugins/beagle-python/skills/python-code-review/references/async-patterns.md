# Async Patterns

## Critical Anti-Patterns

### 1. Blocking Calls in Async Functions

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

### 2. Missing await on Coroutines

**Problem**: Coroutine never executes.

```python
# BAD - coroutine created but never awaited
async def process():
    fetch_data()  # Returns coroutine, doesn't execute!

# GOOD
async def process():
    await fetch_data()
```

### 3. Sequential Instead of Concurrent

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

### 4. Missing async with for Async Context Managers

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

### 5. Sync File I/O in Async Context

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

## Review Questions

1. Are there any `requests`, `time.sleep`, or `open()` calls in async functions?
2. Is every coroutine call awaited?
3. Are independent async calls parallelized with `gather()`?
4. Are async context managers used with `async with`?
