# Custom Serialization

## When Custom Implementation is Needed

Derive handles most cases. Custom implementations are warranted for:
- Format-specific representations (dates, UUIDs, durations)
- Validation during deserialization
- Backwards-compatible format changes
- Types from external crates without serde support

## serde(with) Module Pattern

The cleanest approach for custom field serialization. Create a module with `serialize` and `deserialize` functions:

```rust
mod iso_date {
    use chrono::{DateTime, Utc};
    use serde::{self, Deserialize, Deserializer, Serializer};

    pub fn serialize<S>(date: &DateTime<Utc>, s: S) -> Result<S::Ok, S::Error>
    where S: Serializer {
        s.serialize_str(&date.to_rfc3339())
    }

    pub fn deserialize<'de, D>(d: D) -> Result<DateTime<Utc>, D::Error>
    where D: Deserializer<'de> {
        let s = String::deserialize(d)?;
        DateTime::parse_from_rfc3339(&s)
            .map(|dt| dt.with_timezone(&Utc))
            .map_err(serde::de::Error::custom)
    }
}

#[derive(Serialize, Deserialize, PartialEq, Debug)]
struct Event {
    #[serde(with = "iso_date")]
    created_at: DateTime<Utc>,
}
```

For `Option<T>` fields, use `serialize_with` + `deserialize_with` separately or use the `serde_with` crate.

## Validating Deserialization

When deserialized data needs validation, implement `Deserialize` manually or use `#[serde(try_from)]`:

```rust
#[derive(Serialize, Deserialize)]
#[serde(try_from = "String")]
struct Email(String);

impl TryFrom<String> for Email {
    type Error = String;
    fn try_from(s: String) -> Result<Self, Self::Error> {
        if s.contains('@') {
            Ok(Email(s))
        } else {
            Err(format!("invalid email: {s}"))
        }
    }
}
// Deserialization now validates automatically
```

## Edition 2024: RPIT Lifetime Capture in Custom Serializers

In edition 2024, `-> impl Trait` captures ALL in-scope lifetimes by default. This affects custom serialization helpers that return `impl Trait` — particularly deserializer combinators and visitor factories that take borrowed setup inputs and return an owned visitor.

```rust
// Edition 2021: only captured 'de (since 'a did not appear in Visitor<'de>),
// so MyVisitor { context: context.to_owned() } did NOT borrow 'a.
// Edition 2024: captures 'de AND 'a by default, extending the borrow of `context`!
fn make_visitor<'de, 'a>(context: &'a str) -> impl Visitor<'de> {
    MyVisitor { context: context.to_owned() }
}
```

(Note: if `MyVisitor` actually stored `&'a str`, Edition 2021 required `+ 'a` explicitly.) If the returned type owns its data and should NOT capture `'a`, use precise capture syntax in Edition 2024:

```rust
// GOOD — explicitly captures only 'de, excludes 'a
fn make_visitor<'de, 'a>(context: &'a str) -> impl Visitor<'de> + use<'de> {
    MyVisitor { context: context.to_owned() }
}
```

Most serde `with` modules are unaffected because they return `Result`, not `impl Trait`. This primarily impacts advanced patterns: custom visitor factories, deserializer adapters, and combinator libraries that return opaque types.

## Edition 2024: `never_type_fallback` and Infallible Paths

On stable Rust, the `!` never type cannot be used in type annotations like `Result<T, !>` (that requires nightly `#![feature(never_type)]`, tracking issue `#35121`). For infallible conversions/deserialization on stable, use `std::convert::Infallible` (or `serde::de::value::Error` when a `serde::de::Error` bound is needed):

```rust
use std::convert::Infallible;

// GOOD — stable, explicit infallible error type
fn infallible_parse<T: Default>() -> Result<T, Infallible> {
    Ok(T::default())
}
```

What Edition 2024 *did* change is **`never_type_fallback`** for unconstrained type inference: diverging expressions (e.g., `return`, `panic!`, `continue`) previously fell back to `()` when unconstrained, and in Edition 2024 fall back to `!` instead. This can surface when a generic `Deserialize` or `Serialize` helper has an unconstrained `T` inside a diverging branch — e.g., `()` implements `Deserialize`/`Serialize`, whereas `!` does not:

```rust
// In Edition 2021, an unconstrained `T` in a diverging fallback inferred `()`,
// which implements Deserialize/Serialize. In Edition 2024 it falls back to `!`.
// Fix by specifying a concrete type (e.g. `()`) or `std::convert::Infallible`.
```

## Common Pitfalls

### Lossy Numeric Conversions

JSON numbers are IEEE 754 doubles. Values outside `f64` precision range get silently truncated.

```rust
// BAD for monetary values - f64 loses precision
#[derive(Serialize, Deserialize)]
struct Invoice {
    amount: f64,  // 0.1 + 0.2 ≠ 0.3
}

// GOOD - use decimal types
use rust_decimal::Decimal;

#[derive(Serialize, Deserialize)]
struct Invoice {
    amount: Decimal,  // exact decimal arithmetic
}
```

### Untagged Enum Ambiguity

With `#[serde(untagged)]`, serde tries variants in declaration order. If two variants can match the same input, the first wins silently.

```rust
// AMBIGUOUS - both variants match {"value": 42}
#[serde(untagged)]
enum Data {
    Full { value: i64, extra: Option<String> },
    Simple { value: i64 },
}
// Always deserializes as Full (tried first)
```

### deny_unknown_fields Breaks Forward Compatibility

Adding `#[serde(deny_unknown_fields)]` means older code fails to deserialize data from newer versions that add fields.

```rust
// Version 1: works fine
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Config { port: u16 }

// Version 2 adds `host` field
// Now V1 code fails on V2 config files — breaking change
```

Use `deny_unknown_fields` only for strict input validation (user-facing forms, CLI config) where unknown fields indicate user error.

## Round-Trip Testing

Every type with custom serialization should have a round-trip test:

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn round_trip_event() {
        let original = Event {
            created_at: Utc::now(),
        };
        let json = serde_json::to_string(&original).unwrap();
        let deserialized: Event = serde_json::from_str(&json).unwrap();
        assert_eq!(original, deserialized);
    }

    #[test]
    fn deserialize_from_known_format() {
        // Test against a known JSON string to catch format regressions
        let json = r#"{"created_at": "2024-01-15T10:30:00Z"}"#;
        let event: Event = serde_json::from_str(json).unwrap();
        assert_eq!(event.created_at.year(), 2024);
    }
}
```

## Review Questions

1. Are custom serialization modules (`with`) used instead of full manual implementations where possible?
2. Is `try_from` used for validating deserialization?
3. Are monetary/precision values using `Decimal`, not `f64`?
4. Are untagged enums free from variant ambiguity?
5. Is `deny_unknown_fields` avoided on evolving APIs?
6. Do custom serializations have round-trip tests?
7. Do custom serializer/deserializer helpers returning `impl Trait` account for edition 2024 RPIT lifetime capture?
8. Are infallible paths using `std::convert::Infallible` / concrete types rather than relying on `never_type_fallback`?
