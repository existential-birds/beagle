# Queries

## Compile-Time Checked Queries

sqlx verifies queries against the database schema at compile time. This catches column name typos, type mismatches, and invalid SQL before runtime.

### query! Macro

Returns an anonymous struct with fields matching the query columns.

```rust
// Compile-time checked — column names and types verified
let row = sqlx::query!(
    "SELECT id, name, email FROM users WHERE id = $1",
    user_id
)
.fetch_one(&pool)
.await?;

let name: String = row.name;
let email: Option<String> = row.email; // nullable column → Option
```

### query_as! Macro

Maps results directly to a named struct. Preferred for reusable result types.

```rust
#[derive(Debug)]
struct User {
    id: Uuid,
    name: String,
    email: Option<String>,
    created_at: DateTime<Utc>,
}

let user = sqlx::query_as!(
    User,
    "SELECT id, name, email, created_at FROM users WHERE id = $1",
    user_id
)
.fetch_optional(&pool)
.await?;
```

### Offline Mode

For CI/CD where the database isn't available, sqlx caches query metadata in `sqlx-data.json` (or `.sqlx/` directory):

```bash
# Generate cache from live database
cargo sqlx prepare

# Build uses cached metadata when DATABASE_URL is absent
cargo build
```

## Fetch Methods

| Method | Returns | Use When |
|--------|---------|----------|
| `.fetch_one()` | `T` (error if 0 or 2+ rows) | Exactly one row expected (by PK) |
| `.fetch_optional()` | `Option<T>` | Zero or one row expected |
| `.fetch_all()` | `Vec<T>` | Small, bounded result set |
| `.fetch()` | `Stream<Item = Result<T>>` | Large or unbounded results |

### Common Mistake: fetch_one for Lookups

```rust
// BAD - returns Err(RowNotFound) on "not found" which is an expected case
let user = sqlx::query_as!(User, "SELECT ... WHERE id = $1", id)
    .fetch_one(&pool)
    .await?; // RowNotFound error for missing users

// GOOD - "not found" is a normal case, not an error
let user = sqlx::query_as!(User, "SELECT ... WHERE id = $1", id)
    .fetch_optional(&pool)
    .await?;
match user {
    Some(user) => Ok(user),
    None => Err(Error::NotFound(id)),
}
```

### Streaming Large Results

```rust
use futures::TryStreamExt;

let mut stream = sqlx::query_as!(Event, "SELECT * FROM events WHERE workflow_id = $1", wf_id)
    .fetch(&pool);

while let Some(event) = stream.try_next().await? {
    process(event).await;
}
```

## Bind Parameters

Always use bind parameters (`$1`, `$2` for Postgres; `?` for MySQL/SQLite). Never interpolate values into query strings.

```rust
// BAD - SQL injection vulnerability
let query = format!("SELECT * FROM users WHERE name = '{}'", name);
sqlx::query(&query).fetch_one(&pool).await?;

// GOOD - parameterized query
sqlx::query("SELECT * FROM users WHERE name = $1")
    .bind(&name)
    .fetch_one(&pool)
    .await?;

// BEST - compile-time checked
sqlx::query!("SELECT * FROM users WHERE name = $1", name)
    .fetch_one(&pool)
    .await?;
```

## Type Mapping

### Rust ↔ PostgreSQL

| Rust Type | PostgreSQL Type |
|-----------|-----------------|
| `i32` | `INT4` / `INTEGER` |
| `i64` | `INT8` / `BIGINT` |
| `f64` | `FLOAT8` / `DOUBLE PRECISION` |
| `Decimal` | `NUMERIC` / `DECIMAL` |
| `String` | `TEXT` / `VARCHAR` |
| `bool` | `BOOL` |
| `Uuid` | `UUID` |
| `DateTime<Utc>` | `TIMESTAMPTZ` |
| `NaiveDateTime` | `TIMESTAMP` |
| `serde_json::Value` | `JSONB` / `JSON` |
| `Vec<u8>` | `BYTEA` |
| `Option<T>` | Nullable column |

### Custom Enum Types

```rust
#[derive(Debug, Clone, sqlx::Type, Serialize, Deserialize)]
#[sqlx(type_name = "varchar", rename_all = "snake_case")]
#[serde(rename_all = "snake_case")]
pub enum Status {
    Pending,
    InProgress,
    Complete,
    Failed,
}
```

Ensure `rename_all` matches between `sqlx::Type` and `serde` — mismatches cause silent bugs where data written by one system can't be read by the other.

## Review Questions

1. Are queries compile-time checked where possible?
2. Is `.fetch_optional()` used for lookups that may return no rows?
3. Are bind parameters used (no string interpolation)?
4. Is `.fetch()` streaming used for large result sets?
5. Do Rust types match PostgreSQL column types?
6. Are enum representations consistent between sqlx and serde?
