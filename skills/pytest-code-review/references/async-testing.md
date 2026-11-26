# Async Testing

## Critical Anti-Patterns

### 1. Using `Mock` Instead of `AsyncMock`

**Problem**: Regular `Mock` is not awaitable and fails with `TypeError` (or masks unawaited calls).

```python
# BAD - Mock isn't awaitable
from unittest.mock import Mock

async def test_fetch_data():
    mock_client = Mock()
    mock_client.get.return_value = {"data": "test"}
    result = await fetch_data(mock_client)  # TypeError!

# GOOD - AsyncMock for async methods
from unittest.mock import AsyncMock

async def test_fetch_data():
    mock_client = AsyncMock()
    mock_client.get.return_value = {"data": "test"}
    result = await fetch_data(mock_client)
    assert result == {"data": "test"}
```

### 2. `pytest-asyncio` `strict` vs `auto` Mode Mismatches

**Problem**: `pytest-asyncio` defaults to `strict` mode, where unmarked `async def test_*` functions are skipped/ignored and `@pytest.fixture async def` fails unless `@pytest_asyncio.fixture` is used. Conversely, configuring `asyncio_mode = "auto"` makes `@pytest.mark.asyncio` and `@pytest_asyncio.fixture` redundant. Also, `pytest-asyncio` 0.24+/1.x warns unless `asyncio_default_fixture_loop_scope` is set explicitly.

```toml
# OPTION A (Recommended for async-heavy repos): explicit auto mode in pyproject.toml
[tool.pytest.ini_options]
asyncio_mode = "auto"
asyncio_default_fixture_loop_scope = "function"
```

```python
# Under asyncio_mode = "auto": no markers needed on tests or fixtures
@pytest.fixture
async def client():
    async with httpx.AsyncClient(base_url="http://test") as c:
        yield c

async def test_feature(client):
    resp = await client.get("/health")
    assert resp.status_code == 200
```

```python
# OPTION B (strict mode, the default when asyncio_mode is unset or "strict"):
# Both @pytest_asyncio.fixture and @pytest.mark.asyncio are REQUIRED!
import pytest
import pytest_asyncio

@pytest_asyncio.fixture
async def client():
    async with httpx.AsyncClient(base_url="http://test") as c:
        yield c

@pytest.mark.asyncio
async def test_feature(client):
    resp = await client.get("/health")
    assert resp.status_code == 200
```

### 3. Not Awaiting Async Mocks / Coroutines

**Problem**: Calling an async method or `AsyncMock` without `await` returns a coroutine object instead of executing it.

```python
# BAD - missing await
async def test_service():
    mock_db = AsyncMock()
    mock_db.query.return_value = [{"id": 1}]
    service = UserService(mock_db)
    result = service.get_users()  # Returns coroutine object!
    assert len(result) == 1       # TypeError!

# GOOD
async def test_service():
    mock_db = AsyncMock()
    mock_db.query.return_value = [{"id": 1}]
    service = UserService(mock_db)
    result = await service.get_users()
    assert len(result) == 1
```

### 4. Blocking Calls Inside Async Tests

**Problem**: Calling `time.sleep()` or sync blocking I/O inside an async test stalls the test event loop and masks concurrency bugs.

```python
# BAD
async def test_user_flow():
    user = create_user_sync()
    time.sleep(1)  # Blocks event loop!
    result = await process_user(user)
    assert result.processed

# GOOD
async def test_user_flow():
    user = await create_user_async()
    await asyncio.sleep(0.05)
    result = await process_user(user)
    assert result.processed
```

### 5. Not Cleaning Up Background Tasks / Async Resources

**Problem**: Uncancelled `asyncio.create_task(...)` tasks keep running past test teardown and trigger warnings or cross-test interference.

```python
# BAD - task left running
async def test_background_task():
    task = asyncio.create_task(long_running_operation())
    result = await some_other_operation()
    assert result

# GOOD - cancel and await in finally
async def test_background_task():
    task = asyncio.create_task(long_running_operation())
    try:
        result = await some_other_operation()
        assert result
    finally:
        task.cancel()
        try:
            await task
        except asyncio.CancelledError:
            pass
```

### 6. Testing Concurrent Code Sequentially

**Problem**: Sequential `await` calls never exercise race conditions or locking.

```python
# BAD - sequential
async def test_concurrent_updates():
    await update_counter()
    await update_counter()
    assert get_counter() == 2

# GOOD - concurrent execution via asyncio.gather
async def test_concurrent_updates():
    await asyncio.gather(
        update_counter(),
        update_counter(),
        update_counter(),
    )
    assert get_counter() == 3
```

### 7. Not Testing Async Exception Paths

**Problem**: Failing to test timeouts or rejected awaits leaves error-handling branches unverified.

```python
async def test_error_handling():
    mock_client = AsyncMock()
    mock_client.get.side_effect = asyncio.TimeoutError()

    with pytest.raises(asyncio.TimeoutError):
        await fetch_data(mock_client)
```

## Review Questions

1. Does `pyproject.toml` / `pytest.ini` configure `asyncio_mode` (`"auto"` or `"strict"`) and `asyncio_default_fixture_loop_scope`, and do test/fixture decorators match that mode?
2. Are `AsyncMock` objects used instead of `Mock` for async dependencies?
3. Are all coroutines and async mocks properly awaited?
4. Are spawned `asyncio.Task`s and async clients cleaned up in `finally` blocks?
5. Do concurrency tests actually run operations concurrently (`asyncio.gather`)?
