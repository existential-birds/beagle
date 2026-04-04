# Coding Idioms

## Borrowing Over Cloning

Default to borrowing (`&T`). Clone only when you genuinely need a separate owned copy.

### When Clone is Appropriate

- Shared ownership via `Arc::clone(&arc)` (cheap atomic increment)
- Immutable snapshots where the original must be preserved
- When the API requires owned data and the caller still needs the original
- Caching results returned multiple times

### Clone Traps to Avoid

```rust
// BAD - cloning to avoid lifetime annotations
fn process(thing: &Thing) {
    let owned = thing.clone(); // if you need ownership, take it in the signature
    consume(owned);
}

// GOOD - take ownership explicitly
fn process(thing: Thing) {
    consume(thing);
}
```

```rust
// BAD - cloning inside iterator
items.iter().map(|x| x.clone()).collect::<Vec<_>>();

// GOOD - use .cloned() or .copied()
items.iter().cloned().collect::<Vec<_>>();
items.iter().copied().collect::<Vec<_>>(); // for Copy types
```

### Prefer Borrowed Parameters

```rust
// DO - borrow when you only read
fn greet(name: &str) {
    println!("Hello, {name}");
}

// DO - use slices over owned collections
fn sum(values: &[i32]) -> i32 {
    values.iter().sum()
}

// DON'T - force callers to allocate
fn greet(name: String) {
    println!("Hello, {name}");
}
```

For maximum flexibility in public APIs, use `impl AsRef<str>` or `impl Into<String>`.

## Copy Trait

### When to Derive Copy

- All fields are `Copy` themselves
- Struct is small (<=24 bytes / 2-3 machine words)
- Type is plain data without heap allocations

```rust
// GOOD - small plain data
#[derive(Debug, Copy, Clone)]
struct Point { x: f32, y: f32, z: f32 }

// GOOD - tag-like enum
#[derive(Debug, Copy, Clone)]
enum Direction { North, South, East, West }

// CAN'T - String is not Copy
struct User { age: i32, name: String }
```

Enum size equals the largest variant. Keep variants small or Box large payloads.

## Option and Result Handling

### Pattern Selection

| Pattern | Use When |
|---------|----------|
| `let Ok(x) = expr else { return ... }` | Early return, divergent code doesn't need error value |
| `match` | Pattern matching inner variants, transforming Result/Option shapes |
| `if let ... else` | Else branch needs computation with the value |
| `?` operator | Propagating errors to the caller |

```rust
// Early return with let-else
let Some(config) = load_config() else {
    return Err(AppError::MissingConfig);
};

// Pattern matching inner variants
match result {
    Ok(Direction::North) => handle_north(),
    Ok(other) => handle_other(other),
    Err(e) => handle_error(e),
}

// Propagation with ?
fn process(req: &Request) -> Result<Response, Error> {
    let body = validate(req)?;
    let user = authorize(&body)?;
    Ok(handle(user)?)
}
```

### Avoid These

```rust
// BAD - unwrap in production
let port = config.port.unwrap();

// BAD - match that should be .ok() or .ok_or()
match result {
    Ok(v) => Some(v),
    Err(_) => None,
}
// GOOD
result.ok()
```

## Prevent Early Allocation

Use `_or_else` variants when the fallback involves allocation:

```rust
// BAD - format! runs even when x is Some
x.ok_or(ParseError::Detail(format!("missing {name}")));

// GOOD - only allocates on the error path
x.ok_or_else(|| ParseError::Detail(format!("missing {name}")));

// BAD - Vec::new() always allocates
values.unwrap_or(Vec::new());

// GOOD - uses Default trait
values.unwrap_or_default();
```

## Iterator Patterns

### Prefer Iterator Chains For

- Collection transforms: `.filter().map().collect()`
- Combining: `.enumerate()`, `.chain()`, `.zip()`
- Windowing: `.windows()`, `.chunks()`

### Prefer For Loops For

- Early exits: `break`, `continue`, `return`
- Side effects: logging, I/O
- When readability matters more than chaining

### Anti-Patterns

```rust
// BAD - premature collect
let doubled: Vec<_> = items.iter().map(|x| x * 2).collect();
process(doubled.into_iter());

// GOOD - pass iterator directly
process(items.iter().map(|x| x * 2));

// BAD - .fold() for summing
items.iter().fold(0, |acc, x| acc + x);

// GOOD - .sum() is optimized
let total: i32 = items.iter().sum();
```

Iterators are lazy. Nothing happens until you consume them with `.collect()`, `.sum()`, `.for_each()`, etc.

### Error Mapping

Use `inspect_err` for logging and `map_err` for transforming:

```rust
result
    .inspect_err(|e| tracing::error!("operation failed: {e}"))
    .map_err(|e| AppError::from(e))?;
```

## Import Ordering

Standard order: `std` -> external crates -> workspace crates -> `super::`/`crate::`

```rust
// std
use std::sync::Arc;

// external crates
use chrono::Utc;
use serde::{Deserialize, Serialize};

// workspace crates
use shared_types::Config;

// crate/super
use super::schema::Context;
use crate::models::Event;
```

Configure `rustfmt.toml` for automatic enforcement:

```toml
reorder_imports = true
imports_granularity = "Crate"
group_imports = "StdExternalCrate"
```
