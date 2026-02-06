# Queries

## Critical Anti-Patterns

### 1. Using Legacy query() Instead of select()

**Problem**: Legacy API, deprecated in SQLAlchemy 2.0.

```python
# BAD - legacy query() API (deprecated)
def get_active_users():
    with Session() as session:
        users = session.query(User).filter(User.active == True).all()
        return users

# GOOD - SQLAlchemy 2.0 select() syntax
from sqlalchemy import select

def get_active_users():
    with Session() as session:
        result = session.execute(
            select(User).where(User.active == True)
        )
        return result.scalars().all()

# ASYNC version
async def get_active_users():
    async with AsyncSession() as session:
        result = await session.execute(
            select(User).where(User.active == True)
        )
        return result.scalars().all()
```

### 2. Loading Full Objects When Only Columns Needed

**Problem**: ORM overhead, unnecessary data transfer.

```python
# BAD - loading full ORM objects just for one column
def get_user_emails():
    with Session() as session:
        users = session.execute(select(User)).scalars().all()
        return [user.email for user in users]  # Loaded entire object!

# GOOD - select only needed columns
def get_user_emails():
    with Session() as session:
        result = session.execute(
            select(User.email)
        )
        return result.scalars().all()

# BETTER - multiple columns as tuples
def get_user_info():
    with Session() as session:
        result = session.execute(
            select(User.id, User.name, User.email)
        )
        return result.all()  # Returns list of tuples
```

### 3. Using all() When Only One Result Expected

**Problem**: Confusing API, loads unnecessary data.

```python
# BAD - using all() when expecting one result
def get_user_by_email(email: str):
    with Session() as session:
        users = session.execute(
            select(User).where(User.email == email)
        ).scalars().all()
        return users[0] if users else None  # Awkward!

# GOOD - use scalar_one_or_none()
def get_user_by_email(email: str) -> User | None:
    with Session() as session:
        return session.execute(
            select(User).where(User.email == email)
        ).scalar_one_or_none()

# Use scalar_one() if must exist (raises if not found)
def get_user_by_id(user_id: int) -> User:
    with Session() as session:
        return session.execute(
            select(User).where(User.id == user_id)
        ).scalar_one()  # Raises NoResultFound or MultipleResultsFound
```

### 4. Not Using Bulk Operations

**Problem**: ORM overhead per object, slow inserts/updates.

```python
# BAD - ORM insert in loop
def create_users(user_data: list[dict]):
    with Session() as session:
        for data in user_data:
            user = User(**data)
            session.add(user)  # Individual ORM overhead per user
        session.commit()

# GOOD - bulk insert
def create_users(user_data: list[dict]):
    with Session() as session:
        session.bulk_insert_mappings(User, user_data)
        session.commit()

# BETTER - Core insert for maximum performance
from sqlalchemy import insert

def create_users(user_data: list[dict]):
    with Session() as session:
        session.execute(
            insert(User),
            user_data
        )
        session.commit()

# ASYNC bulk insert
async def create_users(user_data: list[dict]):
    async with AsyncSession() as session:
        await session.execute(
            insert(User),
            user_data
        )
        await session.commit()
```

### 5. Not Using Bulk Updates

**Problem**: ORM overhead, multiple UPDATE statements.

```python
# BAD - update in loop
def deactivate_old_users(cutoff_date):
    with Session() as session:
        users = session.execute(
            select(User).where(User.last_login < cutoff_date)
        ).scalars().all()

        for user in users:
            user.active = False  # Individual UPDATE per user
        session.commit()

# GOOD - single UPDATE statement
from sqlalchemy import update

def deactivate_old_users(cutoff_date):
    with Session() as session:
        session.execute(
            update(User)
            .where(User.last_login < cutoff_date)
            .values(active=False)
        )
        session.commit()

# ASYNC version
async def deactivate_old_users(cutoff_date):
    async with AsyncSession() as session:
        await session.execute(
            update(User)
            .where(User.last_login < cutoff_date)
            .values(active=False)
        )
        await session.commit()
```

### 6. Not Using exists() for Existence Checks

**Problem**: Loads unnecessary data just to check existence.

```python
# BAD - loading data just to check existence
def user_exists(email: str) -> bool:
    with Session() as session:
        user = session.execute(
            select(User).where(User.email == email)
        ).scalar_one_or_none()
        return user is not None  # Loaded entire object!

# GOOD - use exists()
from sqlalchemy import exists, select

def user_exists(email: str) -> bool:
    with Session() as session:
        return session.execute(
            select(exists().where(User.email == email))
        ).scalar()

# Alternative with count (less efficient but sometimes clearer)
from sqlalchemy import func

def user_exists(email: str) -> bool:
    with Session() as session:
        count = session.execute(
            select(func.count()).select_from(User).where(User.email == email)
        ).scalar()
        return count > 0
```

### 7. Not Using Pagination

**Problem**: Memory exhaustion on large result sets.

```python
# BAD - loading all results into memory
def get_all_users():
    with Session() as session:
        users = session.execute(select(User)).scalars().all()  # OOM on millions!
        return users

# GOOD - use limit/offset for pagination
def get_users_page(page: int = 1, page_size: int = 100):
    with Session() as session:
        offset = (page - 1) * page_size
        users = session.execute(
            select(User)
            .offset(offset)
            .limit(page_size)
        ).scalars().all()
        return users

# BETTER - use keyset pagination for large datasets
def get_users_after(last_id: int | None = None, page_size: int = 100):
    with Session() as session:
        query = select(User).order_by(User.id)
        if last_id:
            query = query.where(User.id > last_id)

        users = session.execute(
            query.limit(page_size)
        ).scalars().all()
        return users

# BEST - stream results for very large datasets
def stream_all_users():
    with Session() as session:
        result = session.execute(select(User))
        for user in result.scalars():  # Streams, doesn't load all
            yield user
```

### 8. Not Using with_for_update for Row Locking

**Problem**: Race conditions in concurrent updates.

```python
# BAD - race condition in concurrent requests
def decrement_stock(product_id: int, quantity: int):
    with Session() as session:
        product = session.execute(
            select(Product).where(Product.id == product_id)
        ).scalar_one()

        # Another request could modify stock here!
        if product.stock >= quantity:
            product.stock -= quantity
            session.commit()
        else:
            raise ValueError("Insufficient stock")

# GOOD - use SELECT FOR UPDATE
def decrement_stock(product_id: int, quantity: int):
    with Session() as session:
        with session.begin():
            product = session.execute(
                select(Product)
                .where(Product.id == product_id)
                .with_for_update()  # Row locked until commit
            ).scalar_one()

            if product.stock >= quantity:
                product.stock -= quantity
            else:
                raise ValueError("Insufficient stock")

# ASYNC version
async def decrement_stock(product_id: int, quantity: int):
    async with AsyncSession() as session:
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

### 9. Using String-Based Filters Instead of Column Objects

**Problem**: No IDE support, error-prone, SQL injection risk.

```python
# BAD - string-based filters
def search_users(name: str):
    with Session() as session:
        users = session.execute(
            select(User).filter_by(name=name)  # String-based
        ).scalars().all()
        return users

# WORSE - string SQL (SQL injection risk!)
def search_users(name: str):
    with Session() as session:
        users = session.execute(
            f"SELECT * FROM users WHERE name = '{name}'"  # NEVER DO THIS!
        ).all()

# GOOD - column object filters
def search_users(name: str):
    with Session() as session:
        users = session.execute(
            select(User).where(User.name == name)  # Type-safe
        ).scalars().all()
        return users

# BETTER - parameterized for complex filters
from sqlalchemy import text

def search_users_complex(filters: dict):
    with Session() as session:
        query = select(User)
        if "name" in filters:
            query = query.where(User.name.contains(filters["name"]))
        if "active" in filters:
            query = query.where(User.active == filters["active"])

        users = session.execute(query).scalars().all()
        return users
```

### 10. Not Using Subqueries Efficiently

**Problem**: Multiple queries instead of single subquery.

```python
# BAD - multiple queries
def get_users_with_recent_posts():
    with Session() as session:
        # First query
        recent_post_user_ids = session.execute(
            select(Post.user_id)
            .where(Post.created_at > datetime.now() - timedelta(days=7))
            .distinct()
        ).scalars().all()

        # Second query
        users = session.execute(
            select(User).where(User.id.in_(recent_post_user_ids))
        ).scalars().all()
        return users

# GOOD - single query with subquery
def get_users_with_recent_posts():
    with Session() as session:
        recent_posts_subq = (
            select(Post.user_id)
            .where(Post.created_at > datetime.now() - timedelta(days=7))
            .distinct()
            .subquery()
        )

        users = session.execute(
            select(User).where(User.id.in_(select(recent_posts_subq.c.user_id)))
        ).scalars().all()
        return users

# BETTER - use join
def get_users_with_recent_posts():
    with Session() as session:
        users = session.execute(
            select(User)
            .join(Post)
            .where(Post.created_at > datetime.now() - timedelta(days=7))
            .distinct()
        ).scalars().all()
        return users
```

### 11. Not Using union/union_all

**Problem**: Multiple queries when one combined query would work.

```python
# BAD - multiple queries
def get_all_content():
    with Session() as session:
        posts = session.execute(select(Post)).scalars().all()
        pages = session.execute(select(Page)).scalars().all()
        return {"posts": posts, "pages": pages}

# GOOD - union query (if columns match)
from sqlalchemy import union_all

def get_all_content_items():
    with Session() as session:
        posts_query = select(
            Post.id,
            Post.title,
            Post.created_at,
            literal("post").label("type")
        )

        pages_query = select(
            Page.id,
            Page.title,
            Page.created_at,
            literal("page").label("type")
        )

        combined = union_all(posts_query, pages_query)
        result = session.execute(combined).all()
        return result
```

## Review Questions

1. Are all queries using SQLAlchemy 2.0 `select()` syntax not legacy `query()`?
2. Are bulk operations used for batch inserts/updates?
3. Are only required columns selected when full objects aren't needed?
4. Is `exists()` used instead of loading objects for existence checks?
5. Is pagination implemented for large result sets?
6. Is `with_for_update()` used for concurrent updates?
7. Are column objects used instead of string-based filters?
