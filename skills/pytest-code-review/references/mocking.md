# Mocking

## Critical Anti-Patterns

### 1. Patching Where Defined Instead of Where Used

**Problem**: `patch()` replaces the attribute on the target module; if the code under test did `from module_a import external_api_call`, patching `module_a.external_api_call` leaves `module_b`'s local binding untouched.

```python
# module_a.py
def external_api_call():
    return "real data"

# module_b.py
from module_a import external_api_call

def process_data():
    return external_api_call()

# BAD - patching where defined
@patch("module_a.external_api_call")  # module_b still calls real function!
def test_process_data(mock_api):
    ...

# GOOD - patch where looked up/used
@patch("module_b.external_api_call")
def test_process_data(mock_api):
    mock_api.return_value = "mocked data"
    assert process_data() == "mocked data"
```

### 2. Verifying Mock Calls and Arguments Precisely

**Problem**: Leaving mocks unverified or calling only `assert_called()` fails to verify what arguments were actually passed to the dependency.

```python
# BAD - no verification, or only assert_called()
async def test_create_user():
    mock_db = AsyncMock()
    await create_user(mock_db, name="Alice", email="alice@example.com")
    mock_db.insert.assert_called()  # Passes even if wrong args were passed!

# GOOD - verify exact call count and arguments (or inspect call_args)
async def test_create_user():
    mock_db = AsyncMock()
    await create_user(mock_db, name="Alice", email="alice@example.com")
    mock_db.insert.assert_called_once_with(
        name="Alice",
        email="alice@example.com",
    )
```

### 3. Over-Mocking Internal Implementation

**Problem**: Patching private helpers (`_validate_email`) couples tests to implementation details and lets real bugs pass.

```python
# BAD - mocking internal helper
@patch.object(UserService, "_validate_email", return_value=True)
def test_create_user(mock_validate):
    user = UserService().create_user("invalid")  # Bug hidden!
    assert user.email == "invalid"

# GOOD - test public behavior directly
def test_create_user_invalid():
    with pytest.raises(ValueError, match="Invalid email"):
        UserService().create_user("invalid")
```

### 4. Using `Mock` Instead of `AsyncMock` for Async

**Problem**: `Mock` is not awaitable and raises `TypeError` on `await`.

```python
# BAD
mock_client = Mock()
mock_client.get = Mock(return_value={"data": "test"})

# GOOD
from unittest.mock import AsyncMock

mock_client = AsyncMock()
mock_client.get.return_value = {"data": "test"}
```

### 5. Sharing Module-Level Mocks Across Tests

**Problem**: Module-level `mock_api = Mock()` leaks `call_count` and `return_value` across tests.

```python
# BAD - shared state across tests
mock_api = Mock()

# GOOD - fresh mock per test via fixture
@pytest.fixture
def mock_api():
    return Mock()
```

### 6. Not Using `side_effect` for Retries and Exceptions

**Problem**: Static `return_value` cannot exercise retry loops or dynamic inputs.

```python
async def test_retry_on_failure():
    mock_client = AsyncMock()
    mock_client.get.side_effect = [
        asyncio.TimeoutError(),
        asyncio.TimeoutError(),
        {"data": "test"},
    ]

    result = await fetch_with_retry(mock_client, max_retries=3)
    assert result == {"data": "test"}
    assert mock_client.get.call_count == 3
```

### 7. Not Using `spec` or `spec_set`

**Problem**: Unspecced mocks accept typos (`mock_db.exectue.assert_called_once()`) and stale method names silently.

```python
# BAD - typo passes silently
mock_db = Mock()
service = UserService(mock_db)
service.process()
mock_db.exectue.assert_called_once()  # Typo never caught!

# GOOD - spec_set catches invalid attribute reads AND writes
mock_db = Mock(spec_set=Database)
```

### 8. Scoped Patching With Context Managers vs Decorators

**Problem**: A `@patch` decorator stays active for the entire test function even when only one phase should be mocked; use `with patch(...)` (or `mocker.patch`) when scoping matters.

### 9. Mocking Concrete Implementations Instead of `Protocol` / Interfaces

**Problem**: Mocking a concrete DB driver class leaks storage internals into unit tests; prefer `spec_set=DatabaseProtocol` for clean interface boundaries.

### 10. Manual `patch.start()` Without `stop()` Cleanup

**Problem**: `patcher.start()` without `try`/`finally` or `addCleanup` leaks patches into subsequent tests if an assertion fails. Use `with patch(...)` or `pytest-mock`'s `mocker.patch(...)` (which automatically tears down after each test).

## Review Questions

1. Are `patch()` targets placed where the symbol is **used** (call site), not where defined?
2. Are mock calls verified with exact expectations (`assert_called_once_with`, `call_args`)?
3. Are tests avoiding patching private/internal methods?
4. Is `AsyncMock` used for async functions/methods?
5. Do mocks use `spec` / `spec_set` and fresh per-test instances?
6. Are manual `patch.start()` calls avoided in favor of `with patch(...)` or `mocker`?
