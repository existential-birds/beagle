# Sessions

## Critical Anti-Patterns

### 1. Session Not Closed

**Problem**: Connection pool exhaustion, memory leaks.

```python
# BAD - session never closed
def get_user(user_id: int):
    session = Session()
    user = session.get(User, user_id)
    return user  # Session leaked!

# GOOD - using context manager
def get_user(user_id: int) -> User | None:
    with Session() as session:
        user = session.get(User, user_id)
        return user
```

### 2. Session Shared Across Requests

**Problem**: Concurrent modifications, race conditions, data corruption.

```python
# BAD - global session shared across requests
session = Session()  # Module-level!

@app.get("/users/{user_id}")
async def get_user(user_id: int):
    user = session.get(User, user_id)  # Multiple requests share session!
    return user

# GOOD - request-scoped session
from contextlib import asynccontextmanager

@asynccontextmanager
async def get_db_session():
    async with AsyncSession() as session:
        try:
            yield session
        finally:
            await session.close()

@app.get("/users/{user_id}")
async def get_user(user_id: int, session = Depends(get_db_session)):
    user = await session.get(User, user_id)
    return user
```

### 3. Manual Commit Without Rollback Handling

**Problem**: Partial commits, inconsistent state on errors.

```python
# BAD - no rollback on error
def create_user(name: str, email: str):
    session = Session()
    user = User(name=name, email=email)
    session.add(user)
    session.commit()  # If this fails, session corrupted
    session.close()
    return user

# GOOD - proper error handling
def create_user(name: str, email: str) -> User:
    with Session() as session:
        try:
            user = User(name=name, email=email)
            session.add(user)
            session.commit()
            return user
        except Exception:
            session.rollback()
            raise
```

### 4. Using Sync Session in Async Context

**Problem**: Blocks event loop, poor performance.

```python
# BAD - blocking sync session in async
from sqlalchemy.orm import Session

async def get_user(user_id: int):
    with Session() as session:  # Blocks event loop!
        user = session.get(User, user_id)
        return user

# GOOD - async session
from sqlalchemy.ext.asyncio import AsyncSession

async def get_user(user_id: int) -> User | None:
    async with AsyncSession() as session:
        result = await session.execute(
            select(User).where(User.id == user_id)
        )
        return result.scalar_one_or_none()
```

### 5. Session Used After Commit

**Problem**: DetachedInstanceError, expired objects.

```python
# BAD - accessing object after session closed
def get_user_data(user_id: int):
    with Session() as session:
        user = session.get(User, user_id)
    return user.email  # DetachedInstanceError! Session closed

# GOOD - access data before session closes
def get_user_data(user_id: int) -> str | None:
    with Session() as session:
        user = session.get(User, user_id)
        if user:
            return user.email
        return None

# BETTER - use expunge or eager loading
from sqlalchemy.orm import joinedload

def get_user_with_posts(user_id: int) -> User | None:
    with Session() as session:
        user = session.execute(
            select(User)
            .options(joinedload(User.posts))
            .where(User.id == user_id)
        ).scalar_one_or_none()

        if user:
            session.expunge(user)  # Detach from session
        return user
```

### 6. Not Using Session.begin() for Transactions

**Problem**: AutoCommit confusion, no explicit transaction boundaries.

```python
# BAD - implicit transaction boundaries
def transfer_money(from_id: int, to_id: int, amount: float):
    with Session() as session:
        from_account = session.get(Account, from_id)
        to_account = session.get(Account, to_id)

        from_account.balance -= amount
        session.commit()  # First commit

        to_account.balance += amount
        session.commit()  # Second commit - money lost if this fails!

# GOOD - explicit transaction with begin()
def transfer_money(from_id: int, to_id: int, amount: float):
    with Session() as session:
        with session.begin():
            from_account = session.get(Account, from_id)
            to_account = session.get(Account, to_id)

            if from_account.balance < amount:
                raise ValueError("Insufficient funds")

            from_account.balance -= amount
            to_account.balance += amount
            # Both committed together or rolled back together

# ASYNC version
async def transfer_money(from_id: int, to_id: int, amount: float):
    async with AsyncSession() as session:
        async with session.begin():
            result = await session.execute(
                select(Account).where(Account.id.in_([from_id, to_id]))
            )
            accounts = {acc.id: acc for acc in result.scalars()}

            from_account = accounts[from_id]
            to_account = accounts[to_id]

            if from_account.balance < amount:
                raise ValueError("Insufficient funds")

            from_account.balance -= amount
            to_account.balance += amount
```

### 7. Session Factory Not Configured Properly

**Problem**: Inconsistent session behavior, connection issues.

```python
# BAD - new engine every time
def get_session():
    engine = create_engine("postgresql://...")  # New engine each call!
    Session = sessionmaker(bind=engine)
    return Session()

# GOOD - reuse engine and session factory
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Module level - create once
engine = create_engine(
    "postgresql://...",
    pool_pre_ping=True,  # Verify connections
    pool_size=10,
    max_overflow=20
)

SessionLocal = sessionmaker(
    bind=engine,
    expire_on_commit=False,  # Don't expire objects on commit
    autocommit=False,
    autoflush=False
)

def get_session():
    return SessionLocal()

# ASYNC version
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession

async_engine = create_async_engine(
    "postgresql+asyncpg://...",
    pool_pre_ping=True,
    pool_size=10
)

AsyncSessionLocal = sessionmaker(
    async_engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False
)

async def get_async_session():
    async with AsyncSessionLocal() as session:
        yield session
```

### 8. Missing Session Refresh After Background Operations

**Problem**: Stale data when session persists across long operations.

```python
# BAD - using stale session data
async def process_order(order_id: int):
    async with AsyncSession() as session:
        order = await session.get(Order, order_id)

        # Long running background task
        await process_payment(order.id)  # Another process might update order

        # order.status might be stale here!
        if order.status == "pending":
            order.status = "completed"
            await session.commit()

# GOOD - refresh after external operations
async def process_order(order_id: int):
    async with AsyncSession() as session:
        order = await session.get(Order, order_id)

        await process_payment(order.id)

        # Refresh to get latest state
        await session.refresh(order)

        if order.status == "pending":
            order.status = "completed"
            await session.commit()
```

## Review Questions

1. Are all sessions using context managers (`with` or `async with`)?
2. Is each request/thread getting its own session instance?
3. Are transactions using explicit `session.begin()`?
4. Are async contexts using `AsyncSession` not sync `Session`?
5. Are objects accessed before the session closes?
6. Is the session factory configured once and reused?
