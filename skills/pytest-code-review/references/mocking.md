# Mocking

## Critical Anti-Patterns

### 1. Patching Where Defined Instead of Where Used

**Problem**: Mock doesn't affect the code under test because patch location is wrong.

```python
# module_a.py
def external_api_call():
    return "real data"

# module_b.py
from module_a import external_api_call

def process_data():
    return external_api_call()

# BAD - patching where defined
from unittest.mock import patch

@patch("module_a.external_api_call")  # Wrong location!
def test_process_data(mock_api):
    mock_api.return_value = "mocked data"
    result = process_data()
    assert result == "mocked data"  # FAILS! Uses real function

# GOOD - patch where used
@patch("module_b.external_api_call")  # Patch in module_b namespace
def test_process_data(mock_api):
    mock_api.return_value = "mocked data"
    result = process_data()
    assert result == "mocked data"  # Works!
```

### 2. Not Verifying Mock Calls

**Problem**: Mock used but never verified, test doesn't validate behavior.

```python
# BAD - mock not verified
@pytest.mark.asyncio
async def test_user_creation(mocker):
    mock_db = mocker.AsyncMock()
    mock_db.insert.return_value = {"id": 1}

    await create_user(mock_db, "Alice")
    # No verification! Did it call insert? With what args?

# GOOD - verify mock calls
@pytest.mark.asyncio
async def test_user_creation(mocker):
    mock_db = mocker.AsyncMock()
    mock_db.insert.return_value = {"id": 1}

    result = await create_user(mock_db, "Alice")

    mock_db.insert.assert_called_once_with({"name": "Alice"})
    assert result["id"] == 1
```

### 3. Over-Mocking Internal Implementation

**Problem**: Mocking internal details that should be tested, not mocked.

```python
# BAD - mocking internal helper that should be tested
class UserService:
    def _validate_email(self, email):
        return "@" in email

    def create_user(self, email):
        if self._validate_email(email):
            return User(email=email)
        raise ValueError("Invalid email")

@patch.object(UserService, "_validate_email")
def test_create_user(mock_validate):
    mock_validate.return_value = True
    service = UserService()
    user = service.create_user("invalid")  # Should fail but doesn't!
    assert user.email == "invalid"

# GOOD - test the actual behavior
def test_create_user_valid():
    service = UserService()
    user = service.create_user("valid@example.com")
    assert user.email == "valid@example.com"

def test_create_user_invalid():
    service = UserService()
    with pytest.raises(ValueError, match="Invalid email"):
        service.create_user("invalid")
```

### 4. Using Mock Instead of AsyncMock for Async

**Problem**: Regular Mock doesn't work properly with async code.

```python
# BAD - Mock for async function
from unittest.mock import Mock

@pytest.mark.asyncio
async def test_fetch_data():
    mock_client = Mock()
    mock_client.get = Mock(return_value={"data": "test"})

    result = await fetch_data(mock_client)  # TypeError: object Mock can't be used in 'await'

# GOOD - AsyncMock for async functions
from unittest.mock import AsyncMock

@pytest.mark.asyncio
async def test_fetch_data():
    mock_client = AsyncMock()
    mock_client.get.return_value = {"data": "test"}

    result = await fetch_data(mock_client)
    assert result == {"data": "test"}
```

### 5. Not Resetting Mocks Between Tests

**Problem**: Mock state leaks between tests, causing flaky failures.

```python
# BAD - shared mock across tests
mock_api = Mock()

def test_first_call():
    mock_api.fetch.return_value = "data1"
    result = process(mock_api)
    assert result == "data1"

def test_second_call():
    # Mock still has state from test_first_call!
    mock_api.fetch.return_value = "data2"
    assert mock_api.fetch.call_count == 0  # FAILS! call_count is 1

# GOOD - fresh mock per test with fixture
@pytest.fixture
def mock_api():
    return Mock()

def test_first_call(mock_api):
    mock_api.fetch.return_value = "data1"
    result = process(mock_api)
    assert result == "data1"

def test_second_call(mock_api):
    mock_api.fetch.return_value = "data2"
    result = process(mock_api)
    assert mock_api.fetch.call_count == 1  # Works!
```

### 6. Not Using side_effect for Complex Behavior

**Problem**: Using return_value when mock needs to raise exceptions or vary responses.

```python
# BAD - can't test retry logic with simple return_value
@pytest.mark.asyncio
async def test_retry_on_failure():
    mock_client = AsyncMock()
    mock_client.get.return_value = {"data": "test"}  # Always succeeds!

    result = await fetch_with_retry(mock_client)
    # Can't test retry behavior!

# GOOD - use side_effect for sequence of responses
@pytest.mark.asyncio
async def test_retry_on_failure():
    mock_client = AsyncMock()
    mock_client.get.side_effect = [
        asyncio.TimeoutError(),  # First call fails
        asyncio.TimeoutError(),  # Second call fails
        {"data": "test"}  # Third call succeeds
    ]

    result = await fetch_with_retry(mock_client, max_retries=3)
    assert result == {"data": "test"}
    assert mock_client.get.call_count == 3

# GOOD - use side_effect function for dynamic behavior
def test_dynamic_behavior():
    def side_effect_fn(user_id):
        if user_id == 1:
            return {"name": "Alice"}
        raise ValueError("User not found")

    mock_db = Mock()
    mock_db.get_user.side_effect = side_effect_fn

    assert mock_db.get_user(1) == {"name": "Alice"}
    with pytest.raises(ValueError):
        mock_db.get_user(2)
```

### 7. Not Using spec or spec_set

**Problem**: Mock accepts any attribute, allowing tests that pass but code that fails.

```python
# BAD - mock without spec
def test_user_service():
    mock_db = Mock()
    service = UserService(mock_db)
    service.process()
    # Typo! Should be execute(), not exectue()
    mock_db.exectue.assert_called_once()  # Test passes! But code would fail

# GOOD - use spec to catch attribute errors
def test_user_service():
    mock_db = Mock(spec=Database)
    service = UserService(mock_db)
    service.process()
    # AttributeError: Mock object has no attribute 'exectue'
    mock_db.execute.assert_called_once()  # Forces correct spelling
```

### 8. Patching with Context Manager but Not Using It

**Problem**: Using patch as decorator when context manager is clearer for partial mocking.

```python
# BAD - decorator for partial test mocking
@patch("module.external_call")
def test_process(mock_call):
    mock_call.return_value = "mocked"
    # First part of test uses mock
    result1 = process_with_external()
    assert result1 == "mocked"

    # Second part wants real call, but can't!
    result2 = process_with_external()  # Still mocked!

# GOOD - context manager for scoped mocking
def test_process():
    # First part uses mock
    with patch("module.external_call") as mock_call:
        mock_call.return_value = "mocked"
        result1 = process_with_external()
        assert result1 == "mocked"

    # Second part uses real function
    result2 = process_with_external()
    assert result2 != "mocked"
```

### 9. Not Checking Call Arguments Precisely

**Problem**: Using assert_called() instead of assert_called_with().

```python
# BAD - only checks if called, not what arguments
@pytest.mark.asyncio
async def test_create_user():
    mock_db = AsyncMock()
    await create_user(mock_db, name="Alice", email="alice@example.com")
    mock_db.insert.assert_called()  # Called, but with what args?

# GOOD - verify exact arguments
@pytest.mark.asyncio
async def test_create_user():
    mock_db = AsyncMock()
    await create_user(mock_db, name="Alice", email="alice@example.com")
    mock_db.insert.assert_called_once_with(
        name="Alice",
        email="alice@example.com"
    )

# ALSO GOOD - use call_args for partial matching
@pytest.mark.asyncio
async def test_create_user():
    mock_db = AsyncMock()
    await create_user(mock_db, name="Alice", email="alice@example.com")
    call_args = mock_db.insert.call_args
    assert call_args.kwargs["name"] == "Alice"
    assert "email" in call_args.kwargs
```

### 10. Mocking Entire Objects Instead of Interfaces

**Problem**: Mocking concrete class when interface would be more accurate.

```python
# BAD - mocking concrete class
from unittest.mock import Mock

class PostgresDatabase:
    def query(self, sql): ...
    def execute(self, sql): ...
    def internal_connection_pool(self): ...

def test_service():
    mock_db = Mock(spec=PostgresDatabase)
    # Test knows about PostgreSQL specifics!
    service = UserService(mock_db)

# GOOD - mock interface/protocol
from typing import Protocol

class Database(Protocol):
    async def query(self, sql: str) -> list: ...
    async def execute(self, sql: str) -> None: ...

@pytest.fixture
def mock_db():
    mock = AsyncMock(spec=Database)
    return mock

def test_service(mock_db):
    # Test only depends on interface
    service = UserService(mock_db)
```

### 11. Not Using pytest-mock Plugin

**Problem**: Using unittest.mock directly when pytest-mock provides better integration.

```python
# BAD - manual patch cleanup
from unittest.mock import patch

def test_feature():
    patcher = patch("module.function")
    mock_fn = patcher.start()
    mock_fn.return_value = "test"

    result = use_function()

    patcher.stop()  # Easy to forget!
    assert result == "test"

# GOOD - using pytest-mock mocker fixture
def test_feature(mocker):
    mock_fn = mocker.patch("module.function")
    mock_fn.return_value = "test"

    result = use_function()
    # Automatic cleanup!
    assert result == "test"
```

## Review Questions

1. Are patches applied where the function is used, not where it's defined?
2. Are mock calls verified with assert_called_once_with() or similar?
3. Are internal implementation details tested rather than mocked?
4. Is AsyncMock used for all async functions and methods?
5. Are mocks fresh for each test (via fixtures or setUp)?
6. Is side_effect used for exceptions or varying responses?
7. Do mocks use spec or spec_set to catch attribute errors?
8. Are call arguments verified precisely, not just call presence?
9. Is pytest-mock used instead of raw unittest.mock?
