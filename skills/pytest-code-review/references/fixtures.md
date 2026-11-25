# Fixtures

## Critical Anti-Patterns

### 1. Hardcoded `/tmp` Paths or Missing Teardown in Yield Fixtures

**Problem**: Hardcoded paths like `/tmp/shared_fixture.txt` collide across parallel `pytest -n auto` workers and leak files; missing `try`/`finally` in async/sync yield fixtures skips cleanup when a test raises or fails during setup/assertion.

```python
# BAD - hardcoded /tmp path and no cleanup on failure
@pytest.fixture
async def temp_file():
    file_path = "/tmp/shared_fixture.txt"
    async with aiofiles.open(file_path, "w") as f:
        await f.write("test data")
    return file_path

# GOOD - use pytest built-in tmp_path (unique per test, auto-cleaned)
@pytest.fixture
async def temp_file(tmp_path):
    file_path = tmp_path / "test_file.txt"
    async with aiofiles.open(file_path, "w") as f:
        await f.write("test data")
    return file_path

# GOOD - async yield fixture with try/finally cleanup
# (Use @pytest_asyncio.fixture in strict mode, or @pytest.fixture in asyncio_mode="auto")
@pytest.fixture
async def api_client():
    client = AsyncClient(base_url="http://test")
    try:
        yield client
    finally:
        await client.aclose()
```

### 2. Wrong Fixture Scope (Shared Mutable State vs Expensive Read-Only Setup)

**Problem**: Sharing mutable state in `module`/`session` scope couples tests together; putting slow read-only DB seeding in `function` scope slows the whole suite.

```python
# BAD - session scope returning mutable dict causes cross-test state leaks
@pytest.fixture(scope="session")
def user_cache():
    return {}

# GOOD - function scope (default) for mutable state
@pytest.fixture
def user_cache():
    return {}

# GOOD - module/session scope only for expensive, read-only or transaction-rolled-back setup
@pytest.fixture(scope="module")
def seeded_lookup_db():
    db = create_database()
    seed_readonly_reference_data(db)
    try:
        yield db
    finally:
        db.cleanup()
```

### 3. Proliferating Near-Identical Fixtures Instead of Factory Fixtures

**Problem**: Maintaining separate fixtures (`user_alice`, `user_bob`, `user_charlie`) obscures test intent and scales poorly.

```python
# BAD - separate fixture per variant
@pytest.fixture
def user_alice():
    return User(name="Alice", role="admin")

@pytest.fixture
def user_bob():
    return User(name="Bob", role="user")

# GOOD - factory fixture (can also track created objects for teardown)
@pytest.fixture
def make_user():
    def _make_user(name: str, role: str = "user") -> User:
        return User(name=name, role=role)
    return _make_user
```

### 4. Overusing `autouse=True` Fixtures

**Problem**: `autouse=True` fixtures run for every test in scope (even pure unit tests that don't use the resource) and hide test dependencies.

```python
# BAD - runs heavy DB setup even for unit tests
@pytest.fixture(autouse=True)
def setup_database():
    db = setup_test_db()
    yield
    db.teardown()

# GOOD - explicit fixture parameter where needed
@pytest.fixture
def database():
    db = setup_test_db()
    try:
        yield db
    finally:
        db.teardown()
```

### 5. Duplicated Fixtures Across Test Files

**Problem**: Copy-pasting the same `db_session` or `client` fixture across multiple `test_*.py` files leads to drift; place shared fixtures in the nearest `conftest.py` and compose them via fixture chaining rather than rebuilding setup manually.

## Review Questions

1. Do file-creating fixtures use `tmp_path` instead of hardcoded `/tmp` paths?
2. Do yield fixtures (especially async ones) wrap cleanup in `try`/`finally` and use `@pytest_asyncio.fixture` when in `strict` mode?
3. Is fixture scope appropriate (`function` for mutable state, `module`/`session` only for read-only/isolated expensive setup)?
4. Are `autouse=True` fixtures restricted to truly universal hygiene (e.g., resetting global caches)?
5. Are cross-file fixtures centralized in `conftest.py`?
