# Test Quality Criteria

Detailed detection criteria for test quality issues commonly introduced by LLM coding agents.

## 1. DRY Violations

### What to Look For

Repeated setup/teardown code across test functions instead of using fixtures, conftest, or shared helpers.

### Detection Patterns

**Repeated Object Creation**:
```python
# BAD - Same setup in multiple tests
def test_user_creation():
    db = Database(host="localhost", port=5432)
    user = User(name="test", email="test@example.com")
    # test logic

def test_user_update():
    db = Database(host="localhost", port=5432)  # Repeated!
    user = User(name="test", email="test@example.com")  # Repeated!
    # test logic

# GOOD - Use fixtures
@pytest.fixture
def db():
    return Database(host="localhost", port=5432)

@pytest.fixture
def test_user():
    return User(name="test", email="test@example.com")

def test_user_creation(db, test_user):
    # test logic
```

**Repeated Mock Configuration**:
```python
# BAD - Mock setup copied across tests
def test_api_success():
    mock_response = Mock()
    mock_response.status_code = 200
    mock_response.json.return_value = {"data": "test"}
    with patch("requests.get", return_value=mock_response):
        # test

def test_api_parsing():
    mock_response = Mock()  # Repeated!
    mock_response.status_code = 200
    mock_response.json.return_value = {"data": "test"}
    with patch("requests.get", return_value=mock_response):  # Repeated!
        # test
```

**Copy-Pasted Database Setup**:
```python
# BAD - Database initialization in every test
def test_query_users():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    # test

def test_query_orders():
    engine = create_engine("sqlite:///:memory:")  # Repeated!
    Base.metadata.create_all(engine)  # Repeated!
    Session = sessionmaker(bind=engine)  # Repeated!
    session = Session()
    # test
```

### How to Fix

1. Extract to `conftest.py` fixtures
2. Use fixture scope appropriately (function, class, module, session)
3. Create factory fixtures for parameterized data
4. Use fixture composition for complex setups

---

## 2. Library Testing

### What to Look For

Tests that validate standard library or framework behavior rather than application code.

### Detection Patterns

**No Application Imports**:
```python
# BAD - Testing Python stdlib, not our code
import json

def test_json_loads():
    result = json.loads('{"key": "value"}')
    assert result == {"key": "value"}

def test_json_dumps():
    result = json.dumps({"key": "value"})
    assert result == '{"key": "value"}'
```

**Testing Framework Behavior**:
```python
# BAD - Testing SQLAlchemy, not our models
from sqlalchemy import Column, Integer, String

def test_column_types():
    col = Column(Integer)
    assert col.type.__class__.__name__ == "Integer"

# BAD - Testing Pydantic validation
from pydantic import BaseModel

def test_pydantic_validates():
    class M(BaseModel):
        x: int
    assert M(x=1).x == 1
```

**Signs of Library Testing**:
- Test file imports only stdlib/third-party, no `from myapp import`
- Tests verify documented framework behavior
- Assertions match framework documentation examples
- No domain logic being tested

### How to Fix

1. Delete tests that only verify framework behavior
2. Focus on testing YOUR code that uses the framework
3. Test business logic, not library internals
4. Trust well-tested libraries

---

## 3. Mock Boundaries

### What to Look For

Mocking at the wrong level - either too deep (internal implementation) or too shallow (missing integration points).

### Too Deep: Mocking Internals

```python
# BAD - Mocking private methods
def test_process():
    service = DataService()
    with patch.object(service, "_internal_helper"):  # Too deep!
        with patch.object(service, "_validate_internal"):  # Too deep!
            service.process(data)

# BAD - Mocking implementation details
def test_calculate():
    with patch("myapp.service._cache_lookup"):  # Internal!
        with patch("myapp.service._serialize"):  # Internal!
            result = calculate(input)
```

**Problems with Deep Mocking**:
- Tests break when refactoring internals
- Tests know too much about implementation
- False confidence - internals change, tests still pass

### Too Shallow: Missing Integration Points

```python
# BAD - Not mocking external API in unit test
def test_get_weather():
    # Actually calls the real weather API!
    result = weather_service.get_current("NYC")
    assert result.temp > 0

# BAD - Not mocking database in unit test
def test_user_service():
    # Actually hits the real database!
    user = user_service.get_by_id(1)
```

**Problems with Shallow Mocking**:
- Tests are slow (real network/DB calls)
- Tests are flaky (external dependencies)
- Can't test edge cases easily

### Correct Mock Boundaries

```python
# GOOD - Mock at integration boundaries
def test_weather_service(mock_weather_api):
    mock_weather_api.get.return_value = WeatherResponse(temp=72)
    result = weather_service.get_current("NYC")
    assert result.temp == 72

# GOOD - Mock external dependencies, not internals
def test_data_processor(mock_database, mock_external_api):
    mock_database.query.return_value = [...]
    mock_external_api.fetch.return_value = {...}
    result = processor.process()
    # Tests OUR logic with controlled inputs
```

### Guidelines

| Test Type | What to Mock | What NOT to Mock |
|-----------|--------------|------------------|
| Unit | External APIs, DB, file system | Internal helpers, private methods |
| Integration | External APIs only | DB, internal services |
| E2E | Nothing (or external APIs) | Internal systems |

### Review Questions

1. Are private methods (`_method`) being mocked?
2. Are tests making real external API calls?
3. Do mock boundaries match architectural boundaries?
4. Would refactoring internals break these tests?
