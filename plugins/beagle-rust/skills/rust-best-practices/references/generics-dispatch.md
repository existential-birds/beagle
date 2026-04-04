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
