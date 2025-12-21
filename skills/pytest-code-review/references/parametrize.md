# Parametrize

## Critical Anti-Patterns

### 1. Duplicated Test Functions for Similar Cases

**Problem**: Copy-pasted test functions that differ only in input values.

```python
# BAD - duplicated test logic
@pytest.mark.asyncio
async def test_validate_email_valid():
    result = validate_email("user@example.com")
    assert result.is_valid is True

@pytest.mark.asyncio
async def test_validate_email_valid_subdomain():
    result = validate_email("user@mail.example.com")
    assert result.is_valid is True

@pytest.mark.asyncio
async def test_validate_email_invalid_no_at():
    result = validate_email("userexample.com")
    assert result.is_valid is False

@pytest.mark.asyncio
async def test_validate_email_invalid_no_domain():
    result = validate_email("user@")
    assert result.is_valid is False

# GOOD - parametrized test
@pytest.mark.asyncio
@pytest.mark.parametrize("email,expected", [
    ("user@example.com", True),
    ("user@mail.example.com", True),
    ("userexample.com", False),
    ("user@", False),
])
async def test_validate_email(email, expected):
    result = validate_email(email)
    assert result.is_valid is expected
```

### 2. Unclear Parametrize Names

**Problem**: Using generic names like "input" and "output" instead of descriptive names.

```python
# BAD - unclear parameter names
@pytest.mark.parametrize("input,output", [
    (10, 100),
    (5, 25),
    (0, 0),
])
def test_calculation(input, output):
    assert calculate(input) == output

# GOOD - descriptive parameter names
@pytest.mark.parametrize("radius,expected_area", [
    (10, 314.159),
    (5, 78.539),
    (0, 0),
])
def test_circle_area(radius, expected_area):
    assert calculate_area(radius) == pytest.approx(expected_area, rel=1e-3)
```

### 3. Not Using pytest.param for IDs

**Problem**: Test output shows cryptic parameter values instead of meaningful descriptions.

```python
# BAD - unclear test IDs in output
@pytest.mark.parametrize("user_role,can_access", [
    ("admin", True),
    ("user", False),
    ("guest", False),
])
def test_access_control(user_role, can_access):
    assert check_access(user_role) == can_access
# Output: test_access_control[admin-True], test_access_control[user-False]

# GOOD - descriptive test IDs
@pytest.mark.parametrize("user_role,can_access", [
    pytest.param("admin", True, id="admin_has_access"),
    pytest.param("user", False, id="user_denied"),
    pytest.param("guest", False, id="guest_denied"),
])
def test_access_control(user_role, can_access):
    assert check_access(user_role) == can_access
# Output: test_access_control[admin_has_access], test_access_control[user_denied]
```

### 4. Not Combining Multiple Parametrize Decorators

**Problem**: Creating cartesian product manually instead of stacking decorators.

```python
# BAD - manual combinations
@pytest.mark.parametrize("method,status,role", [
    ("GET", 200, "admin"),
    ("GET", 200, "user"),
    ("POST", 200, "admin"),
    ("POST", 403, "user"),
    ("DELETE", 200, "admin"),
    ("DELETE", 403, "user"),
])
def test_api_access(method, status, role):
    assert api_call(method, role).status_code == status

# GOOD - stacked parametrize for cartesian product
@pytest.mark.parametrize("method", ["GET", "POST", "DELETE"])
@pytest.mark.parametrize("role,expected_statuses", [
    ("admin", {"GET": 200, "POST": 200, "DELETE": 200}),
    ("user", {"GET": 200, "POST": 403, "DELETE": 403}),
])
def test_api_access(method, role, expected_statuses):
    assert api_call(method, role).status_code == expected_statuses[method]

# ALTERNATIVE - if all admins succeed and users fail writes
@pytest.mark.parametrize("method", ["GET", "POST", "DELETE"])
@pytest.mark.parametrize("role,can_write", [
    ("admin", True),
    ("user", False),
])
def test_api_access(method, role, can_write):
    response = api_call(method, role)
    if method in ["POST", "DELETE"] and not can_write:
        assert response.status_code == 403
    else:
        assert response.status_code == 200
```

### 5. Parametrizing Fixtures Instead of Tests

**Problem**: Complex parametrized fixtures when parametrized tests would be clearer.

```python
# BAD - parametrized fixture is hard to read
@pytest.fixture(params=[
    {"name": "Alice", "role": "admin", "can_delete": True},
    {"name": "Bob", "role": "user", "can_delete": False},
])
def user(request):
    return User(**request.param)

def test_user_permissions(user):
    assert user.can_delete() == user.expected_can_delete

# GOOD - parametrize the test
@pytest.fixture
def make_user():
    def _make(name: str, role: str):
        return User(name=name, role=role)
    return _make

@pytest.mark.parametrize("name,role,can_delete", [
    ("Alice", "admin", True),
    ("Bob", "user", False),
])
def test_user_permissions(make_user, name, role, can_delete):
    user = make_user(name, role)
    assert user.can_delete() == can_delete
```

### 6. Not Marking Expected Failures

**Problem**: Including known failing cases without marking them.

```python
# BAD - test fails on known edge case
@pytest.mark.parametrize("input,expected", [
    ("valid", True),
    ("also_valid", True),
    ("edge_case", True),  # This actually fails but is being worked on
])
def test_validator(input, expected):
    assert validate(input) == expected

# GOOD - mark expected failures
@pytest.mark.parametrize("input,expected", [
    ("valid", True),
    ("also_valid", True),
    pytest.param("edge_case", True, marks=pytest.mark.xfail(reason="Issue #123")),
])
def test_validator(input, expected):
    assert validate(input) == expected
```

### 7. Large Parametrize Tables in Test File

**Problem**: Test file cluttered with large data tables.

```python
# BAD - 100 lines of test data inline
@pytest.mark.parametrize("input,expected", [
    ("case1", "result1"),
    ("case2", "result2"),
    # ... 100 more lines ...
])
def test_parser(input, expected):
    assert parse(input) == expected

# GOOD - externalize large datasets
# test_data/parser_cases.json
[
    {"input": "case1", "expected": "result1"},
    {"input": "case2", "expected": "result2"}
]

# test_parser.py
import json
from pathlib import Path

def load_test_cases():
    path = Path(__file__).parent / "test_data" / "parser_cases.json"
    with open(path) as f:
        cases = json.load(f)
    return [(c["input"], c["expected"]) for c in cases]

@pytest.mark.parametrize("input,expected", load_test_cases())
def test_parser(input, expected):
    assert parse(input) == expected
```

### 8. Not Using Indirect Parametrization

**Problem**: Creating expensive test data for every parameter combination.

```python
# BAD - creating full database for each test
@pytest.mark.parametrize("user_id,expected_name", [
    (1, "Alice"),
    (2, "Bob"),
    (3, "Charlie"),
])
async def test_get_user(user_id, expected_name):
    db = await create_full_database()  # Expensive! Runs 3 times!
    user = await db.get_user(user_id)
    assert user.name == expected_name

# GOOD - indirect parametrization with fixture
@pytest.fixture
async def db_with_users():
    db = await create_full_database()
    yield db
    await db.cleanup()

@pytest.mark.parametrize("user_id,expected_name", [
    (1, "Alice"),
    (2, "Bob"),
    (3, "Charlie"),
])
async def test_get_user(db_with_users, user_id, expected_name):
    user = await db_with_users.get_user(user_id)
    assert user.name == expected_name

# EVEN BETTER - indirect parametrization
@pytest.fixture
async def user(request, db):
    user_id = request.param
    return await db.get_user(user_id)

@pytest.mark.parametrize("user,expected_name", [
    (1, "Alice"),
    (2, "Bob"),
    (3, "Charlie"),
], indirect=["user"])
async def test_user_name(user, expected_name):
    assert user.name == expected_name
```

### 9. Testing Multiple Assertions Instead of Separating

**Problem**: Multiple unrelated assertions in one parametrized test.

```python
# BAD - multiple unrelated assertions
@pytest.mark.parametrize("user_data", [
    {"name": "Alice", "age": 30, "role": "admin"},
    {"name": "Bob", "age": 25, "role": "user"},
])
def test_user(user_data):
    user = User(**user_data)
    assert user.name == user_data["name"]
    assert user.age == user_data["age"]
    assert user.role == user_data["role"]
    assert user.is_valid()  # Unrelated to data validation
    assert len(user.name) > 0  # Different concern

# GOOD - separate tests for different concerns
@pytest.mark.parametrize("name,age,role", [
    ("Alice", 30, "admin"),
    ("Bob", 25, "user"),
])
def test_user_creation(name, age, role):
    user = User(name=name, age=age, role=role)
    assert user.name == name
    assert user.age == age
    assert user.role == role

@pytest.mark.parametrize("name", ["Alice", "Bob", ""])
def test_user_name_validation(name):
    if name:
        user = User(name=name, age=30, role="user")
        assert user.is_valid()
    else:
        with pytest.raises(ValueError):
            User(name=name, age=30, role="user")
```

## Review Questions

1. Can duplicated test functions be combined with parametrize?
2. Do parametrized tests use descriptive parameter names?
3. Are test IDs meaningful using pytest.param(id="...")?
4. Should multiple parametrize decorators be stacked for combinations?
5. Are large test datasets externalized to separate files?
6. Is indirect parametrization used for expensive fixture setup?
