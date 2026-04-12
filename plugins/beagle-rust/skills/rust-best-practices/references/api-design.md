# API Design

## Four Principles

Every Rust interface should be **unsurprising** (follow naming conventions and standard trait expectations), **flexible** (avoid unnecessary restrictions on callers), **obvious** (use types and docs to prevent misuse), and **constrained** (expose only what you intend to support long-term).

## Naming Conventions

Follow the Rust API Guidelines. Reuse well-known names so users can rely on intuition:

- `iter` takes `&self` and returns an iterator
- `into_inner` takes `self` and returns a wrapped value
- `SomethingError` implements `std::error::Error`

Avoid using familiar names for unfamiliar behavior -- if `iter` takes `self`, users will write bugs.

## Standard Trait Implementations

Eagerly implement standard traits even if you don't need them yet. Users cannot implement foreign traits on your types due to coherence rules.

**Priority order:**
1. `Debug` -- nearly every type should have it
2. `Send`, `Sync` -- document if intentionally missing
3. `Clone`, `Default` -- expected for most types
4. `PartialEq`, `Hash` -- needed for collections and assertions
5. `Serialize`/`Deserialize` -- behind a `serde` feature flag

Avoid deriving `Copy` by default. It changes move semantics, and removing it later is a breaking change.

## Making Invalid States Unrepresentable

Use the type system to prevent misuse at compile time rather than panicking at runtime.

```rust
// BAD -- runtime check, caller can pass wrong combination
fn launch(rocket: &mut Rocket, is_fueled: bool, is_on_ground: bool) {
    assert!(is_fueled && is_on_ground);
}

// GOOD -- invalid calls are compile errors
struct Grounded;
struct Launched;
struct Rocket<Stage = Grounded> {
    stage: std::marker::PhantomData<Stage>,
}

impl Rocket<Grounded> {
    fn launch(self) -> Rocket<Launched> { /* ... */ }
}
```

Combine related booleans into enums. If a pointer is only valid when a flag is true, use an `Option` or a single enum with the data inside the relevant variant.

## Builder Pattern

Use when constructing types with many optional fields or when required fields must be validated before use.

```rust
pub struct ServerConfig { /* private fields */ }

pub struct ServerConfigBuilder {
    host: String,
    port: Option<u16>,
    tls: Option<TlsConfig>,
}

impl ServerConfigBuilder {
    pub fn new(host: impl Into<String>) -> Self {
        Self { host: host.into(), port: None, tls: None }
    }

    pub fn port(mut self, port: u16) -> Self {
        self.port = Some(port);
        self
    }

    pub fn build(self) -> Result<ServerConfig, ConfigError> {
        // validate and construct
    }
}
```

For builders with required stages, combine with type-state pattern (see [type-state-pattern.md](type-state-pattern.md)).

## `impl Trait` in Argument vs Return Position

**Argument position** (`fn foo(x: impl Read)`) -- syntactic sugar for generics. Caller chooses the concrete type. Monomorphized, so each type gets its own copy.

**Return position** (`fn foo() -> impl Read`) -- caller does not choose the type. Useful for hiding complex return types (iterators, closures, futures). In edition 2024, captures all in-scope lifetimes by default.

```rust
// Argument position: caller picks the type
fn process(input: impl AsRef<str>) { /* ... */ }

// Return position: hides the concrete iterator type
fn even_squares(nums: &[i32]) -> impl Iterator<Item = i32> + '_ {
    nums.iter().filter(|n| *n % 2 == 0).map(|n| n * n)
}
```

Prefer generics over `impl Trait` in arguments when the same type parameter is referenced multiple times or when the caller needs turbofish syntax.

## Sealed Traits

Prevent external crates from implementing your trait while still allowing them to use it. Useful for derived/blanket traits and restricting type parameters.

```rust
pub trait Stage: sealed::Sealed { /* ... */ }

mod sealed {
    pub trait Sealed {}
    impl Sealed for super::Grounded {}
    impl Sealed for super::Launched {}
}
```

Document that the trait is sealed so users don't waste time trying to implement it.

## Newtype Pattern

Wrap a type to give it distinct semantics or work around the orphan rule.

```rust
// Semantic distinctness
struct Meters(f64);
struct Seconds(f64);

// Orphan rule workaround -- implement foreign trait for foreign type
struct PrettyVec<T>(Vec<T>);
impl<T: Display> Display for PrettyVec<T> { /* ... */ }
```

Use `Deref` to forward method calls to the inner type when the wrapper is transparent.

## Non-Exhaustive for Forward Compatibility

Prevent downstream code from constructing your types directly or matching exhaustively, so you can add fields/variants without a breaking change.

```rust
#[non_exhaustive]
pub enum Error {
    NotFound,
    PermissionDenied,
}

#[non_exhaustive]
pub struct Config {
    pub timeout_ms: u64,
}
```

Use when the type is likely to gain new variants or fields. Avoid on stable types where exhaustive matching is valuable to callers.

## Blanket Implementations

Provide blanket impls for references when your trait has only `&self` methods:

```rust
impl<T: MyTrait> MyTrait for &T { /* forward calls */ }
impl<T: MyTrait> MyTrait for Box<T> { /* forward calls */ }
```

This lets `fn foo(x: impl MyTrait)` accept both owned values and references without surprises. Adding a blanket impl later is a breaking change due to coherence, so plan early.

## SemVer Implications

**Breaking changes** (require major version bump):
- Removing or renaming public items
- Adding fields to a non-`#[non_exhaustive]` struct
- Removing a trait implementation
- Adding a blanket trait implementation
- Making a trait no longer object-safe
- Changing auto-trait implementations (Send, Sync)
- Bumping a major version of a re-exported dependency

**Non-breaking changes:**
- Adding new public items
- Adding a trait method with a default implementation
- Implementing a trait for a new type
- Relaxing trait bounds on existing functions

Use `#[non_exhaustive]` on types you expect to evolve, seal traits you need to extend, and wrap re-exported foreign types in newtypes.
