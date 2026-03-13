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

Extract common setup into helper functions. Mark them with `#[allow(dead_code)]` if not all tests use them.

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

Use for complex structural output instead of large `assert_eq!` blocks:

```rust
use insta::assert_yaml_snapshot;

#[test]
fn test_config_serialization() {
    let config = Config::default();
    assert_yaml_snapshot!("default_config", config);
}

// Use redactions for unstable fields
#[test]
fn test_user_response() {
    let user = create_test_user();
    insta::assert_json_snapshot!(user, {
        ".created_at" => "[timestamp]",
        ".id" => "[uuid]"
    });
}
```

Best practices:
- Name snapshots descriptively
- Keep snapshots small and focused
- Use `assert_eq!` for simple values (numbers, flat enums)
- Run `cargo insta test` then `cargo insta review`

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
