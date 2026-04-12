# Migrations and Pool Management

## Connection Pool Configuration

### Creating the Pool

```rust
use sqlx::postgres::PgPoolOptions;

let pool = PgPoolOptions::new()
    .max_connections(20)
    .min_connections(5)
    .acquire_timeout(Duration::from_secs(5))
    .idle_timeout(Duration::from_secs(600))
    .max_lifetime(Duration::from_secs(1800))
    .connect(&database_url)
    .await?;
```

### Edition 2024: Static Pool with `LazyLock`

For applications that initialize a global pool once, use `std::sync::LazyLock` instead of `once_cell::sync::Lazy` or `lazy_static!`. `LazyLock` is in std since Rust 1.80.

```rust
// BAD — third-party crate, unnecessary dependency
use once_cell::sync::Lazy;

static POOL: Lazy<PgPool> = Lazy::new(|| {
    tokio::runtime::Handle::current().block_on(async {
        PgPoolOptions::new()
            .max_connections(20)
            .connect(&std::env::var("DATABASE_URL").unwrap())
            .await
            .unwrap()
    })
});

// GOOD — std library, no extra dependency
use std::sync::LazyLock;

static POOL: LazyLock<PgPool> = LazyLock::new(|| {
    tokio::runtime::Handle::current().block_on(async {
        PgPoolOptions::new()
            .max_connections(20)
            .connect(&std::env::var("DATABASE_URL").unwrap())
            .await
            .unwrap()
    })
});
```

Note: Framework-managed state (e.g., axum `State<PgPool>`) is still preferred over global statics. Use `LazyLock` only when a static singleton is genuinely needed.

### Pool Sizing Guidelines

- **Web servers:** 2-4× the number of async worker threads
- **Background workers:** Match to the number of concurrent jobs
- **Default (5):** Too low for most production workloads
- **Maximum:** Don't exceed the database's `max_connections` minus connections reserved for admin/monitoring

### Common Mistake: Pool Per Request

```rust
// BAD - creates a new pool (and connections) per request
async fn handle(req: Request) -> Response {
    let pool = PgPool::connect(&url).await.unwrap();
    let user = query_as!(User, "...", id).fetch_one(&pool).await?;
    // pool dropped, connections closed
}

// GOOD - share pool via application state
async fn handle(State(pool): State<PgPool>, req: Request) -> Response {
    let user = query_as!(User, "...", id).fetch_one(&pool).await?;
}
```

## Transactions

### Basic Pattern

```rust
let mut tx = pool.begin().await?;

sqlx::query!("INSERT INTO orders (user_id, total) VALUES ($1, $2)", user_id, total)
    .execute(&mut *tx)
    .await?;

sqlx::query!("UPDATE inventory SET count = count - $1 WHERE item_id = $2", qty, item_id)
    .execute(&mut *tx)
    .await?;

tx.commit().await?;
```

If `tx` is dropped without calling `.commit()`, the transaction rolls back automatically. This is a safety net — explicit commit is clearer.

### Error Handling in Transactions

```rust
async fn create_order(pool: &PgPool, order: NewOrder) -> Result<Order, Error> {
    let mut tx = pool.begin().await?;

    let order = sqlx::query_as!(Order, "INSERT INTO orders ... RETURNING *", ...)
        .fetch_one(&mut *tx)
        .await
        .map_err(|e| {
            // tx will rollback on drop
            Error::OrderCreate { source: e }
        })?;

    for item in &order.items {
        sqlx::query!("INSERT INTO order_items ...", ...)
            .execute(&mut *tx)
            .await?;
    }

    tx.commit().await?;
    Ok(order)
}
```

### Savepoints (Nested Transactions)

```rust
let mut tx = pool.begin().await?;

// Outer operation
sqlx::query!("INSERT INTO audit_log ...").execute(&mut *tx).await?;

// Inner operation that might fail independently
let savepoint = tx.begin().await?; // creates a savepoint
match try_optional_operation(&mut *savepoint).await {
    Ok(_) => savepoint.commit().await?,
    Err(_) => {
        // savepoint rolls back, outer transaction continues
        tracing::warn!("optional operation failed, continuing");
    }
}

tx.commit().await?;
```

## Migrations

### File Structure

```
migrations/
├── 20240115100000_create_users.sql
├── 20240115100001_create_orders.sql
└── 20240220150000_add_user_email.sql
```

### Running Migrations

```rust
// At application startup
sqlx::migrate!("./migrations")
    .run(&pool)
    .await?;
```

### Migration Safety Rules

1. **Never modify an applied migration** — Create a new one instead
2. **Separate schema and data migrations** — Mixing DDL and DML in one migration increases lock contention and makes rollbacks operationally risky
3. **Make migrations idempotent where possible** — `IF NOT EXISTS`, `IF EXISTS`
4. **Destructive migrations need a plan** — `DROP COLUMN` and `DROP TABLE` should be preceded by a data migration that archives/moves data

### Reversible Migration Pattern

```sql
-- 20240220150000_add_user_email.sql
ALTER TABLE users ADD COLUMN IF NOT EXISTS email TEXT;

-- To reverse (keep as documentation or in a separate down file):
-- ALTER TABLE users DROP COLUMN IF EXISTS email;
```

## Review Questions

1. Is the pool shared across the application (not created per-request)?
2. Is pool size configured appropriately for the deployment?
3. Are transactions used for multi-statement writes?
4. Are transactions committed explicitly?
5. Are migrations safe (no data loss, idempotent, separate DDL/DML)?
6. Is `sqlx::migrate!()` called at startup?
7. (Edition 2024) Does static pool initialization use `std::sync::LazyLock` instead of `once_cell` or `lazy_static!`?
