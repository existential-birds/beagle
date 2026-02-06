# Async Testing

## Critical Anti-Patterns

### 1. Using Mock Instead of AsyncMock

**Problem**: Mock returns a regular Mock object, not a coroutine. Tests pass but don't actually test async behavior.

```python
# BAD - Mock doesn't work with async
from unittest.mock import Mock

@pytest.mark.asyncio
async def test_fetch_data():
    mock_client = Mock()
    mock_client.get.return_value = {"data": "test"}

    # This won't work! mock_client.get() is not awaitable
    result = await fetch_data(mock_client)  # TypeError!

# GOOD - AsyncMock for async functions
from unittest.mock import AsyncMock

@pytest.mark.asyncio
async def test_fetch_data():
    mock_client = AsyncMock()
    mock_client.get.return_value = {"data": "test"}

    result = await fetch_data(mock_client)
    assert result == {"data": "test"}
```

### 2. Forgetting @pytest.mark.asyncio

**Problem**: Test function is not run as coroutine, async code never executes.

```python
# BAD - missing decorator
async def test_process_data():
    result = await process_data()  # Never actually awaited!
    assert result == expected

# GOOD - proper async test
@pytest.mark.asyncio
async def test_process_data():
    result = await process_data()
    assert result == expected
```

### 3. Not Awaiting Async Mocks

**Problem**: Mock returns coroutine object instead of actual value.

```python
# BAD - not awaiting AsyncMock
@pytest.mark.asyncio
async def test_service():
    mock_db = AsyncMock()
    mock_db.query.return_value = [{"id": 1}]

    service = UserService(mock_db)
    result = service.get_users()  # Returns coroutine, not list!
    assert len(result) == 1  # TypeError!

# GOOD - await AsyncMock
@pytest.mark.asyncio
async def test_service():
    mock_db = AsyncMock()
    mock_db.query.return_value = [{"id": 1}]

    service = UserService(mock_db)
    result = await service.get_users()
    assert len(result) == 1
```

### 4. Mixing Sync and Async in Tests

**Problem**: Calling sync blocking code in async test defeats purpose.

```python
# BAD - mixing sync and async
@pytest.mark.asyncio
async def test_user_flow():
    user = create_user_sync()  # Blocking call!
    time.sleep(1)  # Blocks event loop!
    result = await process_user(user)
    assert result.processed

# GOOD - fully async
@pytest.mark.asyncio
async def test_user_flow():
    user = await create_user_async()
    await asyncio.sleep(1)
    result = await process_user(user)
    assert result.processed
```

### 5. Not Cleaning Up Async Resources

**Problem**: Background tasks, connections, or coroutines left running after test.

```python
# BAD - no cleanup
@pytest.mark.asyncio
async def test_background_task():
    task = asyncio.create_task(long_running_operation())
    # Task still running after test ends!
    result = await some_other_operation()
    assert result

# GOOD - proper cleanup
@pytest.mark.asyncio
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

### 6. Not Testing Concurrent Behavior

**Problem**: Tests run sequentially, missing race conditions and timing issues.

```python
# BAD - sequential testing of concurrent code
@pytest.mark.asyncio
async def test_concurrent_updates():
    await update_counter()
    await update_counter()
    # Doesn't test actual concurrent access!
    assert get_counter() == 2

# GOOD - actually test concurrency
@pytest.mark.asyncio
async def test_concurrent_updates():
    results = await asyncio.gather(
        update_counter(),
        update_counter(),
        update_counter()
    )
    # Tests actual concurrent behavior
    assert get_counter() == 3
```

### 7. Using pytest-asyncio Without Configuration

**Problem**: Tests may not run in correct mode or fail silently.

```python
# BAD - no configuration, ambiguous mode
# test_something.py
async def test_feature():  # Might not run as async!
    result = await process()
    assert result

# GOOD - explicit configuration
# pyproject.toml or pytest.ini
[tool.pytest.ini_options]
asyncio_mode = "auto"

# test_something.py
import pytest

@pytest.mark.asyncio
async def test_feature():
    result = await process()
    assert result
```

### 8. Not Testing Exception Paths in Async Code

**Problem**: Async exceptions behave differently, need explicit testing.

```python
# BAD - not testing async exceptions
@pytest.mark.asyncio
async def test_error_handling():
    # Doesn't verify exception is properly raised
    result = await fetch_data_with_retry()
    assert result

# GOOD - test async exception handling
@pytest.mark.asyncio
async def test_error_handling():
    mock_client = AsyncMock()
    mock_client.get.side_effect = asyncio.TimeoutError()

    with pytest.raises(asyncio.TimeoutError):
        await fetch_data(mock_client)
```

## Review Questions

1. Are all async test functions marked with `@pytest.mark.asyncio`?
2. Are `AsyncMock` objects used instead of `Mock` for async dependencies?
3. Are all coroutines and async mocks properly awaited?
4. Are async resources (tasks, connections) cleaned up after tests?
5. Do concurrent code tests actually run operations concurrently?
6. Is pytest-asyncio configured correctly in pyproject.toml or pytest.ini?
