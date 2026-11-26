# Migrations

## Critical Anti-Patterns

### 1. Non-Reversible Migrations

**Problem**: Empty `downgrade()` blocks rollbacks on failed deployments.

```python
# BAD - no downgrade
def upgrade():
    op.add_column("users", sa.Column("role", sa.String(50)))

def downgrade():
    pass

# GOOD - reversible migration
def upgrade():
    op.add_column("users", sa.Column("role", sa.String(50), nullable=True))

def downgrade():
    op.drop_column("users", "role")
```

### 2. Adding Non-Nullable Column Without `server_default` or Two-Step Backfill

**Problem**: Adding a `nullable=False` column without a `server_default` fails on non-empty tables.

```python
# BAD - fails if table already has rows
def upgrade():
    op.add_column("users", sa.Column("email", sa.String(255), nullable=False))

# GOOD - two-step migration (add nullable -> backfill -> alter nullable=False)
def upgrade():
    op.add_column("users", sa.Column("email", sa.String(255), nullable=True))

# Follow-up migration after backfill:
def upgrade():
    op.alter_column("users", "email", nullable=False)

def downgrade():
    op.alter_column("users", "email", nullable=True)

# ALSO GOOD - add with server_default (PostgreSQL 11+ metadata-only constant default)
def upgrade():
    op.add_column(
        "users",
        sa.Column("email", sa.String(255), nullable=False, server_default=""),
    )
```

### 3. Importing Application ORM Models in Migrations

**Problem**: Future model changes break historical migrations when re-run from scratch.

```python
# BAD - coupled to live ORM model
from app.models import User

def upgrade():
    ...

# GOOD - self-contained SQL via sa.text() or Core table()/column()
import sqlalchemy as sa
from alembic import op

def upgrade():
    op.execute(
        sa.text(
            """
            UPDATE users
            SET email = username || '@example.com'
            WHERE email IS NULL
            """
        )
    )

# BETTER - Core table() snapshot for complex logic
from sqlalchemy import Integer, String, column, select, table, update

def upgrade():
    users_table = table(
        "users",
        column("id", Integer),
        column("username", String),
        column("email", String),
    )

    connection = op.get_bind()
    users = connection.execute(
        select(users_table.c.id, users_table.c.username).where(
            users_table.c.email.is_(None)
        )
    ).fetchall()

    for user in users:
        connection.execute(
            update(users_table)
            .where(users_table.c.id == user.id)
            .values(email=f"{user.username}@example.com")
        )
```

### 4. Concurrent Migration Head Conflicts

**Problem**: Multiple branches sharing the same `down_revision` create multiple Alembic heads.

```bash
# Check for multiple heads before merging
alembic heads
alembic merge -m "merge feature branches" head1 head2
```

### 5. Non-Transactional DDL Without Safety

**Problem**: Dropping/renaming tables outside a transaction risks data loss on partial failure.

```python
# GOOD - PostgreSQL executes migration DDL inside a transaction by default
def upgrade():
    op.add_column("users", sa.Column("new_col", sa.String(50)))
    op.drop_column("users", "old_col")

# GOOD - use batch_alter_table for SQLite table rewrites
def upgrade():
    with op.batch_alter_table("users", schema=None) as batch_op:
        batch_op.add_column(sa.Column("new_col", sa.String(50)))
        batch_op.drop_column("old_col")
```

### 6. Not Testing Migrations (`sa.text()` Required in SQLAlchemy 2.0)

**Problem**: Untested downgrades or raw string `connection.execute("...")` calls break in SQLAlchemy 2.0 (which requires `sa.text(...)` for raw SQL).

```python
# BAD - raw string fails in SQLAlchemy 2.0
connection.execute("SELECT * FROM users WHERE username = 'test'")

# GOOD - wrap raw SQL in sa.text() with bound params
import sqlalchemy as sa
from alembic import command
from alembic.config import Config

def test_migration_upgrade_downgrade(engine):
    config = Config("alembic.ini")
    command.upgrade(config, "head")
    command.downgrade(config, "-1")
    command.upgrade(config, "head")

    with engine.connect() as connection:
        connection.execute(
            sa.text(
                "INSERT INTO users (username, email) VALUES (:u, :e)"
            ),
            {"u": "test", "e": "test@example.com"},
        )
        result = connection.execute(
            sa.text("SELECT 1 FROM users WHERE username = :u"),
            {"u": "test"},
        )
        assert result.first() is not None
```

### 7. Using Direct `alter_column` on SQLite

**Problem**: SQLite lacks full `ALTER TABLE` support for column type/constraint changes.

```python
# BAD - fails on SQLite
def upgrade():
    op.alter_column("users", "email", type_=sa.String(512))

# GOOD - batch_alter_table works on SQLite and other backends
def upgrade():
    with op.batch_alter_table("users", schema=None) as batch_op:
        batch_op.alter_column("email", type_=sa.String(512))

def downgrade():
    with op.batch_alter_table("users", schema=None) as batch_op:
        batch_op.alter_column("email", type_=sa.String(255))
```

### 8. Unbatched Table Backfills or Unsafe `OFFSET` / f-string Loops

**Problem**: Single massive `UPDATE` locks millions of rows; f-string SQL risks injection/syntax errors; `OFFSET` skips rows as `normalized_email IS NULL` shrinks and degrades to O(N^2).

```python
# BAD - locks entire table
def upgrade():
    op.execute(sa.text("UPDATE users SET normalized_email = LOWER(email)"))

# BAD - f-string interpolation and OFFSET skips rows as rows stop matching NULL
# LIMIT {batch_size} OFFSET {offset}

# GOOD - parameterized keyset batching with sa.text()
import time
import sqlalchemy as sa
from alembic import op

def upgrade():
    connection = op.get_bind()
    batch_size = 1000
    last_id = 0

    while True:
        rows = connection.execute(
            sa.text(
                """
                UPDATE users
                SET normalized_email = LOWER(email)
                WHERE id IN (
                    SELECT id FROM users
                    WHERE id > :last_id AND normalized_email IS NULL
                    ORDER BY id
                    LIMIT :batch_size
                )
                RETURNING id
                """
            ),
            {"last_id": last_id, "batch_size": batch_size},
        ).fetchall()

        if not rows:
            break

        last_id = max(row.id for row in rows)
        time.sleep(0.05)
```

*(For very large tables, perform schema changes in the migration and run the backfill via an async/background worker.)*

### 9. Blocking Index Creation vs `autocommit_block()`

**Problem**: Creating indexes inside a transaction locks table writes on large PostgreSQL tables; raw `op.execute("COMMIT")` breaks Alembic's transaction tracking.

```python
# BAD - locks table writes during index build
def upgrade():
    op.create_index("idx_users_email", "users", ["email"])

# BAD - manual COMMIT breaks Alembic's transaction state
def upgrade():
    op.execute("COMMIT")
    op.execute("CREATE INDEX CONCURRENTLY idx_users_email ON users(email)")

# GOOD - Alembic autocommit_block() with postgresql_concurrently=True
def upgrade():
    op.add_column("users", sa.Column("email", sa.String(255)))
    with op.get_context().autocommit_block():
        op.create_index(
            "idx_users_email",
            "users",
            ["email"],
            postgresql_concurrently=True,
        )

def downgrade():
    with op.get_context().autocommit_block():
        op.drop_index(
            "idx_users_email",
            table_name="users",
            postgresql_concurrently=True,
        )
    op.drop_column("users", "email")
```

### 10. Undocumented Risky Migrations

**Problem**: Reviewers/operators cannot tell expected lock duration or rollback safety.

Include a clear revision docstring summarizing table impact, backfill strategy, lock behavior, and rollback notes.

### 11. Missing Database-Level Check/Enum Constraints

**Problem**: Relying solely on app validation lets bad data enter via scripts or other services.

```python
def upgrade():
    op.add_column("users", sa.Column("age", sa.Integer))
    op.create_check_constraint(
        "ck_users_age_positive",
        "users",
        "age >= 0 AND age <= 150",
    )

def downgrade():
    op.drop_constraint("ck_users_age_positive", "users")
    op.drop_column("users", "age")
```

## Review Questions

1. Does every migration have a working `downgrade()` function?
2. Are new non-nullable columns added with `server_default` or via nullable -> backfill -> `nullable=False`?
3. Do data migrations use `sa.text()` / Core `table()` rather than application ORM models?
4. Are large backfills using parameterized keyset batching (no f-string SQL or `OFFSET`)?
5. Are concurrent PostgreSQL indexes created via `op.get_context().autocommit_block()` and `postgresql_concurrently=True` (not `op.execute("COMMIT")`)?
6. Are raw SQL `connection.execute(...)` calls wrapped in `sa.text(...)`?
