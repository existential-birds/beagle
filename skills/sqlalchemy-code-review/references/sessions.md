# Sessions

## Critical Anti-Patterns

### 1. Session Not Closed

**Problem**: Unclosed sessions exhaust the connection pool and leak memory.

```python
# BAD - session never closed
def get_user(SessionLocal, user_id: int):
    session = SessionLocal()
    return session.get(User, user_id)

# GOOD - using context manager
def get_user(SessionLocal, user_id: int) -> User | None:
    with SessionLocal() as session:
        return session.get(User, user_id)
```

### 2. Session Shared Across Requests

**Problem**: Module-level sessions cause concurrent state corruption and race conditions.

```python
# BAD - global session shared across requests
session = SessionLocal()

@app.get("/users/{user_id}")
async def get_user(user_id: int):
    return session.get(User, user_id)

# GOOD - request-scoped async session from configured async_sessionmaker
from collections.abc import AsyncIterator
from typing import Annotated
from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

async def get_db_session() -> AsyncIterator[AsyncSession]:
    async with AsyncSessionLocal() as session:
        yield session

@app.get("/users/{user_id}")
async def get_user(
    user_id: int,
    session: Annotated[AsyncSession, Depends(get_db_session)],
):
    return await session.get(User, user_id)
```

### 3. Manual Commit Without Rollback Handling

**Problem**: Leaving failed transactions unrolled-back leaves sessions in an invalid state.

```python
# BAD - no rollback on error
def create_user(SessionLocal, name: str, email: str):
    session = SessionLocal()
    user = User(name=name, email=email)
    session.add(user)
    session.commit()  # If this fails, session is invalidated and leaked!
    session.close()
    return user

# GOOD - context manager + rollback on exception (or with session.begin():)
def create_user(SessionLocal, name: str, email: str) -> User:
    with SessionLocal() as session:
        try:
            user = User(name=name, email=email)
            session.add(user)
            session.commit()
            return user
        except Exception:
            session.rollback()
            raise
```

### 4. Using Sync `Session` in Async Context

**Problem**: Synchronous SQLAlchemy inside `async def` blocks the asyncio event loop.

```python
# BAD - blocking sync session inside async def
from sqlalchemy.orm import Session

async def get_user(SessionLocal, user_id: int):
    with SessionLocal() as session:  # Blocks event loop!
        return session.get(User, user_id)

# GOOD - async session from async_sessionmaker
from sqlalchemy import select

async def get_user(AsyncSessionLocal, user_id: int) -> User | None:
    async with AsyncSessionLocal() as session:
        result = await session.execute(
            select(User).where(User.id == user_id)
        )
        return result.scalar_one_or_none()
```

### 5. Accessing Expired Attributes After Session Close

**Problem**: Accessing unloaded or expired attributes after exiting the session context raises `DetachedInstanceError`.

```python
# BAD - accessing attribute after session closes
def get_user_email(SessionLocal, user_id: int) -> str:
    with SessionLocal() as session:
        user = session.get(User, user_id)
    return user.email  # DetachedInstanceError!

# GOOD - read/return needed values inside session, or configure expire_on_commit=False + eager load
from sqlalchemy.orm import selectinload

def get_user_with_posts(SessionLocal, user_id: int) -> User | None:
    with SessionLocal() as session:
        user = session.execute(
            select(User)
            .options(selectinload(User.posts))
            .where(User.id == user_id)
        ).scalar_one_or_none()
        if user:
            session.expunge(user)
        return user
```

### 6. Splitting Atomic Operations Across Multiple Commits

**Problem**: Separate commits without an enclosing transaction can leave partial updates persisted on failure.

```python
# BAD - two separate commits for one atomic transfer
def transfer_money(SessionLocal, from_id: int, to_id: int, amount: float):
    with SessionLocal() as session:
        from_account = session.get(Account, from_id)
        to_account = session.get(Account, to_id)

        from_account.balance -= amount
        session.commit()  # Committed even if next update fails!

        to_account.balance += amount
        session.commit()

# GOOD - single explicit transaction with session.begin()
async def transfer_money(
    AsyncSessionLocal,
    from_id: int,
    to_id: int,
    amount: float,
) -> None:
    async with AsyncSessionLocal() as session:
        async with session.begin():
            result = await session.execute(
                select(Account)
                .where(Account.id.in_([from_id, to_id]))
                .with_for_update()
            )
            accounts = {acc.id: acc for acc in result.scalars()}

            from_account = accounts[from_id]
            to_account = accounts[to_id]

            if from_account.balance < amount:
                raise ValueError("Insufficient funds")

            from_account.balance -= amount
            to_account.balance += amount
```

### 7. Session Factory Misconfiguration

**Problem**: Creating engines per request leaks pools; passing removed 1.x `autocommit` parameters to `sessionmaker` fails in SQLAlchemy 2.0.

```python
# BAD - new engine created per call (and avoid legacy 1.x autocommit kwargs removed in 2.0)
def get_session():
    engine = create_engine("postgresql+psycopg://...")
    return sessionmaker(bind=engine)()

# GOOD - module-level engine and sessionmaker (sync)
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

engine = create_engine(
    "postgresql+psycopg://...",
    pool_pre_ping=True,
    pool_size=10,
    max_overflow=20,
)

SessionLocal = sessionmaker(
    bind=engine,
    expire_on_commit=False,
    autoflush=False,
)

# GOOD - async engine and async_sessionmaker (SQLAlchemy 2.0)
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

async_engine = create_async_engine(
    "postgresql+asyncpg://...",
    pool_pre_ping=True,
    pool_size=10,
)

AsyncSessionLocal = async_sessionmaker(
    async_engine,
    expire_on_commit=False,
    autoflush=False,
)

async def get_async_session():
    async with AsyncSessionLocal() as session:
        yield session
```

### 8. Stale Identity Map State Across Long External Operations

**Problem**: Holding an open session across external I/O can leave ORM attributes stale relative to concurrent DB updates (and holds a DB connection idle).

```python
# BAD - keeping session open and trusting stale ORM state across external call
async def process_order(AsyncSessionLocal, order_id: int):
    async with AsyncSessionLocal() as session:
        order = await session.get(Order, order_id)
        await process_payment(order.id)  # Slow external I/O!
        if order.status == "pending":    # May be stale!
            order.status = "completed"
            await session.commit()

# GOOD - release session during external I/O or refresh / conditionally update
async def process_order(AsyncSessionLocal, order_id: int):
    async with AsyncSessionLocal() as session:
        order = await session.get(Order, order_id)
        if not order or order.status != "pending":
            return

    await process_payment(order_id)

    async with AsyncSessionLocal() as session:
        async with session.begin():
            order = await session.get(Order, order_id, with_for_update=True)
            if order and order.status == "pending":
                order.status = "completed"
```

## Review Questions

1. Are all sessions created from a reused `sessionmaker` / `async_sessionmaker` and closed via `with` / `async with`?
2. Are removed 1.x `autocommit` kwargs absent from `sessionmaker` / `async_sessionmaker`?
3. Is each request/task getting its own session instance?
4. Are multi-step writes wrapped in `session.begin()`?
5. Are async code paths using `AsyncSession` rather than sync `Session`?
6. Are sessions released during external network I/O rather than holding DB connections idle?
