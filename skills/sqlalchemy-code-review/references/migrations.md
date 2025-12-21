# Migrations

## Critical Anti-Patterns

### 1. Non-Reversible Migrations

**Problem**: Can't rollback, stuck on failed deploys.

```python
# BAD - no downgrade
"""Add user_role column

Revision ID: abc123
"""

def upgrade():
    op.add_column('users', sa.Column('role', sa.String(50)))

def downgrade():
    pass  # Can't rollback!

# GOOD - reversible migration
def upgrade():
    op.add_column('users', sa.Column('role', sa.String(50), nullable=True))

def downgrade():
    op.drop_column('users', 'role')
```

### 2. Not Making New Columns Nullable First

**Problem**: Migration fails on existing data.

```python
# BAD - adding non-nullable column to existing table
def upgrade():
    # Fails if table has existing rows!
    op.add_column('users', sa.Column('email', sa.String(255), nullable=False))

# GOOD - two-step migration
def upgrade():
    # Step 1: Add nullable column
    op.add_column('users', sa.Column('email', sa.String(255), nullable=True))

# Then in a separate migration after backfilling data:
def upgrade():
    # Step 2: Make it non-nullable
    op.alter_column('users', 'email', nullable=False)

def downgrade():
    op.alter_column('users', 'email', nullable=True)

# BETTER - add with server_default
def upgrade():
    op.add_column(
        'users',
        sa.Column('email', sa.String(255), nullable=False, server_default='')
    )
    # Remove server_default in next migration after cleanup
```

### 3. Using ORM Models in Migrations

**Problem**: Model changes break old migrations.

```python
# BAD - using ORM models directly
from app.models import User  # DON'T!

def upgrade():
    session = Session()
    users = session.query(User).all()  # Model might change!
    for user in users:
        user.email = f"{user.username}@example.com"
    session.commit()

# GOOD - use op.execute with raw SQL
def upgrade():
    op.execute(
        """
        UPDATE users
        SET email = username || '@example.com'
        WHERE email IS NULL
        """
    )

# BETTER - use Core Table for complex operations
from sqlalchemy import table, column, String, Integer

def upgrade():
    users_table = table(
        'users',
        column('id', Integer),
        column('username', String),
        column('email', String)
    )

    connection = op.get_bind()
    users = connection.execute(
        select(users_table.c.id, users_table.c.username)
        .where(users_table.c.email.is_(None))
    ).fetchall()

    for user in users:
        connection.execute(
            update(users_table)
            .where(users_table.c.id == user.id)
            .values(email=f"{user.username}@example.com")
        )
```

### 4. Not Handling Concurrent Migrations

**Problem**: Multiple developers create conflicting migrations.

```python
# BAD - no dependency management
"""Add status column

Revision ID: abc123
Revises: xyz789
"""

# Developer B also based on xyz789 - conflict!
"""Add priority column

Revision ID: def456
Revises: xyz789  # Same parent!
"""

# GOOD - use down_revision properly
# Developer A
"""Add status column

Revision ID: abc123
Revises: xyz789
"""

# Developer B rebases
"""Add priority column

Revision ID: def456
Revises: abc123  # Updated after merge
"""

# BETTER - use alembic branches for long-running features
$ alembic revision -m "feature branch" --branch-label feature_x --depends-on abc123
```

### 5. Dangerous DDL Without Transactions

**Problem**: Partial migrations leave database in broken state.

```python
# BAD - multiple DDL operations without transaction
def upgrade():
    op.create_table('temp_users', ...)
    op.execute("INSERT INTO temp_users SELECT * FROM users")
    op.drop_table('users')  # If this fails, temp_users exists but users is gone!
    op.rename_table('temp_users', 'users')

# GOOD - use batch operations for SQLite
def upgrade():
    with op.batch_alter_table('users') as batch_op:
        batch_op.add_column(sa.Column('new_col', sa.String(50)))
        batch_op.drop_column('old_col')

# PostgreSQL supports transactional DDL
def upgrade():
    # These all happen in a transaction by default
    op.add_column('users', sa.Column('new_col', sa.String(50)))
    op.drop_column('users', 'old_col')

# For operations that can't be in a transaction
def upgrade():
    op.execute("CREATE INDEX CONCURRENTLY idx_users_email ON users(email)")

def downgrade():
    op.execute("DROP INDEX CONCURRENTLY idx_users_email")
```

### 6. Not Testing Migrations

**Problem**: Migrations fail in production.

```python
# BAD - no testing
def upgrade():
    # Hope this works in production!
    op.add_column('users', sa.Column('role', sa.String(50)))

# GOOD - test migrations in CI
# tests/test_migrations.py
import pytest
from alembic import command
from alembic.config import Config

def test_migration_upgrade_downgrade():
    config = Config("alembic.ini")

    # Test upgrade
    command.upgrade(config, "head")

    # Test downgrade
    command.downgrade(config, "-1")

    # Test re-upgrade
    command.upgrade(config, "head")

# BETTER - test with actual data
def test_migration_preserves_data():
    config = Config("alembic.ini")

    # Setup test data
    connection = engine.connect()
    connection.execute(
        "INSERT INTO users (username, email) VALUES ('test', 'test@example.com')"
    )

    # Run migration
    command.upgrade(config, "head")

    # Verify data preserved
    result = connection.execute("SELECT * FROM users WHERE username = 'test'")
    assert result.rowcount == 1
```

### 7. Not Using Batch Operations for SQLite

**Problem**: SQLite doesn't support many ALTER TABLE operations.

```python
# BAD - doesn't work on SQLite
def upgrade():
    op.alter_column('users', 'email', type_=sa.String(512))  # Fails on SQLite!

# GOOD - use batch operations
def upgrade():
    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.alter_column('email', type_=sa.String(512))

def downgrade():
    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.alter_column('email', type_=sa.String(255))
```

### 8. Not Handling Large Data Migrations

**Problem**: Migration times out or locks table.

```python
# BAD - single UPDATE locks entire table
def upgrade():
    op.execute(
        "UPDATE users SET normalized_email = LOWER(email)"
    )  # Locks millions of rows!

# GOOD - batch updates
def upgrade():
    connection = op.get_bind()
    batch_size = 1000
    offset = 0

    while True:
        result = connection.execute(
            f"""
            UPDATE users
            SET normalized_email = LOWER(email)
            WHERE id IN (
                SELECT id FROM users
                WHERE normalized_email IS NULL
                ORDER BY id
                LIMIT {batch_size} OFFSET {offset}
            )
            """
        )

        if result.rowcount == 0:
            break

        offset += batch_size
        # Sleep to avoid overwhelming the database
        import time
        time.sleep(0.1)

# BETTER - use queue/background job for very large tables
def upgrade():
    # Add column
    op.add_column('users', sa.Column('normalized_email', sa.String(255)))

    # Create background job to populate
    # (Actual backfill happens outside migration)
    pass
```

### 9. Not Managing Indexes Properly

**Problem**: Slow queries after migration, or failed migrations.

```python
# BAD - adding index inline blocks table
def upgrade():
    op.add_column('users', sa.Column('email', sa.String(255)))
    op.create_index('idx_users_email', 'users', ['email'])  # Locks table!

# GOOD - create index concurrently (PostgreSQL)
def upgrade():
    op.add_column('users', sa.Column('email', sa.String(255)))

    # Separate connection for concurrent index
    op.execute("COMMIT")  # End transaction
    op.execute("CREATE INDEX CONCURRENTLY idx_users_email ON users(email)")

def downgrade():
    op.execute("DROP INDEX CONCURRENTLY idx_users_email")
    op.drop_column('users', 'email')

# BETTER - track index creation separately
def upgrade():
    op.add_column('users', sa.Column('email', sa.String(255)))
    # Create index in a separate migration
```

### 10. Not Documenting Complex Migrations

**Problem**: Team doesn't understand migration purpose or impact.

```python
# BAD - no documentation
"""revision abc123
"""

def upgrade():
    op.execute("complex SQL here...")

# GOOD - clear documentation
"""Add normalized_email column for case-insensitive lookups

This migration:
1. Adds a new normalized_email column (nullable initially)
2. Backfills it with lowercase email values
3. Creates a unique index on normalized_email
4. Does NOT make it non-nullable yet (requires follow-up migration)

Expected duration: ~2 minutes for 1M users
Locks: Brief lock during index creation
Rollback safe: Yes

Revision ID: abc123
Revises: xyz789
Create Date: 2024-01-15 10:30:00
"""

def upgrade():
    # Step 1: Add column
    op.add_column(
        'users',
        sa.Column('normalized_email', sa.String(255), nullable=True)
    )

    # Step 2: Backfill in batches
    connection = op.get_bind()
    batch_size = 1000
    # ... batched update logic ...

    # Step 3: Create index
    op.create_index(
        'idx_users_normalized_email',
        'users',
        ['normalized_email'],
        unique=True
    )

def downgrade():
    op.drop_index('idx_users_normalized_email', table_name='users')
    op.drop_column('users', 'normalized_email')
```

### 11. Not Using Check Constraints

**Problem**: Invalid data gets inserted.

```python
# BAD - no constraints, rely on application validation
def upgrade():
    op.add_column('users', sa.Column('age', sa.Integer))

# GOOD - add check constraints
def upgrade():
    op.add_column('users', sa.Column('age', sa.Integer))
    op.create_check_constraint(
        'ck_users_age_positive',
        'users',
        'age >= 0 AND age <= 150'
    )

def downgrade():
    op.drop_constraint('ck_users_age_positive', 'users')
    op.drop_column('users', 'age')

# BETTER - use enum for limited values
from sqlalchemy import Enum

def upgrade():
    role_enum = sa.Enum('user', 'admin', 'moderator', name='user_role')
    role_enum.create(op.get_bind())

    op.add_column(
        'users',
        sa.Column('role', role_enum, nullable=False, server_default='user')
    )

def downgrade():
    op.drop_column('users', 'role')
    sa.Enum(name='user_role').drop(op.get_bind())
```

## Review Questions

1. Does every migration have a working `downgrade()` function?
2. Are new non-nullable columns added in two steps (nullable first, then constrain)?
3. Are data migrations using `op.execute()` not ORM models?
4. Are large data updates batched to avoid timeouts?
5. Are indexes created with CONCURRENTLY on PostgreSQL?
6. Are complex migrations documented with expected duration and impact?
7. Are constraints (CHECK, UNIQUE, FK) properly created and dropped?
