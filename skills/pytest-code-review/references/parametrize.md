# Parametrize

## Critical Anti-Patterns

### 1. Duplicated Test Functions for Input/Output Variations

**Problem**: Copy-pasted test functions differing only in inputs/expected results bloat test suites and miss edge cases.

```python
# BAD - duplicated test functions
def test_validate_email_valid():
    assert validate_email("user@example.com").is_valid is True

def test_validate_email_invalid():
    assert validate_email("userexample.com").is_valid is False

# GOOD - parametrized with descriptive pytest.param IDs
@pytest.mark.parametrize(
    "email,expected",
    [
        pytest.param("user@example.com", True, id="valid_standard"),
        pytest.param("user@mail.example.com", True, id="valid_subdomain"),
        pytest.param("userexample.com", False, id="missing_at"),
        pytest.param("user@", False, id="missing_domain"),
    ],
)
def test_validate_email(email: str, expected: bool):
    assert validate_email(email).is_valid is expected
```

### 2. Cryptic Test IDs or Unmarked Known Failures

**Problem**: Long or non-string parameter values produce unreadable node IDs (`[dict0]`), and unskipped known failures pollute CI runs.

```python
@pytest.mark.parametrize(
    "raw_input,expected",
    [
        pytest.param("valid", True, id="valid_input"),
        pytest.param(
            "known_bug_case",
            True,
            id="known_bug",
            marks=pytest.mark.xfail(reason="Issue #123", strict=True),
        ),
    ],
)
def test_validator(raw_input: str, expected: bool):
    assert validate(raw_input) is expected
```

### 3. Manual Cartesian Products Instead of Stacked Decorators

**Problem**: Manually enumerating `M × N` combinations duplicates cases and misses pairs when adding a new axis value.

```python
# GOOD - stack @pytest.mark.parametrize for clean combinations
@pytest.mark.parametrize("method", ["GET", "POST", "DELETE"])
@pytest.mark.parametrize(
    "role,can_write",
    [
        pytest.param("admin", True, id="admin"),
        pytest.param("user", False, id="user"),
    ],
)
def test_api_access(method: str, role: str, can_write: bool):
    response = api_call(method, role)
    if method in {"POST", "DELETE"} and not can_write:
        assert response.status_code == 403
    else:
        assert response.status_code == 200
```

### 4. Rebuilding Expensive Fixture Setup Inside Each Parametrized Case

**Problem**: Creating a DB/app inside the test body repeats setup per parameter; instead share a fixture or use `indirect=["..."]` when the fixture itself needs parameterizing.

```python
@pytest.fixture
async def seeded_user(request, db):
    return await db.get_user(request.param)

@pytest.mark.parametrize(
    "seeded_user,expected_name",
    [
        (1, "Alice"),
        (2, "Bob"),
    ],
    indirect=["seeded_user"],
)
async def test_user_name(seeded_user, expected_name: str):
    assert seeded_user.name == expected_name
```

### 5. Packing Unrelated Concerns Into One Parametrized Test

**Problem**: Branching inside a parametrized test to verify unrelated behaviors hides failures and makes parameters hard to read. Split distinct behaviors (e.g., valid creation vs error validation) into separate focused tests.

## Review Questions

1. Can duplicated test functions be consolidated with `@pytest.mark.parametrize`?
2. Are complex or non-primitive cases labeled with `pytest.param(..., id=...)`?
3. Are multi-axis combinations expressed with stacked `@pytest.mark.parametrize` decorators?
4. Are fixture-driven variations using `indirect=[...]` cleanly instead of repeating setup inside the test body?
