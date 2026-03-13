# Ownership and Borrowing

## Critical Anti-Patterns

### 1. Clone to Silence the Borrow Checker

When `.clone()` appears primarily to resolve borrow checker errors, it often hides a design issue. The borrow checker is pointing at a real ownership conflict that cloning papers over.

```rust
// BAD - cloning to work around borrow conflict
fn process(data: &mut Vec<String>) {
    let items = data.clone(); // expensive, hides design issue
    for item in &items {
        data.push(item.to_uppercase());
    }
}

// GOOD - restructure to avoid the conflict
fn process(data: &mut Vec<String>) {
    let uppercased: Vec<String> = data.iter().map(|s| s.to_uppercase()).collect();
    data.extend(uppercased);
}
```

The exception: `.clone()` is fine when you genuinely need an independent copy (e.g., sending data to another thread, storing in a cache alongside the original).

### 2. Overly Broad Lifetimes

Using `'static` when a shorter lifetime works makes APIs inflexible and can hide real ownership issues.

```rust
// BAD - forces callers to own their data forever
fn process(name: &'static str) {
    println!("{name}");
}

// GOOD - any borrowed string works
fn process(name: &str) {
    println!("{name}");
}
```

`'static` is appropriate for: compile-time constants, leaked allocations (intentional), thread-spawned closures that must outlive the caller.

### 3. Taking Ownership When Borrowing Suffices

Functions that take `String` when they only read the data force unnecessary allocations at call sites.

```rust
// BAD - forces callers to allocate
fn greet(name: String) {
    println!("Hello, {name}");
}
greet(some_str.to_string()); // unnecessary allocation

// GOOD - borrows are cheaper
fn greet(name: &str) {
    println!("Hello, {name}");
}
greet(some_str); // works with &str, String, &String
```

For maximum flexibility in public APIs, consider `impl AsRef<str>` which accepts `&str`, `String`, `&String`, and other types that deref to `str`.

### 4. Returning References to Local Data

The borrow checker catches this at compile time, but it indicates a misunderstanding of ownership.

```rust
// WON'T COMPILE - but indicates design confusion
fn create_name() -> &str {
    let name = String::from("hello");
    &name // name is dropped at end of function
}

// GOOD - return owned data
fn create_name() -> String {
    String::from("hello")
}
```

### 5. Interior Mutability Overuse

`RefCell`, `Cell`, and `Mutex` bypass compile-time borrow checking. Overusing them suggests the ownership model needs rethinking.

```rust
// SUSPICIOUS - RefCell to work around borrow rules
struct Service {
    cache: RefCell<HashMap<String, Data>>,
    config: RefCell<Config>,
}

// BETTER - separate mutable and immutable state
struct Service {
    cache: HashMap<String, Data>,  // mutated via &mut self
    config: Config,                // set at construction
}
```

`RefCell` is appropriate for: observer patterns, graph structures with shared nodes, runtime-polymorphic mutation. In multithreaded code, `Mutex`/`RwLock` serve a similar role but with thread safety.

## Lifetime Elision Rules

Rust elides lifetimes when the rules are unambiguous. Understanding them prevents unnecessary lifetime annotations:

1. Each input reference gets its own lifetime: `fn f(a: &T, b: &U)` → `fn f<'a, 'b>(a: &'a T, b: &'b U)`
2. If there's exactly one input lifetime, it's assigned to all output references
3. If `&self` or `&mut self` is an input, its lifetime is assigned to outputs

```rust
// Elision handles this - no annotations needed
fn first_word(s: &str) -> &str { ... }

// Multiple inputs, ambiguous - must annotate
fn longest<'a>(a: &'a str, b: &'a str) -> &'a str { ... }
```

## Smart Pointer Guidelines

| Type | Use When | Thread Safe |
|------|----------|-------------|
| `Box<T>` | Heap allocation, recursive types, trait objects | Yes (if T: Send) |
| `Rc<T>` | Shared ownership, single thread | No |
| `Arc<T>` | Shared ownership, multi-thread | Yes |
| `Cow<'a, T>` | Clone-on-write, avoid allocation when possible | Depends on T |

Common mistake: using `Arc<Mutex<T>>` when the data is only accessed from one thread. Use `Rc<RefCell<T>>` in single-threaded code.

## Copy Trait Guidelines

Not all types should be passed by reference. If a type is small and cheap to copy, pass it by value.

### When to Derive `Copy`

- All fields are themselves `Copy`
- The struct is small (≤24 bytes / 2-3 machine words)
- The type represents plain data without heap allocations (`Vec`, `String` are NOT `Copy`)

```rust
// GOOD - small plain data, derive Copy
#[derive(Debug, Copy, Clone)]
struct Point {
    x: f32,
    y: f32,
    z: f32,
}

// GOOD - tag-like enum, derive Copy
#[derive(Debug, Copy, Clone)]
enum Direction {
    North,
    South,
    East,
    West,
}

// BAD - String is not Copy
#[derive(Debug, Clone)]
struct User {
    age: i32,
    name: String, // String is not Copy, so User can't be either
}
```

Enum size is determined by the largest variant. Keep variants small or Box large payloads.

### Primitive Type Sizes

| Type | Size | Type | Size |
|------|------|------|------|
| `bool` | 1 byte | `i8`/`u8` | 1 byte |
| `char` | 4 bytes | `i16`/`u16` | 2 bytes |
| `f32` | 4 bytes | `i32`/`u32` | 4 bytes |
| `f64` | 8 bytes | `i64`/`u64` | 8 bytes |
| `isize`/`usize` | arch | `i128`/`u128` | 16 bytes |

## `Cow` for Maybe-Owned Data

When ownership requirements are ambiguous, use `Cow<'_, T>` to avoid unnecessary cloning:

```rust
use std::borrow::Cow;

// Accepts both borrowed and owned strings without cloning
fn process_name(name: Cow<'_, str>) {
    println!("Hello {name}");
}

process_name(Cow::Borrowed("Alice"));
process_name(Cow::Owned("Bob".to_string()));
```

`Cow` is useful for functions that usually borrow but occasionally need to own (e.g., string normalization that only allocates when the input needs modification).

## Full Pointer Type Reference

| Pointer Type | Description | Send + Sync | Main Use |
|-------------|-------------|-------------|----------|
| `&T` | Shared reference | Yes | Shared read access |
| `&mut T` | Exclusive mutable reference | Send (if T: Send), Sync (if T: Sync) | Exclusive mutation |
| `Box<T>` | Heap-allocated owning pointer | Yes (if T: Send + Sync) | Heap allocation, recursive types |
| `Rc<T>` | Single-threaded ref count | No | Multiple owners (single-thread) |
| `Arc<T>` | Atomic ref count | Yes | Multiple owners (multi-thread) |
| `Cell<T>` | Interior mutability for Copy types | Not Sync | Shared mutable, non-threaded |
| `RefCell<T>` | Runtime borrow checking | Not Sync | Shared mutable, non-threaded |
| `Mutex<T>` | Thread-safe exclusive access | Yes | Shared mutable, threaded |
| `RwLock<T>` | Thread-safe read OR exclusive write | Yes | Shared mutable, threaded |
| `OnceCell<T>` / `OnceLock<T>` | One-time initialization | `OnceLock`: Yes | Lazy static values |
| `LazyCell<T>` / `LazyLock<T>` | Lazy init with closure | `LazyLock`: Yes | Complex lazy initialization |
| `*const T` / `*mut T` | Raw pointers | No (manual) | FFI, raw memory |

## Review Questions

1. Are `.clone()` calls necessary, or do they mask ownership design issues?
2. Are lifetimes as narrow as possible (not overly `'static`)?
3. Do functions borrow when they don't need ownership?
4. Is interior mutability (`RefCell`, `Cell`) used only when compile-time borrowing is genuinely insufficient?
5. Are smart pointers chosen appropriately for the sharing and threading model?
6. Are `Copy` types passed by value rather than by reference?
7. Is `Cow<'_, T>` used where ownership is ambiguous?
