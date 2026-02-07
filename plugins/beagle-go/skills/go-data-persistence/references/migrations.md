# Database Migrations with golang-migrate

## Overview

**golang-migrate** is the standard migration tool for Go applications using raw SQL. It manages versioned migration files, tracks which migrations have been applied, and supports both programmatic and CLI usage.

Install the CLI:

```bash
go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest
```

## File Naming Convention

Migrations are pairs of SQL files stored in a `migrations/` directory:

```
migrations/
├── 000001_create_users.up.sql
├── 000001_create_users.down.sql
├── 000002_add_user_roles.up.sql
├── 000002_add_user_roles.down.sql
├── 000003_create_orders.up.sql
└── 000003_create_orders.down.sql
```

Format: `{version}_{description}.{direction}.sql`

- **version**: zero-padded sequential number (6 digits recommended for sorting)
- **description**: snake_case description of the change
- **direction**: `up` (apply) or `down` (revert)

Generate a new migration pair with the CLI:

```bash
migrate create -ext sql -dir migrations -seq add_user_roles
```

This creates both `up.sql` and `down.sql` files with the next sequential version number.

## Example Migrations

### Creating a table

```sql
-- 000001_create_users.up.sql
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_users_email ON users(email);

-- 000001_create_users.down.sql
DROP TABLE IF EXISTS users;
```

### Adding columns

```sql
-- 000002_add_user_roles.up.sql
ALTER TABLE users ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'user';
CREATE INDEX idx_users_role ON users(role);

-- 000002_add_user_roles.down.sql
DROP INDEX IF EXISTS idx_users_role;
ALTER TABLE users DROP COLUMN IF EXISTS role;
```

### Creating a related table

```sql
-- 000003_create_orders.up.sql
CREATE TABLE IF NOT EXISTS orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    total_cents BIGINT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_status ON orders(status);

-- 000003_create_orders.down.sql
DROP TABLE IF EXISTS orders;
```

## Running Migrations in Code

Embed migrations in your binary and run them at application startup:

```go
import (
    "embed"
    "fmt"

    "github.com/golang-migrate/migrate/v4"
    _ "github.com/golang-migrate/migrate/v4/database/postgres"
    "github.com/golang-migrate/migrate/v4/source/iofs"
)

//go:embed migrations/*.sql
var migrationsFS embed.FS

func runMigrations(dbURL string) error {
    source, err := iofs.New(migrationsFS, "migrations")
    if err != nil {
        return fmt.Errorf("creating migration source: %w", err)
    }

    m, err := migrate.NewWithSourceInstance("iofs", source, dbURL)
    if err != nil {
        return fmt.Errorf("creating migrator: %w", err)
    }

    if err := m.Up(); err != nil && err != migrate.ErrNoChange {
        return fmt.Errorf("running migrations: %w", err)
    }

    version, dirty, _ := m.Version()
    slog.Info("migrations complete", "version", version, "dirty", dirty)

    return nil
}
```

### File-based migrations (without embedding)

```go
func runMigrations(dbURL string) error {
    m, err := migrate.New("file://migrations", dbURL)
    if err != nil {
        return fmt.Errorf("creating migrator: %w", err)
    }

    if err := m.Up(); err != nil && err != migrate.ErrNoChange {
        return fmt.Errorf("running migrations: %w", err)
    }

    return nil
}
```

### Integration in main()

```go
func run(ctx context.Context) error {
    dbURL := os.Getenv("DATABASE_URL")

    // Run migrations before opening the connection pool
    if err := runMigrations(dbURL); err != nil {
        return fmt.Errorf("running migrations: %w", err)
    }

    db, err := sql.Open("postgres", dbURL)
    if err != nil {
        return fmt.Errorf("opening db: %w", err)
    }
    defer db.Close()

    // ... rest of app setup ...
}
```

## CLI Usage

```bash
# Apply all pending migrations
migrate -database "$DATABASE_URL" -path migrations up

# Apply the next N migrations
migrate -database "$DATABASE_URL" -path migrations up 2

# Rollback the last migration
migrate -database "$DATABASE_URL" -path migrations down 1

# Rollback all migrations
migrate -database "$DATABASE_URL" -path migrations down

# Go to a specific version
migrate -database "$DATABASE_URL" -path migrations goto 3

# Show current migration version
migrate -database "$DATABASE_URL" -path migrations version

# Force a version (useful for fixing dirty state)
migrate -database "$DATABASE_URL" -path migrations force 3
```

## Writing Safe Migrations

### Idempotency

Always use `IF NOT EXISTS` and `IF EXISTS` so that migrations can be retried safely after partial failures:

```sql
-- Good: idempotent
CREATE TABLE IF NOT EXISTS users (...);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
ALTER TABLE users ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'user';

-- Bad: fails on re-run
CREATE TABLE users (...);
CREATE INDEX idx_users_email ON users(email);
```

### Use Transactions

Wrap DDL statements in transactions when the database supports transactional DDL (PostgreSQL does):

```sql
-- 000004_add_audit_fields.up.sql
BEGIN;

ALTER TABLE users ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMPTZ;
ALTER TABLE users ADD COLUMN IF NOT EXISTS login_count INTEGER NOT NULL DEFAULT 0;

COMMIT;
```

If any statement within the transaction fails, all changes are rolled back, leaving the schema in a consistent state.

### Large Table Migrations

For tables with millions of rows, certain operations lock the table and block reads/writes. Use these strategies:

```sql
-- Bad: locks the entire table while building the index
CREATE INDEX idx_orders_created_at ON orders(created_at);

-- Good: builds the index without locking
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_orders_created_at ON orders(created_at);
```

Note: `CREATE INDEX CONCURRENTLY` cannot run inside a transaction. For migrations that include concurrent index creation, do not wrap them in `BEGIN/COMMIT`.

For adding columns with defaults on large tables (PostgreSQL 11+), `ALTER TABLE ADD COLUMN ... DEFAULT` is safe and fast because PostgreSQL stores the default value in the catalog rather than rewriting the table.

### Separate Data and Schema Migrations

Keep data transformations in separate migration files from schema changes:

```
migrations/
├── 000005_add_full_name_column.up.sql      # Schema: add column
├── 000005_add_full_name_column.down.sql
├── 000006_populate_full_name.up.sql         # Data: backfill
├── 000006_populate_full_name.down.sql
├── 000007_drop_first_last_name.up.sql       # Schema: remove old columns
└── 000007_drop_first_last_name.down.sql
```

This three-step approach (add new, backfill, remove old) allows zero-downtime deployments because the application can read from either the old or new columns during the transition.

## Rolling Back Migrations

### When to Roll Back

- A migration introduced a bug that affects production
- A deployment failed partway through and the database is in a dirty state
- You need to revert a schema change before deploying a fix

### How to Roll Back

```bash
# Roll back the last applied migration
migrate -database "$DATABASE_URL" -path migrations down 1
```

### Handling Dirty State

If a migration fails partway through, golang-migrate marks the migration version as "dirty." You cannot apply further migrations until the dirty flag is cleared.

```bash
# Check current state
migrate -database "$DATABASE_URL" -path migrations version
# Output: 5 (dirty)

# Option 1: Fix the issue and force the version
migrate -database "$DATABASE_URL" -path migrations force 4  # Revert to last clean version

# Option 2: Manually fix the database, then force to the current version
migrate -database "$DATABASE_URL" -path migrations force 5  # Mark as clean
```

### Writing Reversible Down Migrations

Not all migrations are easily reversible. For destructive operations, the down migration should be a best-effort approximation:

```sql
-- 000005_drop_legacy_column.up.sql
ALTER TABLE users DROP COLUMN IF EXISTS legacy_field;

-- 000005_drop_legacy_column.down.sql
-- Cannot restore data, but can restore the column
ALTER TABLE users ADD COLUMN IF NOT EXISTS legacy_field TEXT;
```

Document in comments when a down migration cannot fully restore the previous state.

## Migration Rules

1. **Never modify a migration that has been applied in production.** Create a new migration to make corrections.
2. **Always write both up and down migrations.** Even if the down migration is imperfect, it provides a rollback path.
3. **Use `IF NOT EXISTS` / `IF EXISTS`** for idempotent, retriable migrations.
4. **Use transactions** for multi-statement migrations (except when using `CONCURRENTLY`).
5. **Separate data migrations from schema migrations.** This keeps each migration focused and allows staged rollouts.
6. **Add indexes concurrently** on large tables to avoid blocking reads and writes.
7. **Test migrations** against a copy of production data before deploying. Schema changes that work on an empty table may lock or fail on a table with millions of rows.
8. **Version control your migrations.** They are part of the codebase and should be reviewed in pull requests.

## Migrations in CI/CD

### CI Pipeline

Run migrations as part of your test pipeline against a test database:

```yaml
# GitHub Actions example
jobs:
  test:
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
          POSTGRES_DB: testdb
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v4

      - name: Run migrations
        run: |
          migrate -database "postgres://test:test@localhost:5432/testdb?sslmode=disable" \
                  -path migrations up

      - name: Run tests
        run: go test ./...
        env:
          DATABASE_URL: postgres://test:test@localhost:5432/testdb?sslmode=disable
```

### CD Pipeline

For production deployments, run migrations before deploying the new application version:

```bash
# 1. Run migrations against production database
migrate -database "$PROD_DATABASE_URL" -path migrations up

# 2. Deploy new application version
# (only after migrations succeed)
```

If migrations fail, do not deploy the new application version. Fix the migration issue first, then retry.

### Multi-Instance Deployments

golang-migrate uses an advisory lock in PostgreSQL to prevent concurrent migration runs. This means it is safe to run migrations from multiple instances simultaneously -- only one will execute, the others will wait or skip.

However, it is cleaner to run migrations as a separate step (e.g., a Kubernetes Job or an init container) rather than having every application instance attempt to migrate on startup.
