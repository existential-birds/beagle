# Relationships

## Critical Anti-Patterns

### 1. N+1 Query Problem

**Problem**: One query per related object causes severe performance degradation.

```python
# BAD - N+1 queries
def get_users_with_posts(session_factory):
    with session_factory() as session:
        users = session.execute(select(User)).scalars().all()
        result = []
        for user in users:
            posts = user.posts  # Separate SELECT per user!
            result.append({"user": user, "posts": posts})
        return result

# GOOD - eager load with selectinload / joinedload
from sqlalchemy import select
from sqlalchemy.orm import selectinload

def get_users_with_posts(session_factory):
    with session_factory() as session:
        return session.execute(
            select(User).options(selectinload(User.posts))
        ).scalars().all()

# ASYNC version (using configured async_sessionmaker)
async def get_users_with_posts(async_session_factory):
    async with async_session_factory() as session:
        result = await session.execute(
            select(User).options(selectinload(User.posts))
        )
        return result.scalars().all()
```

*(Note: When using `joinedload` on a collection relationship, call `.unique().scalars().all()` on the result.)*

### 2. Wrong Lazy Loading Strategy

**Problem**: Default `lazy="select"` silently emits N+1 queries (and raises `MissingGreenlet` in async sessions).

```python
from sqlalchemy import ForeignKey
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship, selectinload

class Base(DeclarativeBase):
    pass

# BAD - default lazy="select" hides N+1 queries
class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(primary_key=True)
    posts: Mapped[list["Post"]] = relationship(back_populates="user")

# GOOD - force explicit loading with lazy="raise" (recommended for async & large apps)
class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(primary_key=True)
    posts: Mapped[list["Post"]] = relationship(
        back_populates="user",
        lazy="raise",
    )

# Load explicitly when needed
def get_user_with_posts(session_factory, user_id: int) -> User:
    with session_factory() as session:
        return session.execute(
            select(User)
            .options(selectinload(User.posts))
            .where(User.id == user_id)
        ).scalar_one()
```

### 3. Missing `back_populates`

**Problem**: One-way relationship leaves in-memory object graphs out of sync.

```python
# BAD - one-way relationship
class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(primary_key=True)
    posts: Mapped[list["Post"]] = relationship()

class Post(Base):
    __tablename__ = "posts"
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))

# GOOD - bidirectional with back_populates
class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(primary_key=True)
    posts: Mapped[list["Post"]] = relationship(back_populates="user")

class Post(Base):
    __tablename__ = "posts"
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    user: Mapped["User"] = relationship(back_populates="posts")
```

### 4. Cascade Not Set Properly

**Problem**: Orphaned records or foreign key violations when parent objects are deleted.

```python
# BAD - no cascade, deleting User leaves orphaned posts or hits FK error
class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(primary_key=True)
    posts: Mapped[list["Post"]] = relationship(back_populates="user")

# GOOD - delete-orphan for owned child entities
class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(primary_key=True)
    posts: Mapped[list["Post"]] = relationship(
        back_populates="user",
        cascade="all, delete-orphan",
    )

# For many-to-many associations, do not delete shared target rows
class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(primary_key=True)
    groups: Mapped[list["Group"]] = relationship(
        secondary="user_groups",
        back_populates="users",
        cascade="save-update, merge",
    )
```

### 5. Using `joinedload` with Multiple Collections

**Problem**: Joining multiple one-to-many or many-to-many collections creates a Cartesian product explosion.

```python
# BAD - Cartesian product: users * groups * posts
def get_users_with_groups_and_posts(session):
    return session.execute(
        select(User)
        .options(joinedload(User.groups))
        .options(joinedload(User.posts))
    ).unique().scalars().all()

# GOOD - use selectinload for collection relationships
def get_users_with_groups_and_posts(session):
    return session.execute(
        select(User)
        .options(selectinload(User.groups))
        .options(selectinload(User.posts))
    ).scalars().all()
```

### 6. Not Using `contains_eager` for Filtered Joins

**Problem**: Loading all related rows and filtering in Python wastes bandwidth and memory.

```python
# BAD - loads all posts then filters in Python
def get_users_with_published_posts(session):
    users = session.execute(
        select(User).options(selectinload(User.posts))
    ).scalars().all()
    return [
        {"user": user, "posts": [p for p in user.posts if p.published]}
        for user in users
    ]

# GOOD - filter in SQL and populate relationship via contains_eager
from sqlalchemy.orm import contains_eager

def get_users_with_published_posts(session):
    return session.execute(
        select(User)
        .join(User.posts)
        .where(Post.published.is_(True))
        .options(contains_eager(User.posts))
    ).unique().scalars().all()
```

### 7. Circular Eager Loading

**Problem**: Mutual `lazy="joined"` on bidirectional relationships creates self-referencing joins or recursion limits.

```python
# BAD - circular eager loading
class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(primary_key=True)
    posts: Mapped[list["Post"]] = relationship(back_populates="user", lazy="joined")

class Post(Base):
    __tablename__ = "posts"
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    user: Mapped["User"] = relationship(back_populates="posts", lazy="joined")

# GOOD - use lazy="raise" on models and explicit loading per query
class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(primary_key=True)
    posts: Mapped[list["Post"]] = relationship(back_populates="user", lazy="raise")

class Post(Base):
    __tablename__ = "posts"
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    user: Mapped["User"] = relationship(back_populates="posts", lazy="raise")
```

### 8. Not Using Association Object for Rich M2M

**Problem**: Simple `secondary` tables cannot store link attributes like `joined_at` or `role`.

```python
from datetime import datetime, timezone
from sqlalchemy import DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

# GOOD - association object pattern with SQLAlchemy 2.0 Mapped typing
class UserGroup(Base):
    __tablename__ = "user_groups"
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), primary_key=True)
    group_id: Mapped[int] = mapped_column(ForeignKey("groups.id"), primary_key=True)
    joined_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
    )
    role: Mapped[str] = mapped_column(String(50))

    user: Mapped["User"] = relationship(back_populates="group_associations")
    group: Mapped["Group"] = relationship(back_populates="user_associations")

class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(primary_key=True)
    group_associations: Mapped[list["UserGroup"]] = relationship(back_populates="user")

    @property
    def groups(self) -> list["Group"]:
        return [assoc.group for assoc in self.group_associations]

class Group(Base):
    __tablename__ = "groups"
    id: Mapped[int] = mapped_column(primary_key=True)
    user_associations: Mapped[list["UserGroup"]] = relationship(back_populates="group")
```

*(Note: Avoid naive UTC datetime constructors deprecated in Python 3.12+; use `lambda: datetime.now(timezone.utc)` with `DateTime(timezone=True)` or `server_default=func.now()`.)*

### 9. Not Using `raiseload` to Catch Hidden Lazy Loads

**Problem**: Accidental lazy loads pass local tests and cause N+1 latency in production.

```python
from sqlalchemy.orm import raiseload, selectinload

# GOOD - fail fast if any relationship is accessed without eager loading
def get_users(session):
    return session.execute(
        select(User).options(raiseload("*"))
    ).scalars().all()

# Explicit loading when posts are needed
def get_users_with_posts(session):
    return session.execute(
        select(User).options(selectinload(User.posts))
    ).scalars().all()
```

## Review Questions

1. Do models use SQLAlchemy 2.0 `Mapped[T] = mapped_column(...)` declarations?
2. Are relationship queries using explicit eager loading (`selectinload`, `joinedload`, `contains_eager`)?
3. Is `lazy="raise"` (or `raiseload("*")`) used to catch accidental lazy loads, especially in async code?
4. Do bidirectional relationships declare `back_populates`?
5. Are `cascade` options appropriate for owned children vs shared many-to-many targets?
6. Is `selectinload` used instead of `joinedload` when loading multiple collections?
