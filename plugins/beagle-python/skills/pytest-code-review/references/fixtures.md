# Fixtures

## Critical Anti-Patterns

### 1. Duplicated Setup Across Tests

**Problem**: Same setup repeated in every test function instead of using fixtures.

```python
# BAD - duplicated setup
@pytest.mark.asyncio
async def test_create_user():
    db = await create_db_connection()
    await db.setup_schema()
    result = await create_user(db, "Alice")
    await db.close()
    assert result.name == "Alice"

@pytest.mark.asyncio
async def test_delete_user():
    db = await create_db_connection()
    await db.setup_schema()
    result = await delete_user(db, 1)
    await db.close()
    assert result.success

# GOOD - fixture handles setup/teardown
@pytest.fixture
async def db():
    connection = await create_db_connection()
    await connection.setup_schema()
    yield connection
    await connection.close()

@pytest.mark.asyncio
async def test_create_user(db):
    result = await create_user(db, "Alice")
    assert result.name == "Alice"

@pytest.mark.asyncio
async def test_delete_user(db):
    result = await delete_user(db, 1)
    assert result.success
```

### 2. Missing Cleanup in Fixtures

**Problem**: Resources leak when tests fail or fixtures don't clean up.

```python
# BAD - no cleanup
@pytest.fixture
async def temp_file():
    file_path = "/tmp/test_file.txt"
    async with aiofiles.open(file_path, "w") as f:
        await f.write("test data")
    return file_path
    # File never deleted!

# GOOD - cleanup with yield
@pytest.fixture
async def temp_file():
    file_path = "/tmp/test_file.txt"
    async with aiofiles.open(file_path, "w") as f:
        await f.write("test data")
    yield file_path
    # Cleanup always runs
    if os.path.exists(file_path):
        os.remove(file_path)
```

### 3. Wrong Fixture Scope

**Problem**: Expensive setup repeated unnecessarily or shared state causes test coupling.

```python
# BAD - function scope for expensive operation
@pytest.fixture(scope="function")  # Runs for EVERY test!
def database_with_seed_data():
    db = create_database()
    seed_large_dataset(db)  # Takes 10 seconds!
    return db

# GOOD - module scope for expensive, read-only setup
@pytest.fixture(scope="module")
def database_with_seed_data():
    db = create_database()
    seed_large_dataset(db)
    yield db
    db.cleanup()

# BAD - session scope for mutable state
@pytest.fixture(scope="session")
def user_cache():
    return {}  # Shared across ALL tests - race conditions!

# GOOD - function scope for mutable state
@pytest.fixture(scope="function")
def user_cache():
    return {}  # Fresh cache per test
```

### 4. Not Using conftest.py

**Problem**: Fixtures duplicated across test files.

```python
# BAD - fixture in test_users.py
@pytest.fixture
def db_session():
    session = create_session()
    yield session
    session.close()

# BAD - same fixture duplicated in test_posts.py
@pytest.fixture
def db_session():
    session = create_session()
    yield session
    session.close()

# GOOD - shared fixture in conftest.py
# conftest.py
@pytest.fixture
def db_session():
    session = create_session()
    yield session
    session.close()

# test_users.py and test_posts.py can both use db_session
```

### 5. Factory Fixtures Not Used for Variations

**Problem**: Creating multiple similar fixtures instead of one factory.

```python
# BAD - separate fixture for each variation
@pytest.fixture
def user_alice():
    return User(name="Alice", role="admin")

@pytest.fixture
def user_bob():
    return User(name="Bob", role="user")

@pytest.fixture
def user_charlie():
    return User(name="Charlie", role="guest")

# GOOD - factory fixture
@pytest.fixture
def make_user():
    def _make_user(name: str, role: str = "user"):
        return User(name=name, role=role)
    return _make_user

def test_admin_access(make_user):
    admin = make_user("Alice", role="admin")
    assert admin.can_delete()

def test_user_access(make_user):
    user = make_user("Bob")
    assert not user.can_delete()
```

### 6. Fixture Dependencies Not Leveraged

**Problem**: Manually composing dependencies instead of using fixture chaining.

```python
# BAD - manual composition
@pytest.fixture
def authenticated_client():
    app = create_app()
    client = TestClient(app)
    user = create_user()
    token = generate_token(user)
    client.headers["Authorization"] = f"Bearer {token}"
    return client

# GOOD - fixture chaining
@pytest.fixture
def app():
    return create_app()

@pytest.fixture
def client(app):
    return TestClient(app)

@pytest.fixture
def user():
    return create_user()

@pytest.fixture
def auth_token(user):
    return generate_token(user)

@pytest.fixture
def authenticated_client(client, auth_token):
    client.headers["Authorization"] = f"Bearer {auth_token}"
    return client
```

### 7. Autouse Fixtures Overused

**Problem**: Autouse fixtures run even when not needed, slowing tests.

```python
# BAD - autouse for specific setup
@pytest.fixture(autouse=True)
def setup_database():
    # Runs for EVERY test, even ones that don't use database
    db = setup_test_db()
    yield
    db.teardown()

# GOOD - explicit fixture dependency
@pytest.fixture
def database():
    db = setup_test_db()
    yield db
    db.teardown()

def test_with_db(database):
    # Only runs when explicitly requested
    assert database.is_connected()

def test_without_db():
    # Doesn't pay database setup cost
    assert 1 + 1 == 2
```

### 8. Async Fixtures Without Proper Cleanup

**Problem**: Async cleanup not wrapped in try/finally.

```python
# BAD - no try/finally in async fixture
@pytest.fixture
async def api_client():
    client = AsyncClient(base_url="http://test")
    yield client
    await client.close()  # Skipped if test fails!

# GOOD - try/finally ensures cleanup
@pytest.fixture
async def api_client():
    client = AsyncClient(base_url="http://test")
    try:
        yield client
    finally:
        await client.close()
```

### 9. Using Fixtures as Data Instead of Setup

**Problem**: Fixtures return data instead of managing resources.

```python
# BAD - fixture just returns data
@pytest.fixture
def sample_users():
    return [
        {"name": "Alice", "role": "admin"},
        {"name": "Bob", "role": "user"}
    ]

# GOOD - use module-level constant
SAMPLE_USERS = [
    {"name": "Alice", "role": "admin"},
    {"name": "Bob", "role": "user"}
]

# ACCEPTABLE - fixture when setup/teardown needed
@pytest.fixture
async def sample_users(db):
    users = await db.create_users([
        {"name": "Alice", "role": "admin"},
        {"name": "Bob", "role": "user"}
    ])
    yield users
    await db.delete_users([u.id for u in users])
```

## Review Questions

1. Are fixtures in conftest.py for cross-file reuse?
2. Do all fixtures with resources have proper yield + cleanup?
3. Is fixture scope appropriate (function/module/session)?
4. Are factory fixtures used for creating test data variations?
5. Are fixture dependencies chained instead of manually composed?
6. Are autouse fixtures limited to truly universal setup?
7. Do async fixtures wrap cleanup in try/finally blocks?
