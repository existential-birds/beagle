# Common Mistakes

## Unsafe Code

### Missing Safety Comments

Every `unsafe` block must explain why the invariants are upheld. This isn't a style preference — it's how future maintainers verify the code is correct.

```rust
// BAD - no justification
let value = unsafe { &*ptr };

// GOOD - documents the invariant
// SAFETY: `ptr` was allocated by `Box::into_raw` in `new()` and
// is guaranteed to be valid until `drop()` is called. We hold &self,
// which prevents concurrent mutation.
let value = unsafe { &*ptr };
```

### Overly Broad Unsafe Blocks

Only the minimum necessary code should be inside `unsafe`. Surrounding safe code makes it harder to audit.

```rust
// BAD - safe operations inside unsafe block
unsafe {
    let len = data.len();          // safe
    let ptr = data.as_ptr();       // safe
    std::slice::from_raw_parts(ptr, len)  // this is the only unsafe part
}

// GOOD - narrow unsafe boundary
let len = data.len();
let ptr = data.as_ptr();
// SAFETY: ptr and len come from the same slice, which is still alive
unsafe { std::slice::from_raw_parts(ptr, len) }
```

## API Design

### Non-Exhaustive Enums

Public enums should be `#[non_exhaustive]` if variants may be added in the future. Without it, adding a variant is a breaking change.

```rust
// GOOD - allows adding variants without breaking downstream
#[derive(Debug)]
#[non_exhaustive]
pub enum Status {
    Pending,
    Active,
    Complete,
}
```

### Builder Pattern

For types with many optional fields, builders prevent argument confusion and allow incremental construction.

```rust
// Builder takes ownership for chaining
pub struct ServerBuilder {
    port: u16,
    host: String,
    workers: Option<usize>,
}

impl ServerBuilder {
    pub fn new(port: u16) -> Self {
        Self { port, host: "0.0.0.0".into(), workers: None }
    }

    pub fn host(mut self, host: impl Into<String>) -> Self {
        self.host = host.into();
        self
    }

    pub fn workers(mut self, n: usize) -> Self {
        self.workers = Some(n);
        self
    }

    pub fn build(self) -> Result<Server, Error> { ... }
}
```

### Type State Pattern

Use zero-sized marker types to encode state transitions in the type system, making invalid states unrepresentable at compile time.

```rust
// States as zero-sized types
pub struct Draft;
pub struct Published;

pub struct Document<S> {
    content: String,
    _state: std::marker::PhantomData<S>,
}

impl Document<Draft> {
    pub fn publish(self) -> Document<Published> {
        Document {
            content: self.content,
            _state: PhantomData,
        }
    }
}

// Can't call publish() on an already-published document - won't compile
```

## Performance Pitfalls

### Unnecessary Allocations

```rust
// BAD - allocates a String just to compare
if input.to_string() == "hello" { ... }

// GOOD - compare directly
if input == "hello" { ... }

// BAD - collecting then iterating
let items: Vec<_> = source.iter().filter(|x| x.is_valid()).collect();
for item in &items { process(item); }

// GOOD - chain iterators
for item in source.iter().filter(|x| x.is_valid()) {
    process(item);
}
```

### String Formatting in Hot Paths

`format!` allocates a new `String` every call. In hot paths, prefer `write!` to a pre-allocated buffer.

```rust
// BAD in hot path - allocates per iteration
for item in items {
    let msg = format!("processing {}", item.id);
    log(&msg);
}

// GOOD - reuse buffer
let mut buf = String::with_capacity(64);
for item in items {
    buf.clear();
    write!(&mut buf, "processing {}", item.id).unwrap();
    log(&buf);
}
```

### Missing Capacity Hints

When the final size is known or estimable, pre-allocate to avoid repeated reallocations.

```rust
// BAD - grows the vec incrementally
let mut results = Vec::new();
for item in &items {
    results.push(transform(item));
}

// GOOD - allocate upfront
let mut results = Vec::with_capacity(items.len());
for item in &items {
    results.push(transform(item));
}

// BEST - use iterator
let results: Vec<_> = items.iter().map(transform).collect();
```

## Clippy Patterns Worth Flagging

These are patterns that `clippy` warns about but are easy to miss:

- `manual_map` — match arms that just wrap in `Some`/`Ok`; use `.map()` instead
- `needless_borrow` — `&` on values that already implement the trait for references
- `redundant_closure` — closures that just call a function: `|x| foo(x)` → `foo`
- `single_match` — `match` with one arm + wildcard; use `if let` instead
- `or_fun_call` — `.unwrap_or(Vec::new())` allocates even on the happy path; use `.unwrap_or_default()`

## Derive Macro Guidelines

| Trait | Derive When |
|-------|-------------|
| `Debug` | Almost always — essential for logging and debugging |
| `Clone` | Type is used in contexts requiring copies (collections, Arc patterns) |
| `PartialEq, Eq` | Type is compared or used as HashMap/HashSet key |
| `Hash` | Type is used as HashMap/HashSet key (requires `Eq`) |
| `Default` | Type has a meaningful default state |
| `Serialize, Deserialize` | Type crosses serialization boundaries (API, DB, config) |
| `Send, Sync` | Auto-derived; manually implement ONLY with unsafe justification |

## Review Questions

1. Does every `unsafe` block have a safety comment?
2. Are `unsafe` blocks as narrow as possible?
3. Are public enums `#[non_exhaustive]` if they may grow?
4. Are there unnecessary allocations in hot paths?
5. Are appropriate derive macros present for each type's usage?
6. Would clippy flag any of these patterns?
