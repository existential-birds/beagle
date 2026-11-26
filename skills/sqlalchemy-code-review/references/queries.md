# Queries

## Critical Anti-Patterns

### 1. Using Legacy `query()` Instead of `select()`

**Problem**: `session.query()` is the legacy 1.x API, deprecated in SQLAlchemy 2.0.

```python
# BAD - legacy query() API
def get_active_users(session):
    return session.query(User).filter(User.active.is_(True)).all()

# GOOD - SQLAlchemy 2.0 select() syntax
from sqlalchemy import select

def get_active_users(session):
    result = session.execute(
        select(User).where(User.active.is_(True))
    )
    return result.scalars().all()

# ASYNC version (using configured AsyncSessionLocal)
async def get_active_users(AsyncSessionLocal):
    async with AsyncSessionLocal() as session:
        result = await session.execute(
            select(User).where(User.active.is_(True))
        )
        return result.scalars().all()
```

### 2. Loading Full ORM Objects When Only Columns Are Needed

**Problem**: Materializing full ORM instances for a single field wastes memory and CPU.

```python
# BAD - loads full ORM models just for emails
def get_user_emails(session):
    users = session.execute(select(User)).scalars().all()
    return [user.email for user in users]

# GOOD - select only needed columns
def get_user_emails(session):
    return session.execute(select(User.email)).scalars().all()

# Multiple columns as tuples / Row objects
def get_user_info(session):
    return session.execute(
        select(User.id, User.name, User.email)
    ).all()
```

### 3. Using `.all()` When Expecting a Single Row

**Problem**: Indexing `[0]` after `.all()` misses multiplicity checks and loads extra rows.

```python
# BAD
def get_user_by_email(session, email: str):
    users = session.execute(
        select(User).where(User.email == email)
    ).scalars().all()
    return users[0] if users else None

# GOOD - scalar_one_or_none() or scalar_one()
def get_user_by_email(session, email: str) -> User | None:
    return session.execute(
        select(User).where(User.email == email)
    ).scalar_one_or_none()

def get_user_by_id(session, user_id: int) -> User:
    return session.execute(
        select(User).where(User.id == user_id)
    ).scalar_one()  # Raises NoResultFound or MultipleResultsFound
```

### 4. Not Using Core `insert()` for Bulk Inserts

**Problem**: Calling `session.add()` in a loop incurs per-object ORM identity-map overhead. (In SQLAlchemy 2.0, `session.execute(insert(User), data)` replaces legacy 1.x `bulk_insert_mappings`.)

```python
# BAD - ORM add in loop
def create_users(session, user_data: list[dict]):
    for data in user_data:
        session.add(User(**data))
    session.commit()

# GOOD - SQLAlchemy 2.0 Core insert() bulk DML
from sqlalchemy import insert

def create_users(session, user_data: list[dict]):
    session.execute(insert(User), user_data)
    session.commit()

# ASYNC bulk insert
async def create_users(AsyncSessionLocal, user_data: list[dict]):
    async with AsyncSessionLocal() as session:
        await session.execute(insert(User), user_data)
        await session.commit()
```

### 5. Not Using Core `update()` for Bulk Updates

**Problem**: Loading rows into Python just to mutate one column emits N `UPDATE` statements.

```python
# BAD - load and update in loop
def deactivate_old_users(session, cutoff_date):
    users = session.execute(
        select(User).where(User.last_login < cutoff_date)
    ).scalars().all()
    for user in users:
        user.active = False
    session.commit()

# GOOD - single UPDATE statement
from sqlalchemy import update

async def deactivate_old_users(AsyncSessionLocal, cutoff_date):
    async with AsyncSessionLocal() as session:
        await session.execute(
            update(User)
            .where(User.last_login < cutoff_date)
            .values(active=False)
        )
        await session.commit()
```

### 6. Not Using `exists()` for Existence Checks

**Problem**: Fetching full rows just to check `is not None`.

```python
# BAD
def user_exists(session, email: str) -> bool:
    user = session.execute(
        select(User).where(User.email == email)
    ).scalar_one_or_none()
    return user is not None

# GOOD - SELECT EXISTS(...)
from sqlalchemy import exists, select

def user_exists(session, email: str) -> bool:
    return bool(
        session.execute(
            select(exists().where(User.email == email))
        ).scalar()
    )
```

### 7. Missing Pagination or Streaming on Large Result Sets

**Problem**: Unbounded `.all()` risks OOM on large tables; large `OFFSET` scans get slow.

```python
# BAD - unbounded load
def get_all_users(session):
    return session.execute(select(User)).scalars().all()

# GOOD - keyset pagination for large datasets
def get_users_after(session, last_id: int | None = None, page_size: int = 100):
    query = select(User).order_by(User.id)
    if last_id is not None:
        query = query.where(User.id > last_id)
    return session.execute(query.limit(page_size)).scalars().all()

# GOOD - streaming with yield_per
def stream_all_users(session):
    result = session.execute(select(User).execution_options(yield_per=1000))
    for user in result.scalars():
        yield user
```

### 8. Missing `with_for_update()` for Read-Modify-Write Updates

**Problem**: Concurrent read-then-write updates lose increments/decrements without row locking.

```python
# BAD - race condition between read and commit
def decrement_stock(session, product_id: int, quantity: int):
    product = session.execute(
        select(Product).where(Product.id == product_id)
    ).scalar_one()
    if product.stock >= quantity:
        product.stock -= quantity
        session.commit()
    else:
        raise ValueError("Insufficient stock")

# GOOD - row-level lock with_for_update()
async def decrement_stock(AsyncSessionLocal, product_id: int, quantity: int):
    async with AsyncSessionLocal() as session:
        async with session.begin():
            result = await session.execute(
                select(Product)
                .where(Product.id == product_id)
                .with_for_update()
            )
            product = result.scalar_one()
            if product.stock >= quantity:
                product.stock -= quantity
            else:
                raise ValueError("Insufficient stock")
```

### 9. Unparameterized Raw SQL vs Type-Safe Column Filters

**Problem**: Interpolating user input into raw SQL strings causes critical SQL injection vulnerabilities. (`filter_by(name=name)` binds parameters safely and is NOT a SQL injection risk, though `.where(User.name == name)` is preferred for static type checking and complex expressions.)

```python
# CRITICAL - SQL injection via string interpolation
def search_users_unsafe(session, name: str):
    return session.execute(
        text(f"SELECT * FROM users WHERE name = '{name}'")  # NEVER DO THIS!
    ).all()

# GOOD - parameterized text() if raw SQL is required
from sqlalchemy import text

def search_users_raw(session, name: str):
    return session.execute(
        text("SELECT * FROM users WHERE name = :name"),
        {"name": name},
    ).all()

# BEST - type-safe column expressions with .where()
def search_users(session, name: str):
    return session.execute(
        select(User).where(User.name == name)
    ).scalars().all()
```

### 10. Multiple Round-Trips Instead of Joins or Subqueries

**Problem**: Running a query to collect IDs and a second query with `IN (...)` wastes a round-trip and fails on huge ID lists.

```python
from datetime import datetime, timedelta, timezone

# BAD - two round-trips with naive datetime.now()
def get_users_with_recent_posts(session):
    cutoff = datetime.now() - timedelta(days=7)  # Naive datetime!
    user_ids = session.execute(
        select(Post.user_id).where(Post.created_at > cutoff).distinct()
    ).scalars().all()
    return session.execute(select(User).where(User.id.in_(user_ids))).scalars().all()

# GOOD - single join query with timezone-aware UTC datetime
def get_users_with_recent_posts(session):
    cutoff = datetime.now(timezone.utc) - timedelta(days=7)
    return session.execute(
        select(User)
        .join(Post)
        .where(Post.created_at > cutoff)
        .distinct()
    ).scalars().all()
```

### 11. Not Using `union_all` for Combined Read Feeds

**Problem**: Fetching two homogeneous result sets separately when a single `union_all` suffices.

```python
from sqlalchemy import literal, select, union_all

def get_all_content_items(session):
    posts_query = select(
        Post.id,
        Post.title,
        Post.created_at,
        literal("post").label("type"),
    )
    pages_query = select(
        Page.id,
        Page.title,
        Page.created_at,
        literal("page").label("type"),
    )
    return session.execute(union_all(posts_query, pages_query)).all()
```

## Review Questions

1. Are queries using SQLAlchemy 2.0 `select()` instead of legacy `query()`?
2. Do bulk inserts/updates use `insert()` / `update()` instead of ORM loops or legacy `bulk_insert_mappings`?
3. Are only required columns selected when full ORM models aren't needed?
4. Is `exists()` used for existence checks and keyset pagination/`yield_per` for large datasets?
5. Is `with_for_update()` used for read-modify-write concurrency?
6. Are all raw SQL statements wrapped in `text()` with bound parameters (never f-strings)?
7. Are timestamps timezone-aware (`datetime.now(timezone.utc)`)?
