# Ownership and Borrowing

For pointer type selection, Copy trait guidance, Cow patterns, and iterator idioms, see the `beagle-rust:rust-best-practices` skill.

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

1. Each input reference gets its own lifetime: `fn f(a: &T, b: &U)` becomes `fn f<'a, 'b>(a: &'a T, b: &'b U)`
2. If there's exactly one input lifetime, it's assigned to all output references
3. If `&self` or `&mut self` is an input, its lifetime is assigned to outputs

```rust
// Elision handles this - no annotations needed
fn first_word(s: &str) -> &str { ... }

// Multiple inputs, ambiguous - must annotate
fn longest<'a>(a: &'a str, b: &'a str) -> &'a str { ... }
```

## RPIT Lifetime Capture (Edition 2024)

In edition 2024, `-> impl Trait` return types capture **all** in-scope generic parameters and lifetimes by default. In edition 2021, only type parameters used in the bounds were captured.

```rust
// Edition 2021: this compiled — 'a is NOT captured by impl Display
fn foo<'a>(x: &'a str, y: String) -> impl Display {
    y // fine: returned value doesn't borrow 'a
}

// Edition 2024: same code captures 'a — returned impl Display now
// borrows 'a even though it doesn't use it. This can cause
// unexpected borrow checker errors at call sites.

// GOOD — use precise capturing to opt out of capturing 'a
fn foo<'a>(x: &'a str, y: String) -> impl Display + use<> {
    y // explicitly captures nothing
}

// GOOD — capture only what you need
fn bar<'a, 'b>(x: &'a str, y: &'b str) -> impl Display + use<'b> {
    y.to_uppercase() // only captures 'b
}
```

**When to flag**: Functions returning `impl Trait` that take multiple lifetime parameters — check whether the edition 2024 default capture causes unintended borrowing at call sites. If callers get unexpected "borrowed value does not live long enough" errors, add `+ use<...>` to narrow the capture.

## `if let` Temporary Scope (Edition 2024)

In edition 2024, temporaries created in `if let` conditions are dropped at the end of the condition, not at the end of the `if` block. This breaks patterns that relied on temporaries living through the `else` branch.

```rust
// BAD in edition 2024 — MutexGuard dropped before else branch
if let Some(val) = mutex.lock().unwrap().get("key") {
    use_val(val);
} else {
    // mutex is already unlocked here — was locked in 2021
}

// GOOD — bind the guard explicitly to control its lifetime
let guard = mutex.lock().unwrap();
if let Some(val) = guard.get("key") {
    use_val(val);
} else {
    // guard still alive — explicit control
}
```

## Tail Expression Temporary Scope (Edition 2024)

In edition 2024, temporaries in tail expressions (the final expression in a block without a semicolon) are dropped **before** local variables. This can break code where a temporary borrows a local.

```rust
// BAD in edition 2024 — temporary String dropped before local
fn example() -> &str {
    let s = String::from("hello");
    s.as_str() // temporary borrow dropped before s in 2024
}

// GOOD — return owned data or bind explicitly
fn example() -> String {
    String::from("hello")
}
```

**When to flag**: Tail expressions that create temporaries referencing local variables — in edition 2024 the drop order changed and this may cause borrow checker errors that didn't exist in 2021.

## `IntoIterator` for `Box<[T]>` (Edition 2024)

`Box<[T]>` now implements `IntoIterator` directly in edition 2024, yielding owned `T` values without converting to `Vec` first.

```rust
// BEFORE edition 2024 — had to convert to Vec
let boxed: Box<[i32]> = vec![1, 2, 3].into_boxed_slice();
for item in boxed.into_vec() {
    process(item);
}

// GOOD in edition 2024 — iterate directly
let boxed: Box<[i32]> = vec![1, 2, 3].into_boxed_slice();
for item in boxed {
    process(item);
}
```

## Review Questions

1. Are `.clone()` calls necessary, or do they mask ownership design issues?
2. Are lifetimes as narrow as possible (not overly `'static`)?
3. Do functions borrow when they don't need ownership?
4. Is interior mutability (`RefCell`, `Cell`) used only when compile-time borrowing is genuinely insufficient?
5. Are smart pointers chosen appropriately for the sharing and threading model?
6. **Edition 2024**: Do `-> impl Trait` returns use `+ use<...>` when default lifetime capture is too broad?
7. **Edition 2024**: Are `if let` temporaries explicitly bound when their lifetime matters?
8. **Edition 2024**: Are tail expression temporaries safe given the new drop order?
