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

## Edition 2024 Awareness

### Reserved Keyword: `gen`

Rust 2024 reserves `gen` as a keyword (for future generator support). Code using `gen` as an identifier must use the raw identifier escape:

```rust
// BAD (edition 2024) -- gen is a reserved keyword
let gen = 42;
fn gen() {}

// GOOD -- use raw identifier
let r#gen = 42;
fn r#gen() {}

// BETTER -- just rename to avoid confusion
let generation = 42;
fn generate() {}
```

This affects variable names, function names, module names, and any other identifiers. Prefer renaming over `r#gen` for readability.

### Never Type Fallback

In edition 2024, the `!` (never) type falls back to `!` instead of `()`. This affects diverging expressions in type inference:

```rust
// This compiles in edition 2021 (! falls back to ())
// May behave differently in edition 2024
let value = if condition {
    42
} else {
    panic!("unreachable")
    // In 2021: inferred as () fallback
    // In 2024: inferred as ! (never type)
};
```

In practice, most well-typed code is unaffected. Watch for cases where diverging branches interact with trait resolution or match exhaustiveness.

### `if let` Temporary Scope

Temporaries in `if let` conditions are now dropped at the end of the `if let` expression (not the enclosing block). This can affect code holding locks or references through temporaries:

```rust
// Edition 2024: temporary from get_mutex().lock() dropped earlier
if let Some(val) = get_mutex().lock().unwrap().get("key") {
    // In edition 2024, the MutexGuard may already be dropped here
    // if the temporary is not bound to a variable
}

// GOOD -- bind the guard explicitly
let guard = get_mutex().lock().unwrap();
if let Some(val) = guard.get("key") {
    // guard lives until end of scope
}
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

## Drop Guards

RAII bound to a scoped local lets you restore state, release a flag, or run cleanup at scope exit, including on panic. The pattern is a small struct that implements `Drop`; the side effect lives in the destructor.

```rust
fn with_flag(flag: &AtomicBool, f: impl FnOnce()) {
    flag.store(true, Ordering::Release);
    struct Guard<'a>(&'a AtomicBool);
    impl Drop for Guard<'_> {
        fn drop(&mut self) { self.0.store(false, Ordering::Release); }
    }
    let _guard = Guard(flag); // bound to a name; lives until scope ends
    f();
}
```

The bug that catches everyone: `let _ = Guard(flag)` is NOT the same as `let _guard = Guard(flag)`. The bare `_` pattern is a wildcard, not a binding — the temporary is dropped immediately at the `;`, before `f()` runs. A leading-underscore name (`_guard`) is a real binding and extends the lifetime to the end of the enclosing block.

```rust
let _ = Guard(flag);      // BAD: Drop runs here, before f()
f();
let _guard = Guard(flag); // GOOD: Drop runs at end of scope
f();
```

State-restore variants use `mem::replace` (or `mem::take`) to snapshot the prior value into the guard, then restore on drop:

```rust
let prev = mem::replace(&mut *cell, new_value);
struct Restore<'a, T>(&'a mut T, Option<T>);
impl<T> Drop for Restore<'_, T> {
    fn drop(&mut self) { *self.0 = self.1.take().unwrap(); }
}
let _g = Restore(&mut *cell, Some(prev));
```

For ad-hoc cleanup, the `scopeguard` crate's `defer!` macro packages the same pattern as a one-liner. Caveat: `panic = "abort"` skips destructors entirely *and* there is no unwind for `std::panic::catch_unwind` to intercept — the process terminates immediately. Under `abort`, neither drop guards nor `catch_unwind` will run cleanup. The only options are (a) build with the default `panic = "unwind"` so guards and `catch_unwind` work, or (b) restructure so cleanup happens on the success path before any panic-producing call. Crates that ship as `cdylib` / `staticlib` cannot dictate the consumer's panic strategy and should document this hazard explicitly.

## Extension Traits

The orphan rule forbids `impl ForeignTrait for ForeignType`. The workaround is to define a new trait in your crate and blanket-impl it for the bound you want to extend:

```rust
pub trait MyExt {
    fn my_method(&self) -> usize;
}
impl<T: AsRef<str>> MyExt for T {
    fn my_method(&self) -> usize { self.as_ref().len() }
}
```

Real examples: `itertools::Itertools` extends `Iterator`, `futures::TryStreamExt` extends `TryStream`, `tower::ServiceExt` extends `Service`. Splitting "core trait" from "ergonomic helpers" lets the helper trait evolve without forcing major bumps of the core.

When to reach for an extension trait: the type is foreign, the trait you'd want to impl is also foreign, and you want method-call syntax (`x.my_method()`) rather than a free function (`my_method(x)`). When NOT to reach for one: when you own the type — just write `impl Type` directly, no trait import required at every call site.

Pitfalls:

- Method names that shadow popular inherent methods (`len`, `iter`, `clone`, `into`) on the implementing type cause call-site ambiguity that's hard to diagnose.
- Add `#[doc(alias = "base_method")]` to make the extension method discoverable when users search for the base trait's name.
- If the trait is meant to be call-site-only and not implemented by downstream crates, seal it (`pub trait Ext: sealed::Sealed`); otherwise adding a method becomes a breaking change.

## Index Pointers

Storing data once in a `Vec` / `Slab` / arena and threading `usize` (or `u32`) indices through derived structures side-steps the borrow checker without `unsafe`. Real-world examples: `petgraph` stores nodes and edges as parallel `Vec`s with `u32` endpoint indices; `indexmap` keeps keys in a `Vec` and stores positions in its hashmap; ECS world-state crates do the same. Cycles in the data are now expressible without `Rc`/`Arc` and refcount overhead.

```rust
use slotmap::{DefaultKey, SlotMap};

struct Graph {
    nodes: SlotMap<DefaultKey, Node>,
    edges: Vec<(DefaultKey, DefaultKey)>, // generational keys
}

impl Graph {
    fn add_node(&mut self, n: Node) -> DefaultKey { self.nodes.insert(n) }
    fn neighbors(&self, k: DefaultKey) -> impl Iterator<Item = DefaultKey> + '_ {
        self.edges.iter().filter_map(move |&(a, b)| {
            if a == k { Some(b) } else if b == k { Some(a) } else { None }
        })
    }
}
```

Trade-offs:

- Lookup is O(1) but cache-cold compared to direct `&T` dereferences. Index pointers are not free.
- No compile-time check that the index is valid. A stale `usize` panics at lookup time, or silently returns the wrong entry if the slot was reused.
- `Vec::swap_remove(i)` invalidates the index `len-1` (it moves into slot `i`). Any derived structure still holding that old index is now wrong. Either fix up every derived structure after the swap, or use `Vec::remove` and accept O(n).
- Mixing indices from different containers (a `Vec<Node>` index used to look up in a `Vec<Edge>`) is undetectable at the type level. Newtype each: `struct NodeIdx(u32);`, `struct EdgeIdx(u32);`.
- For containers that delete and reuse slots, use **generational indices**: `slotmap::DefaultKey` and `petgraph::graph::NodeIndex` carry a generation that invalidates stale references at lookup time.

## Crate Preludes

Curate a `pub mod prelude` that re-exports the items used in 80% of call sites, so users can write `use somecrate::prelude::*;` once at the top of a file. Preludes pair especially well with extension traits, whose methods are invisible-until-imported — `diesel`'s prelude is what makes `posts.filter(...).limit(5).load(&conn)` compile without naming every helper trait.

```rust
pub mod prelude {
    pub use crate::{Pool, Connection, Query};
    pub use crate::traits::{Executor, Queryable, Loadable};
    pub use crate::Result; // crate-specific Result alias
}
```

What belongs in a prelude:

- Core traits users almost always need (extension traits, the crate's error trait).
- A `Result` type alias if you have one.
- Most-used types (connection handles, builders, the primary entry-point struct).

What does NOT belong:

- Internal types that escaped `pub` and shouldn't have.
- Items that shadow the std prelude without a clear reason (`Result`, `Option`, `Box`, `Iterator`). `anyhow::Result` shadows deliberately; most don't.
- Deprecated items — glob users get warnings they didn't opt into.

SemVer note: per RFC 1105, *adding* a trait to a published prelude is a minor breaking change because method-resolution ambiguity can break user code at the call site (even though glob imports have lower precedence than named imports, traits in scope affect inherent-method resolution). Reserve prelude additions for major versions when feasible. Tokio's and Diesel's preludes are the gold standard: small, mostly traits, stable across minor versions.

## Review-Side Companion

For the reviewer-facing checklist of these patterns — `[FILE:LINE]` checks for `let _ = guard` typos, `swap_remove` aliasing, extension-trait overuse, prelude bloat, and related SemVer hazards — see [../../rust-code-review/references/patterns-in-the-wild.md](../../rust-code-review/references/patterns-in-the-wild.md).
