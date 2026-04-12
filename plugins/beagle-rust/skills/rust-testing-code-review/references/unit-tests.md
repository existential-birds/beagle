# Unit Tests

## Standard Structure

```rust
// In src/types.rs
pub enum Status {
    Active,
    Inactive,
}

impl Status {
    pub fn is_active(&self) -> bool {
        matches!(self, Self::Active)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_status_active_returns_true() {
        assert!(Status::Active.is_active());
    }

    #[test]
    fn test_status_inactive_returns_false() {
        assert!(!Status::Inactive.is_active());
    }
}
```

## Assertion Patterns

### Value Comparisons

```rust
// BAD - error message is just "assertion failed"
assert!(result == 42);

// GOOD - shows left and right values on failure
assert_eq!(result, 42);
assert_ne!(result, 0);

// With context
assert_eq!(result, 42, "expected 42 for input {input}");
```

### Enum Variant Checking

```rust
// BAD - verbose pattern matching
match result {
    Err(Error::NotFound(_)) => (),
    other => panic!("expected NotFound, got {other:?}"),
}

// GOOD - matches! macro
assert!(matches!(result, Err(Error::NotFound(_))));

// With message
assert!(
    matches!(result, Err(Error::NotFound(id)) if id == expected_id),
    "expected NotFound for {expected_id}, got {result:?}"
);
```

### Result Testing

```rust
// Return Result from test for cleaner error propagation
#[test]
fn test_parse_valid_input() -> Result<(), Error> {
    let config = parse("valid input")?;
    assert_eq!(config.name, "expected");
    Ok(())
}

// Test error cases
#[test]
fn test_parse_empty_input_returns_error() {
    let result = parse("");
    assert!(matches!(result, Err(Error::Empty)));
}
```

### Should Panic

Use sparingly. Prefer `Result`-returning tests.

```rust
// ACCEPTABLE - when testing an intentional panic
#[test]
#[should_panic(expected = "index out of bounds")]
fn test_invalid_index_panics() {
    let list = FixedList::new(5);
    list.get(10); // should panic
}
```

## Test Helpers

Extract common setup into helper functions. Mark them with `#[expect(dead_code)]` (edition 2024) or `#[allow(dead_code)]` if not all tests use them.

```rust
#[cfg(test)]
mod tests {
    use super::*;

    fn sample_user() -> User {
        User {
            id: Uuid::nil(),
            name: "Test User".into(),
            email: "test@example.com".into(),
        }
    }

    fn sample_config() -> Config {
        Config {
            port: 8080,
            host: "localhost".into(),
            ..Config::default()
        }
    }
}
```

## Send + Sync Verification

Verify that types satisfy thread-safety bounds at compile time:

```rust
#[test]
fn assert_error_is_send_sync() {
    fn assert_send_sync<T: Send + Sync>() {}
    assert_send_sync::<Error>();
    assert_send_sync::<WorkflowError>();
}
```

## Serialization Round-Trip Tests

```rust
#[test]
fn test_status_serialization_round_trip() {
    let original = Status::InProgress;
    let json = serde_json::to_string(&original).unwrap();
    let deserialized: Status = serde_json::from_str(&json).unwrap();
    assert_eq!(original, deserialized);
}

#[test]
fn test_status_serializes_to_expected_string() {
    let status = Status::InProgress;
    let s = serde_json::to_string(&status).unwrap();
    assert_eq!(s, r#""in_progress""#);
}
```

## Test Naming Convention

Nested modules make test output readable and allow running groups:

```rust
#[cfg(test)]
mod tests {
    use super::*;

    mod parse_config {
        use super::*;

        #[test]
        fn returns_config_when_valid_toml() {
            let config = parse_config(VALID_TOML).unwrap();
            assert_eq!(config.port, 8080);
        }

        #[test]
        fn returns_error_when_empty_input() {
            let err = parse_config("").unwrap_err();
            assert!(matches!(err, ParseError::Empty));
        }

        #[test]
        fn returns_error_when_missing_required_field() {
            let err = parse_config("[server]").unwrap_err();
            assert!(matches!(err, ParseError::MissingField(_)));
        }
    }
}
```

Output: `tests::parse_config::returns_config_when_valid_toml`, etc.

## One Assertion Per Test

Each test should verify one behavior. This makes failures easier to diagnose:

```rust
// BAD - which assertion failed?
#[test]
fn test_valid_inputs() {
    assert!(parse("a").is_ok());
    assert!(parse("ab").is_ok());
    assert!(parse("abc").is_ok());
}

// GOOD - descriptive separate tests, or use rstest
#[rstest]
#[case::single_char("a")]
#[case::two_chars("ab")]
#[case::three_chars("abc")]
fn parse_accepts_valid_strings(#[case] input: &str) {
    assert!(parse(input).is_ok(), "parse failed for: {input}");
}
```

## Snapshot Testing with `cargo insta`

Snapshot testing compares output against a saved "golden" version. On future runs, the test fails if output changes unless explicitly approved.

### Setup

```toml
# Cargo.toml
[dev-dependencies]
insta = { version = "1", features = ["yaml"] }
```

Install the CLI for better review workflow: `cargo install cargo-insta`

### Assert Macros

```rust
use insta::{assert_snapshot, assert_yaml_snapshot, assert_json_snapshot};

// Plain text snapshots
#[test]
fn test_error_display() {
    let err = MyError::NotFound("user-123".into());
    assert_snapshot!("error_not_found", err.to_string());
}

// YAML snapshots (best for version control diffs)
#[test]
fn test_config_serialization() {
    let config = Config::default();
    assert_yaml_snapshot!("default_config", config);
}

// JSON snapshots with redactions for unstable fields
#[test]
fn test_user_response() {
    let user = create_test_user();
    assert_json_snapshot!(user, {
        ".created_at" => "[timestamp]",
        ".id" => "[uuid]"
    });
}
```

### Review Workflow

1. Write test with `assert_snapshot!` / `assert_yaml_snapshot!` / `assert_json_snapshot!`
2. Run `cargo insta test` — creates pending snapshots
3. Run `cargo insta review` — interactively accept or reject changes
4. Commit the `.snap` files in `snapshots/` alongside your tests

### When to Use Snapshots

- Serialized output (JSON, YAML, TOML)
- Error message formatting (`Display` impls)
- CLI output, rendered HTML, generated code
- Complex nested structures where `assert_eq!` is unwieldy

### When NOT to Use Snapshots

- Simple values — use `assert_eq!(x, 42)` instead
- Critical path logic — precise unit tests catch regressions faster
- Flaky/random output — use redactions or avoid snapshots entirely
- Huge objects — keep snapshots small and focused for easier review

## Parametrized Testing with `rstest`

`rstest` eliminates duplicated test functions when testing the same behavior with different inputs.

### Setup

```toml
# Cargo.toml
[dev-dependencies]
rstest = "0.23"
```

### Basic Parametrized Tests

```rust
use rstest::rstest;

#[rstest]
#[case::empty("", true)]
#[case::whitespace("  ", true)]
#[case::content("hello", false)]
fn is_blank_returns_expected(#[case] input: &str, #[case] expected: bool) {
    assert_eq!(is_blank(input), expected);
}
```

Each `#[case]` generates a separate test with a descriptive name: `is_blank_returns_expected::empty`, etc.

### Fixtures

Share setup logic across tests with `#[fixture]`:

```rust
use rstest::{fixture, rstest};

#[fixture]
fn test_db() -> TestDb {
    TestDb::new("sqlite::memory:")
}

#[rstest]
fn insert_user_succeeds(test_db: TestDb) {
    let user = User::new("Alice");
    assert!(test_db.insert(&user).is_ok());
}

#[rstest]
fn query_missing_user_returns_none(test_db: TestDb) {
    assert!(test_db.find_user("nonexistent").is_none());
}
```

### Async Parametrized Tests

Combine `rstest` with `tokio::test`:

```rust
#[rstest]
#[case::valid_url("https://example.com", true)]
#[case::invalid_url("not-a-url", false)]
#[tokio::test]
async fn fetch_url_validates(#[case] url: &str, #[case] should_succeed: bool) {
    let result = fetch(url).await;
    assert_eq!(result.is_ok(), should_succeed);
}
```

### Considerations

- Descriptive case names are important — `#[case::empty_input("")]` beats `#[case("")]`
- It is harder for IDEs to run/locate specific parametrized tests
- For complex per-case setup, separate test functions may be clearer

## Doc Tests

Public API examples that double as tests:

```rust
/// Adds two numbers together.
///
/// # Examples
///
/// ```rust
/// # use my_crate::add;
/// assert_eq!(add(2, 3), 5);
/// ```
pub fn add(a: i32, b: i32) -> i32 {
    a + b
}
```

Doc test attributes: `ignore`, `should_panic`, `no_run`, `compile_fail`.

Note: `cargo test --doc` runs doc tests. `cargo nextest` does NOT — run separately.

## Testing Error Messages

When errors don't implement `PartialEq`, test via `Display`:

```rust
#[test]
fn divide_by_zero_error_message() {
    let err = divide(10.0, 0.0).unwrap_err();
    assert_eq!(err.to_string(), "division by zero");
}
```

## `#[expect]` for Test Lint Suppression (Stable Since 1.81)

`#[expect(lint)]` is a self-cleaning alternative to `#[allow(lint)]`. The compiler warns when the suppressed lint no longer triggers, preventing stale suppressions from accumulating in test code.

```rust
// BAD - stale suppression goes undetected forever
#[allow(unused_variables)]
#[test]
fn test_complex_setup() {
    let db = setup_db();
    let _cache = setup_cache(); // if _cache is later removed, #[allow] stays silently
    assert!(db.is_connected());
}

// GOOD - compiler warns when suppression is no longer needed
#[expect(unused_variables, reason = "cache setup needed for side effects")]
#[test]
fn test_complex_setup() {
    let db = setup_db();
    let _cache = setup_cache();
    assert!(db.is_connected());
}
```

Common test-specific suppressions to migrate:

| `#[allow(...)]` | `#[expect(...)]` | When to use |
|-----------------|------------------|-------------|
| `#[allow(dead_code)]` | `#[expect(dead_code)]` | Test helpers not used by every test |
| `#[allow(unused_variables)]` | `#[expect(unused_variables)]` | Setup vars kept for side effects |
| `#[allow(clippy::needless_return)]` | `#[expect(clippy::needless_return)]` | Explicit returns for test clarity |

## `LazyLock` for Test Fixtures (Stable Since 1.80)

`std::sync::LazyLock` replaces `lazy_static!` and `once_cell::sync::Lazy` for shared test fixtures that are expensive to construct. Thread-safe by default.

```rust
// BAD - external dependency for test fixture
use lazy_static::lazy_static;
lazy_static! {
    static ref TEST_CONFIG: Config = Config::load("test.toml").unwrap();
}

// BAD - also external dependency
use once_cell::sync::Lazy;
static TEST_CONFIG: Lazy<Config> = Lazy::new(|| Config::load("test.toml").unwrap());

// GOOD (edition 2024) - std library, no external crate
use std::sync::LazyLock;
static TEST_CONFIG: LazyLock<Config> = LazyLock::new(|| Config::load("test.toml").unwrap());
```

For test fixtures that don't need to cross thread boundaries, use `std::cell::LazyCell` instead.

**Note:** `tokio::sync::OnceCell` is still preferred when fixture initialization requires `.await`.

## Tail Expression Temporary Scope (Edition 2024)

In edition 2024, temporaries in tail expressions are dropped **before** local variables. This can affect test functions that return `Result` and create temporaries in the return expression.

```rust
// Edition 2021 - temporaries in tail expression outlive locals
#[test]
fn test_parse_config() -> Result<(), Error> {
    let input = "key=value";
    // temporary String from to_string() lives until end of function
    Ok(parse(input.to_string().as_str())?)
}

// Edition 2024 - temporary String drops BEFORE the function returns
// This may cause "temporary value dropped while borrowed" errors
// Fix: bind the temporary to a local variable
#[test]
fn test_parse_config() -> Result<(), Error> {
    let input = "key=value";
    let owned = input.to_string();
    Ok(parse(owned.as_str())?)
}
```

This primarily affects tests that chain method calls in the return position. If the compiler reports "temporary value dropped while borrowed" after an edition migration, bind the temporary to a `let` binding.

## Review Questions

1. Are unit tests in `#[cfg(test)]` modules within source files?
2. Do assertions use `assert_eq!` for value comparisons?
3. Are error variants checked specifically (not just "is error")?
4. Are test helpers extracted for repeated setup?
5. Do types that cross thread boundaries have Send/Sync tests?
6. Do serialized types have round-trip tests?
7. Are tests named descriptively (not `test_happy_path`)?
8. Do tests verify one behavior each?
9. Is snapshot testing used for complex structural output?
10. Do public API functions have doc test examples?
11. Is `#[expect]` used instead of `#[allow]` for test-specific lint suppressions?
12. Are `lazy_static!` / `once_cell` test fixtures replaced with `std::sync::LazyLock` when MSRV allows?
13. Do tail expression temporaries in `Result`-returning tests avoid dangling borrows under edition 2024?
