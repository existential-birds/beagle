# Generics and Dispatch

## Static Dispatch: `impl Trait` / `<T: Trait>`

Generics are monomorphized at compile time -- the compiler generates specialized code for each concrete type. Zero runtime cost.

### Use When

- Performance-critical code (tight loops, hot paths)
- Types are known at compile time
- You want inlining and optimization

```rust
// Generic function -- compiler generates specialized versions
fn process<T: Display>(item: T) {
    println!("{item}");
}

// Equivalent modern syntax
fn process(item: impl Display) {
    println!("{item}");
}
```

## Dynamic Dispatch: `dyn Trait`

Uses a vtable (virtual function table) for runtime polymorphism. Incurs indirection cost per call.

### Use When

- Heterogeneous collections (different types in one `Vec`)
- Plugin architectures with runtime-loaded components
- Abstracting internals behind a stable public interface
- Binary size matters more than call performance

```rust
// Different types in one collection
fn greet_all(animals: &[Box<dyn Animal>]) {
    for animal in animals {
        println!("{}", animal.greet());
    }
}
```

## Trade-Off Table

| Aspect | Static (`impl Trait`) | Dynamic (`dyn Trait`) |
|--------|----------------------|----------------------|
| Performance | Faster, inlined | Slower, vtable indirection |
| Compile time | Slower (monomorphization) | Faster (shared code) |
| Binary size | Larger (per-type codegen) | Smaller |
| Flexibility | One type at a time | Mix types in collections |
| Error messages | Clearer | Type erasure obscures errors |

## Decision Guide

1. **Start with generics.** They are the default in Rust.
2. **Switch to `dyn Trait`** when you need runtime polymorphism or heterogeneous collections.
3. If unsure, use generics with trait bounds -- refactor to `dyn` only when flexibility outweighs speed.

## Best Practices for Dynamic Dispatch

### Pointer Choice

```rust
// Prefer &dyn Trait when you don't need ownership
fn log(writer: &dyn Write) { /* ... */ }

// Use Box<dyn Trait> when you need to own the value
fn create_handler() -> Box<dyn Handler> { /* ... */ }

// Use Arc<dyn Trait> for shared access across threads
fn register(service: Arc<dyn Service>) { /* ... */ }
```

### Don't Box Too Early

```rust
// DO - use generics when possible
struct Renderer<B: Backend> {
    backend: B,
}

// DON'T - premature boxing reduces performance and flexibility
struct Renderer {
    backend: Box<dyn Backend>,
}
```

Box at API boundaries (public return types), not inside structs.

### Object Safety Rules

You can only create `dyn Trait` from object-safe traits:

- No generic methods
- No `Self: Sized` bound
- All methods use `&self`, `&mut self`, or `self`

```rust
// Object-safe -- can use as dyn
trait Runnable {
    fn run(&self);
}

// NOT object-safe -- generic method
trait Factory {
    fn create<T>(&self) -> T;
}
```

## RPIT Lifetime Capture (Edition 2024)

In Rust 2024, `-> impl Trait` return types capture ALL in-scope generic parameters and lifetimes by default. Previously (edition 2021), hidden types only captured the generic parameters explicitly mentioned in the opaque type.

### What Changed

```rust
// Edition 2021: 'a is NOT captured, return type outlives 'a
fn foo<'a>(x: &'a str) -> impl Display {
    x.len() // returns usize, no lifetime dependency
}

// Edition 2024: 'a IS captured by default, return type borrows 'a
fn foo<'a>(x: &'a str) -> impl Display {
    x.len() // still returns usize, but type signature now captures 'a
}
```

### Precise Capturing with `+ use<>`

When you need to opt out of capturing a lifetime or generic, use the `+ use<>` syntax:

```rust
// Only capture T, not the lifetime 'a
fn extract<'a, T: Display>(data: &'a [T]) -> impl Display + use<T> {
    data.len()
}

// Capture nothing -- equivalent to edition 2021 behavior
fn compute<'a>(x: &'a str) -> impl Display + use<> {
    x.len()
}
```

Use `+ use<>` when the return type genuinely does not depend on a lifetime, and callers need the returned value to outlive the borrow.

## Async Functions in Traits

Since Rust 1.75, `async fn` works directly in traits without the `async-trait` crate for many use cases:

```rust
// GOOD (Rust 1.75+) -- native async fn in trait
trait DataStore {
    async fn get(&self, key: &str) -> Option<String>;
    async fn put(&self, key: &str, value: &str) -> Result<(), StoreError>;
}

// BAD -- unnecessary async-trait dependency
#[async_trait::async_trait]
trait DataStore {
    async fn get(&self, key: &str) -> Option<String>;
    async fn put(&self, key: &str, value: &str) -> Result<(), StoreError>;
}
```

### When You Still Need `async-trait`

- **`dyn Trait` dispatch** -- native async fn in traits is not yet object-safe. If you need `Box<dyn DataStore>`, you still need `async-trait` or manual boxing.
- **Older MSRV** -- if your minimum supported Rust version is below 1.75.

For most application code with static dispatch, drop `async-trait` and use native syntax.

## Patterns

### Accept Generic, Return Concrete

Public APIs often accept generics for flexibility but return concrete types:

```rust
pub fn parse(input: impl AsRef<str>) -> Result<Config, ParseError> {
    let s = input.as_ref();
    // ...
}
```

### Trait Bounds on Impl Blocks

Constrain methods to specific trait implementations:

```rust
struct Wrapper<T>(T);

impl<T: Display> Wrapper<T> {
    fn show(&self) {
        println!("{}", self.0);
    }
}

impl<T: Display + Debug> Wrapper<T> {
    fn debug_show(&self) {
        println!("{:?}", self.0);
    }
}
```

### Where Clauses for Readability

```rust
// Hard to read
fn process<T: Clone + Debug + Send + Sync + 'static>(item: T) { /* ... */ }

// Clearer
fn process<T>(item: T)
where
    T: Clone + Debug + Send + Sync + 'static,
{
    // ...
}
```

## Variance Rules for Generics

Variance determines how subtyping relationships carry through generic types.

| Variance | Rule | Example |
|----------|------|---------|
| Covariant | If `'a: 'b`, then `T<'a>: T<'b>` | `&'a T`, `Vec<T>`, `Box<T>` |
| Contravariant | If `'a: 'b`, then `T<'b>: T<'a>` | `fn(T)` (in argument position) |
| Invariant | No subtyping relationship | `&'a mut T`, `Cell<T>`, `UnsafeCell<T>` |

**Practical impact:** `&'a mut T` is invariant over `T`, meaning you cannot coerce `&mut Vec<&'static str>` to `&mut Vec<&'a str>`. This prevents unsoundness where a shorter-lived reference could be inserted through the mutable alias.

Prefer `&T` (covariant) over `&mut T` (invariant) in generic contexts when mutation is not needed -- it gives callers more flexibility with lifetimes.

## Trait Object Cost Analysis

Dynamic dispatch via `dyn Trait` introduces two costs:

1. **Vtable indirection** -- each method call goes through a pointer lookup instead of a direct call. Prevents inlining and limits compiler optimizations.
2. **Loss of monomorphization** -- the compiler cannot specialize code per concrete type, eliminating opportunities for constant folding and layout optimization.

The overhead per call is typically 1-3 ns (vtable pointer chase). Avoid `dyn Trait` in tight loops or hot paths. Use it freely at architectural boundaries where call frequency is low.

## Object Safety Rules

A trait is object-safe (usable as `dyn Trait`) only when all methods satisfy:

- **No generic type parameters** on methods (generic params on the trait itself are fine)
- **No use of `Self` as a concrete type** in arguments or return position
- **No `Self: Sized` bound** on the trait itself (individual methods can have it)
- **Receivers must be dispatchable:** `&self`, `&mut self`, `self`, `Box<Self>`, `Arc<Self>`, `Pin<&Self>`, etc.

```rust
// NOT object-safe -- generic method prevents vtable construction
trait Parser {
    fn parse<T: FromStr>(&self, input: &str) -> T;
}

// Fix: exempt the generic method, keep the trait object-safe
trait Searchable {
    fn search(&self, query: &str) -> Vec<String>;
    fn search_typed<T>(&self, query: &str) -> Vec<T> where Self: Sized;
    // ^^ only callable on concrete types; dyn Searchable still works for search()
}
```

Prefer keeping traits object-safe. Add `where Self: Sized` to convenience methods that break object safety rather than sacrificing the whole trait.

## Complete Dispatch Decision Tree

```text
Do you need different concrete types in the same collection or behind one pointer?
  YES -> dyn Trait (dynamic dispatch)
    -> Need ownership? Box<dyn Trait>
    -> Borrowed only? &dyn Trait
    -> Shared across threads? Arc<dyn Trait>
  NO -> Do callers need to name the concrete return type?
    YES -> Generic <T: Trait> (full monomorphization)
    NO  -> impl Trait (opaque type, still static dispatch)
```

**`impl Trait` vs `dyn Trait` vs `T: Trait` summary:**

| Feature | `T: Trait` | `impl Trait` | `dyn Trait` |
|---------|-----------|-------------|-------------|
| Dispatch | Static | Static | Dynamic |
| Caller picks type | Yes | Arg: yes, Return: no | No (type-erased) |
| Turbofish (`::<>`) | Yes | No | N/A |
| Multiple types in collection | No | No | Yes |
| Binary size impact | Larger (codegen per type) | Larger | Smaller |
| Use in trait definitions | Yes | Limited | Yes |

## Blanket Implementation Patterns

Blanket impls provide automatic trait implementations for broad categories of types. Use them to reduce boilerplate, but be aware of their downstream impact.

```rust
// Common: forward trait through references
impl<T: MyTrait> MyTrait for &T {
    fn method(&self) { (**self).method() }
}

// Common: forward through smart pointers
impl<T: MyTrait + ?Sized> MyTrait for Box<T> {
    fn method(&self) { (**self).method() }
}

// Powerful but constraining: implement for all types meeting a bound
impl<T: Display> Loggable for T {
    fn log(&self) { println!("{self}"); }
}
```

**Impact on downstream users:** a blanket impl prevents anyone from writing a more specific impl for the same trait. Once `impl<T: Display> Loggable for T` exists, no one can write `impl Loggable for MyType` even if `MyType: Display`. Plan blanket impls carefully -- adding one later is a breaking change due to coherence rules.
