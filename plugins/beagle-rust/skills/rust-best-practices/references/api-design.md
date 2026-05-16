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

## Hidden Contracts

Some breaking changes do not show up in your signatures. The review-side companion in [../../rust-code-review/references/interface-design.md](../../rust-code-review/references/interface-design.md) catches these in diffs; on the development side, design around them up front.

**Re-exported foreign types.** `pub use serde::Serialize;` (or returning `serde_json::Value` from a public function) silently makes serde's major version part of your API contract. When serde bumps 1.x to 2.x, downstream code that mixes your crate with `serde 1.x` sees `serde1::Value` and `serde2::Value` as different types. Three defenses:

- Don't re-export. Keep foreign types out of your public surface.
- Wrap the foreign type in a newtype and expose only the methods you commit to.
- Return `impl Trait` with a minimal bound (`impl Iterator<Item = T>` rather than `itercrate::Empty<T>`) so the concrete foreign type is invisible.

**Auto-trait propagation.** `Send`, `Sync`, `Unpin`, `UnwindSafe` are inferred by the compiler from a type's contents and propagated through `-> impl Trait` and async fn bodies. A function whose body holds an `Rc<...>` across an `.await` silently downgrades its returned future to `!Send`, and downstream code that `tokio::spawn`s it stops compiling. The auto-trait status is part of your contract even though it appears nowhere in the signature.

To lock the contract, name it explicitly on the return type:

```rust
pub fn run(&self) -> impl Future<Output = ()> + Send + Sync + 'static {
    async move { /* compiler enforces Send + Sync */ }
}
```

**The `is_normal` compile-time test.** Pin every important public type so silent auto-trait regressions fail CI rather than downstream builds:

```rust
#[cfg(test)]
fn is_normal<T: Sized + Send + Sync + Unpin>() {}

#[test]
fn public_types_are_normal() {
    is_normal::<MyType>();
    is_normal::<MyHandle>();
}
```

The test runs no code; it just fails to compile if any listed type loses an auto-trait.

## Object Safety Mechanics

A trait is object-safe (usable as `dyn Trait`) only if every method satisfies all of:

1. **No `Self` by value or as return type.** Rules out `Clone::clone(&self) -> Self`. The vtable doesn't know `Self`'s size.
2. **No generic type parameters on methods.** Rules out `Extend::extend<I: IntoIterator>`. One vtable slot cannot hold infinite monomorphizations.
3. **A `self`/`&self`/`&mut self`/`Box<Self>` receiver.** Rules out `Default::default() -> Self` and other associated functions — no receiver means no impl to pick.
4. **`Sized` must be a non-required supertrait.** `dyn Trait` is unsized; if the trait demands `Self: Sized`, no `dyn` exists.
5. **No associated constants** (without `where Self: Sized`) — same reason as static methods.

Escape hatch: tag the offending method `where Self: Sized`. The method becomes unavailable through `dyn Trait`, but the rest of the trait stays object-safe. `Iterator` uses this trick — `map`, `filter`, `collect`, etc. all carry `where Self: Sized`, which is why `Box<dyn Iterator<Item = T>>` works for `next()` even though most combinators are gone.

If a method genuinely needs a generic, three options before giving up on object safety:

```rust
// Option A: lift the generic to the trait
trait Sink<I> { fn extend(&mut self, iter: I); }

// Option B: take a trait object inside the method
trait Sink { fn extend(&mut self, iter: &mut dyn Iterator<Item = u8>); }

// Option C: opt that one method out of object safety
trait Sink { fn extend<I: IntoIterator<Item = u8>>(&mut self, iter: I) where Self: Sized; }
```

## Wrapper Types and Deref Discipline

`Deref` is appropriate when access is cheap and the wrapper is transparent — the user should be unable to tell the difference between calling a method on the wrapper and on the inner type. Good fits:

- Smart pointers: `Box<T>`, `Rc<T>`, `Arc<T>`, `MutexGuard<'_, T>`.
- Transparent newtypes wrapping a single inner value with no behavior change (`String` derefs to `&str`).

`Deref` is wrong when:

- You want OOP-style inheritance. Rust has none, and `Deref` ambiguity bites: if both your wrapper and its `Deref::Target` have inherent methods named `frobnicate`, `wrapper.frobnicate()` is unambiguous to the compiler but not to the reader. If the target is a *user-controlled* type, any inherent method you add can later clash with one the user adds. Prefer static-form methods (`fn frobnicate(w: Wrapper)`) when forwarding is the goal.
- Access requires complex or expensive logic. `Deref` is implicit; users won't expect `.field` to allocate or hit the network. Provide an explicit accessor instead.
- You are adding behavior rather than forwarding. Use ordinary inherent methods.

`Borrow<T>` vs `AsRef<T>` vs `Deref<Target = T>` are three different contracts. `Borrow` requires that the wrapper produces identical `Hash`, `Eq`, and `Ord` results to the inner — that is why `HashSet<String>` accepts `&str` lookups via `Borrow`. Treat `Borrow` as "equivalent for collection keys," not as a general "I can be referenced as." `AsRef` is the right trait for cheap reference-to-reference conversions without the hash/eq invariant. `Deref` is for transparent dot-operator forwarding.

For a transparent wrapper, eagerly provide all of: `Deref`, `AsRef<Inner>`, `From<Inner>`, `Into<Inner>`.

## Fallible and Blocking Destructors

`Drop::drop(&mut self)` cannot return an error and cannot `.await`. For I/O-flavored types this is a real design constraint. Patterns:

**Explicit `close()` / `shutdown()` method** taking `self` by value and returning `Result<(), Error>` (or `impl Future<Output = Result<...>>`). `Drop` runs as best-effort fallback only. Document the explicit destructor prominently — users won't find it by reading method signatures.

```rust
impl Connection {
    pub fn close(self) -> Result<(), CloseError> { /* surfaces errors */ }
}
impl Drop for Connection {
    fn drop(&mut self) { let _ = self.try_close_sync(); }
}
```

**The "Drop blocks moves out of self" trap.** Once you implement `Drop`, you cannot move fields out of `self` in other methods, because `Drop::drop(&mut self)` still runs afterward with all fields required intact. Three workarounds:

- **`Option<T>` field**: replace fields (or the whole inner) with `Option`, then `mem::take(&mut self.inner)` (or `Option::take`) in both `Drop` and the explicit destructor. Cost: every field access becomes an unwrap.
- **`std::mem::take`** with a cheap `Default`: swap out the live value during destruction. Tidy when fields have sensible empty defaults.
- **`ManuallyDrop<T>`**: hold the inner in `ManuallyDrop<Inner>` for full manual control. `ManuallyDrop::take` is `unsafe` — double-take or use-after-take is UB. Use only when the code is simple enough to statically verify.

**Never `block_on` in `Drop`.** Spawning a runtime or blocking on one inside a destructor deadlocks under async runtimes and races executor shutdown. Provide an explicit `async fn close(self) -> Result<...>` and document that callers must invoke it.

## Ergonomic Blanket Impls

Rust does not auto-implement traits for references or smart pointers. So `fn f<T: MyTrait>(t: T)` rejects `&Wrapper` even when `Wrapper: MyTrait`. When you define a new trait, eagerly add the blanket impls users expect — adding them later is a breaking change because of coherence rules (downstream impls may already overlap).

For a trait whose methods all take `&self`:

```rust
impl<T: MyTrait + ?Sized> MyTrait for &T { /* forward */ }
impl<T: MyTrait + ?Sized> MyTrait for &mut T { /* forward */ }
impl<T: MyTrait + ?Sized> MyTrait for Box<T> { /* forward */ }
```

Which blankets are possible depends on the receivers. `&mut self` rules out `&T`. `self` rules out all three. Include `?Sized` so unsized types (`dyn`, `str`, slices) work too.

For iterable collections, also provide both reference forms of `IntoIterator` so `for x in &c` and `for x in &mut c` work as users expect from `Vec` and `HashMap`:

```rust
impl<'a, T> IntoIterator for &'a MyCollection<T> { /* type Item = &'a T; */ }
impl<'a, T> IntoIterator for &'a mut MyCollection<T> { /* type Item = &'a mut T; */ }
```

## Standard Derives Priority — Ordered List

The intro section above lists the basics. Jon's full ordering with caveats:

- **`Debug`** — first, nearly every type. If `#[derive(Debug)]` adds an unwanted `T: Debug` bound (e.g., `T` is only used as `PhantomData`), hand-write the impl via `f.debug_struct(...)`.
- **`Send` / `Sync` / `Unpin`** — auto-derived from contents. If a type is intentionally `!Send` or `!Sync`, document why in rustdoc. Non-`Send` types cannot live in `Mutex` or tokio tasks; non-`Sync` types cannot live in `Arc` or `static`.
- **`Clone` / `Default`** — expected for most types. Easy to derive; document explicitly if a type cannot implement them.
- **`PartialEq`** — high value; users want `assert_eq!`. Worth implementing even when equality is reflexive-only.
- **`Eq` / `Hash`** — for map and set keys. `Eq` carries reflexivity beyond `PartialEq`; only add when the semantics hold.
- **`PartialOrd` / `Ord`** — only when a natural total order exists. Most types don't qualify.
- **`Serialize` / `Deserialize`** — gate behind `#[cfg_attr(feature = "serde", derive(...))]` so consumers opt into the serde dependency.

**Avoid `Copy` by default.** Users expect to call `.clone()` for a second copy. `Copy` changes move semantics and is highly restrictive — a type that starts simple often grows to hold a `String`, and removing `Copy` is a breaking change. `Clone` is far easier to keep stable across versions.
