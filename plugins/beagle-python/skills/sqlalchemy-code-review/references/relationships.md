# Relationships

## Critical Anti-Patterns

### 1. N+1 Query Problem

**Problem**: One query per related object, severe performance degradation.

```python
# BAD - N+1 queries
def get_users_with_posts():
    with Session() as session:
        users = session.execute(select(User)).scalars().all()
        result = []
        for user in users:
            # Each access triggers a separate query!
            posts = user.posts  # SELECT * FROM posts WHERE user_id = ?
            result.append({"user": user, "posts": posts})
        return result

# GOOD - eager load with joinedload
from sqlalchemy.orm import joinedload

def get_users_with_posts():
    with Session() as session:
        users = session.execute(
            select(User).options(joinedload(User.posts))
        ).unique().scalars().all()
        return users

# ASYNC version
async def get_users_with_posts():
    async with AsyncSession() as session:
        result = await session.execute(
            select(User).options(joinedload(User.posts))
        )
        return result.unique().scalars().all()
```

### 2. Wrong Lazy Loading Strategy

**Problem**: Default lazy loading causes N+1 in most real-world scenarios.

```python
# BAD - default lazy='select' causes N+1
class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True)
    posts = relationship("Post", back_populates="user")  # lazy='select' by default

# GOOD - choose appropriate lazy strategy
class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True)

    # Option 1: lazy='joined' - always join
    posts = relationship("Post", back_populates="user", lazy="joined")

    # Option 2: lazy='selectin' - single extra query
    posts = relationship("Post", back_populates="user", lazy="selectin")

    # Option 3: lazy='raise' - force explicit loading
    posts = relationship("Post", back_populates="user", lazy="raise")

# BEST - use lazy='raise' and explicit loading at query time
class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True)
    posts = relationship("Post", back_populates="user", lazy="raise")

# Then explicitly load when needed
def get_user_with_posts(user_id: int):
    with Session() as session:
        user = session.execute(
            select(User)
            .options(selectinload(User.posts))
            .where(User.id == user_id)
        ).scalar_one()
        return user
```

### 3. Missing back_populates

**Problem**: One-way relationship, inconsistent state, bugs.

```python
# BAD - missing back_populates
class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True)
    posts = relationship("Post")

class Post(Base):
    __tablename__ = "posts"
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    # No relationship back to User!

# GOOD - bidirectional with back_populates
class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True)
    posts = relationship("Post", back_populates="user")

class Post(Base):
    __tablename__ = "posts"
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    user = relationship("User", back_populates="posts")
```

### 4. Cascade Not Set Properly

**Problem**: Orphaned records, foreign key violations.

```python
# BAD - no cascade, orphaned posts when user deleted
class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True)
    posts = relationship("Post", back_populates="user")

# Deleting user leaves orphaned posts or fails with FK constraint

# GOOD - proper cascade for composition
class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True)
    posts = relationship(
        "Post",
        back_populates="user",
        cascade="all, delete-orphan"  # Delete posts when user deleted
    )

# For many-to-many, different cascade
class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True)
    groups = relationship(
        "Group",
        secondary="user_groups",
        back_populates="users",
        cascade="save-update, merge"  # Don't delete groups
    )
```

### 5. Using joinedload with Many-to-Many

**Problem**: Cartesian product explosion, duplicate rows.

```python
# BAD - joinedload with many-to-many causes duplicates
def get_users_with_groups_and_posts():
    with Session() as session:
        users = session.execute(
            select(User)
            .options(joinedload(User.groups))
            .options(joinedload(User.posts))
        ).scalars().all()  # Cartesian product: users × groups × posts!

# GOOD - use selectinload for collections
from sqlalchemy.orm import selectinload

def get_users_with_groups_and_posts():
    with Session() as session:
        users = session.execute(
            select(User)
            .options(selectinload(User.groups))
            .options(selectinload(User.posts))
        ).scalars().all()  # Two separate IN queries, no cartesian product
```

### 6. Not Using contains_eager for Filtered Joins

**Problem**: Inefficient loading when filtering related objects.

```python
# BAD - loads all posts, then filters in Python
def get_users_with_published_posts():
    with Session() as session:
        users = session.execute(
            select(User).options(selectinload(User.posts))
        ).scalars().all()

        # Filters in Python, wasteful
        return [
            {
                "user": user,
                "posts": [p for p in user.posts if p.published]
            }
            for user in users
        ]

# GOOD - use contains_eager with join filter
from sqlalchemy.orm import contains_eager

def get_users_with_published_posts():
    with Session() as session:
        users = session.execute(
            select(User)
            .join(User.posts)
            .where(Post.published == True)
            .options(contains_eager(User.posts))
        ).unique().scalars().all()
        return users
```

### 7. Circular Eager Loading

**Problem**: Infinite recursion with bidirectional relationships.

```python
# BAD - circular eager loading
class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True)
    posts = relationship("Post", back_populates="user", lazy="joined")

class Post(Base):
    __tablename__ = "posts"
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    user = relationship("User", back_populates="posts", lazy="joined")

# Querying User loads Posts which loads User which loads Posts...

# GOOD - one side lazy, or explicit loading
class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True)
    posts = relationship("Post", back_populates="user", lazy="raise")

class Post(Base):
    __tablename__ = "posts"
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    user = relationship("User", back_populates="posts", lazy="raise")

# Explicitly load what you need
def get_user_with_posts(user_id: int):
    with Session() as session:
        return session.execute(
            select(User)
            .options(selectinload(User.posts))
            .where(User.id == user_id)
        ).scalar_one()
```

### 8. Not Using Association Object for Rich M2M

**Problem**: Can't store additional attributes on join table.

```python
# BAD - simple secondary table, can't add attributes
user_groups = Table(
    "user_groups",
    Base.metadata,
    Column("user_id", ForeignKey("users.id")),
    Column("group_id", ForeignKey("groups.id"))
)

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True)
    groups = relationship("Group", secondary=user_groups)

# Can't store "joined_at" or "role" on the relationship!

# GOOD - association object pattern
class UserGroup(Base):
    __tablename__ = "user_groups"
    user_id = Column(Integer, ForeignKey("users.id"), primary_key=True)
    group_id = Column(Integer, ForeignKey("groups.id"), primary_key=True)
    joined_at = Column(DateTime, default=datetime.utcnow)
    role = Column(String)  # "admin", "member", etc.

    user = relationship("User", back_populates="group_associations")
    group = relationship("Group", back_populates="user_associations")

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True)
    group_associations = relationship("UserGroup", back_populates="user")

    # Convenience property
    @property
    def groups(self):
        return [assoc.group for assoc in self.group_associations]

class Group(Base):
    __tablename__ = "groups"
    id = Column(Integer, primary_key=True)
    user_associations = relationship("UserGroup", back_populates="group")
```

### 9. Not Using raiseload for Debugging

**Problem**: N+1 queries slip into production unnoticed.

```python
# BAD - lazy loading hidden issues in production
from sqlalchemy.orm import Session

def get_users():
    with Session() as session:
        users = session.execute(select(User)).scalars().all()
        # Accessing posts triggers lazy load - silent N+1 in production
        for user in users:
            print(user.posts)

# GOOD - use raiseload in development to catch issues
from sqlalchemy.orm import raiseload

def get_users():
    with Session() as session:
        users = session.execute(
            select(User).options(raiseload("*"))  # Raise on any lazy load
        ).scalars().all()
        # This will raise immediately, forcing us to fix it
        for user in users:
            print(user.posts)  # InvalidRequestError!

# FIX - explicit loading
def get_users():
    with Session() as session:
        users = session.execute(
            select(User).options(selectinload(User.posts))
        ).scalars().all()
        for user in users:
            print(user.posts)  # No lazy load, efficient!
```

## Review Questions

1. Are all relationship queries using explicit eager loading (joinedload, selectinload)?
2. Is `lazy='raise'` used to prevent accidental lazy loading?
3. Do all relationships have proper `back_populates`?
4. Are cascade options set appropriately for composition vs association?
5. Is `selectinload` used instead of `joinedload` for collections?
6. Are association objects used for many-to-many with attributes?
