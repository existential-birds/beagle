# Test Quality — Python examples

Worked examples for [../../tests-criteria.md](../../tests-criteria.md). Load only when reviewing Python tests. The criteria file is the authority; these illustrate it.

## 1. DRY Violations

**Repeated object creation**:
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

**Repeated mock configuration**:
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

**Copy-pasted database setup**:
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

**Python-specific fixes:** extract to `conftest.py` fixtures; set fixture scope (`function`, `class`, `module`, `session`) to the narrowest that works; use factory fixtures for parameterized data; compose fixtures for complex setups.

## 2. Library Testing

**No application imports**:
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

**Testing framework behavior**:
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

**Python-specific signal:** the test file has no `from myapp import ...` — only stdlib and third-party imports.

## 3. Mock Boundaries

**Too deep — mocking internals**:
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

**Too shallow — missing integration points**:
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

**Correct boundaries**:
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

**Python-specific signal:** `patch.object(x, "_leading_underscore")` and `patch("pkg.mod._private")` are near-certain too-deep mocks.
