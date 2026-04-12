# Integration Tests

## Test Directory Structure

```
project/
├── src/
│   └── lib.rs
└── tests/
    ├── common/
    │   └── mod.rs       # shared test utilities
    ├── api_test.rs       # integration test suite
    └── workflow_test.rs  # integration test suite
```

Each file in `tests/` is compiled as a separate crate with access only to the public API.

## Shared Test Utilities

```rust
// tests/common/mod.rs
use my_crate::Config;

pub fn test_config() -> Config {
    Config {
        database_url: std::env::var("TEST_DATABASE_URL")
            .unwrap_or_else(|_| "postgres://localhost:5433/test".into()),
        ..Config::default()
    }
}

pub async fn setup_test_db(pool: &PgPool) {
    sqlx::query("TRUNCATE users, orders CASCADE")
        .execute(pool)
        .await
        .expect("failed to clean test database");
}
```

```rust
// tests/api_test.rs
mod common;

#[tokio::test]
async fn test_create_user_returns_201() {
    let config = common::test_config();
    // ...
}
```

## Async Integration Tests

```rust
#[tokio::test]
async fn test_event_bus_delivers_to_all_subscribers() {
    let (tx, _) = broadcast::channel(100);

    let mut rx1 = tx.subscribe();
    let mut rx2 = tx.subscribe();

    tx.send(Event::new("test")).unwrap();

    let event1 = rx1.recv().await.unwrap();
    let event2 = rx2.recv().await.unwrap();

    assert_eq!(event1.name, "test");
    assert_eq!(event2.name, "test");
}
```

### Multi-Threaded Tests

When testing concurrent behavior, use `#[tokio::test(flavor = "multi_thread")]`:

```rust
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn test_concurrent_state_updates() {
    let state = Arc::new(Mutex::new(Vec::new()));
    let mut handles = Vec::new();

    for i in 0..10 {
        let state = Arc::clone(&state);
        handles.push(tokio::spawn(async move {
            let mut guard = state.lock().await;
            guard.push(i);
        }));
    }

    for handle in handles {
        handle.await.unwrap();
    }

    let guard = state.lock().await;
    assert_eq!(guard.len(), 10);
}
```

## Database Integration Tests

### Test Isolation

Each test should start with a clean state. Options:

1. **Truncate tables** — Fast, works for most cases
2. **Transaction rollback** — Test runs inside a transaction that's rolled back
3. **Separate database per test** — Most isolated, slowest

```rust
// Transaction rollback pattern
#[tokio::test]
async fn test_insert_user() {
    let pool = PgPool::connect(&test_database_url()).await.unwrap();
    let mut tx = pool.begin().await.unwrap();

    let user = sqlx::query_as!(User, "INSERT INTO users (name) VALUES ($1) RETURNING *", "Test")
        .fetch_one(&mut *tx)
        .await
        .unwrap();

    assert_eq!(user.name, "Test");
    // tx dropped here — rolls back automatically
}
```

### sqlx::test Macro

The `#[sqlx::test]` macro simplifies database test setup by automatically creating a fresh test database, running migrations, and cleaning up after each test. The connection pool is injected as a function argument.

```rust
#[sqlx::test]
async fn test_create_user(pool: PgPool) {
    // pool is a fresh database with migrations applied
    let result = sqlx::query!("INSERT INTO users (name) VALUES ($1) RETURNING id", "test")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert!(result.id > 0);
}
```

Use `migrations` to specify a custom migrations path, and `fixtures` to load SQL fixture files from `tests/fixtures/`:

```rust
#[sqlx::test(migrations = "db/migrations")]
async fn test_with_custom_migrations(pool: PgPool) {
    // uses migrations from db/migrations/ instead of the default
}

#[sqlx::test(fixtures("users", "orders"))]
async fn test_with_fixtures(pool: PgPool) {
    // tests/fixtures/users.sql and tests/fixtures/orders.sql are loaded
    let count = sqlx::query_scalar!("SELECT COUNT(*) FROM users")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert!(count.unwrap() > 0);
}
```

Prefer `#[sqlx::test]` over manual pool setup with `#[tokio::test]` for database tests — it eliminates boilerplate and guarantees test isolation without manual truncation or transaction rollback.

## Mocking with Traits

Define traits as seams for testing. Implement mock versions for tests.

Since Rust 1.75, `async fn` works directly in trait definitions without the `async-trait` crate. Prefer native syntax for new code.

```rust
// BAD (edition 2024) - unnecessary async-trait dependency
#[async_trait]
pub trait UserRepository: Send + Sync {
    async fn find(&self, id: Uuid) -> Result<Option<User>>;
    async fn create(&self, input: CreateUser) -> Result<User>;
}

// GOOD (edition 2024) - native async fn in traits
pub trait UserRepository: Send + Sync {
    fn find(&self, id: Uuid) -> impl Future<Output = Result<Option<User>>> + Send;
    fn create(&self, input: CreateUser) -> impl Future<Output = Result<User>> + Send;
}

// Also valid - async fn directly (simpler, but caller can't name the future type)
pub trait UserRepository: Send + Sync {
    async fn find(&self, id: Uuid) -> Result<Option<User>>;
    async fn create(&self, input: CreateUser) -> Result<User>;
}
```

Production and mock implementations:

```rust
// Production implementation
pub struct PgUserRepository { pool: PgPool }

impl UserRepository for PgUserRepository {
    async fn find(&self, id: Uuid) -> Result<Option<User>> {
        sqlx::query_as!(User, "SELECT ... WHERE id = $1", id)
            .fetch_optional(&self.pool)
            .await
            .map_err(Into::into)
    }
    // ...
}

// Test implementation
struct MockUserRepository {
    users: Vec<User>,
}

impl UserRepository for MockUserRepository {
    async fn find(&self, id: Uuid) -> Result<Option<User>> {
        Ok(self.users.iter().find(|u| u.id == id).cloned())
    }
    // ...
}
```

**When `async-trait` is still needed:** Native `async fn` in traits does not support `dyn Trait` dispatch. If your code requires `Box<dyn UserRepository>`, keep using `async-trait` for that trait. See `beagle-rust:tokio-async-code-review` for async trait patterns in detail.

## `if let` Temporary Scope in Test Assertions (Edition 2024)

In edition 2024, temporaries in `if let` conditions are dropped at the end of the **condition**, not at the end of the block. This affects test patterns that inline method calls in `if let` conditions.

```rust
// BAD (edition 2024) - temporary lock guard drops after condition evaluates
// val may be a dangling reference inside the block
#[tokio::test]
async fn test_cache_hit() {
    let cache = setup_cache().await;
    if let Some(val) = cache.lock().await.get("key") {
        assert_eq!(val, "expected"); // guard already dropped!
    }
}

// GOOD (edition 2024) - bind the guard to extend its lifetime
#[tokio::test]
async fn test_cache_hit() {
    let cache = setup_cache().await;
    let guard = cache.lock().await;
    if let Some(val) = guard.get("key") {
        assert_eq!(val, "expected"); // guard lives through the block
    }
}
```

This also affects non-async patterns with `RefCell`, `Mutex`, or any method returning a temporary with borrowed data:

```rust
// BAD (edition 2024) - RefCell borrow drops after condition
if let Some(item) = state.borrow().items.first() {
    assert_eq!(item.name, "test"); // borrow already dropped
}

// GOOD - bind the borrow
let borrowed = state.borrow();
if let Some(item) = borrowed.items.first() {
    assert_eq!(item.name, "test");
}
```

See `beagle-rust:tokio-async-code-review` for more `if let` temporary scope patterns with async lock guards.

## Test Configuration

Use environment variables or test-specific config files:

```rust
fn test_database_url() -> String {
    std::env::var("TEST_DATABASE_URL")
        .unwrap_or_else(|_| "postgres://postgres:postgres@localhost:5433/test".into())
}
```

For structured logging in tests:

```rust
// Initialize tracing subscriber for test output
use tracing_subscriber::fmt;

#[tokio::test]
async fn test_with_logging() {
    let _ = fmt::try_init(); // ignore error if already initialized
    tracing::info!("test starting");
    // ...
}
```

## Review Questions

1. Are integration tests in the `tests/` directory?
2. Is shared test setup extracted to a `common` module?
3. Are database tests isolated (no cross-test contamination)?
4. Are traits used as seams for dependency injection in tests?
5. Is `#[tokio::test]` used for async tests?
6. Are multi-threaded tests using `flavor = "multi_thread"`?
7. Are database tests using `#[sqlx::test]` instead of manual pool setup?
8. Are mock traits using native `async fn` instead of `async-trait` where possible?
9. Do `if let` assertions with inline temporaries (lock guards, borrows) account for edition 2024 temporary scoping?
10. Is `#[expect]` used instead of `#[allow]` for test-specific lint suppressions?
