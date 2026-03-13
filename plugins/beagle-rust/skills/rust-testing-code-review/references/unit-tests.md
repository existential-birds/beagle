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

## Review Questions

1. Are unit tests in `#[cfg(test)]` modules within source files?
2. Do assertions use `assert_eq!` for value comparisons?
3. Are error variants checked specifically (not just "is error")?
4. Are test helpers extracted for repeated setup?
5. Do types that cross thread boundaries have Send/Sync tests?
6. Do serialized types have round-trip tests?
