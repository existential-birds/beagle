# Error Handling

## Critical Anti-Patterns

### 1. Unwrap in Production Code

`unwrap()` and `expect()` panic on `None`/`Err`, crashing the program. They bypass the type system's error safety guarantees.

```rust
// BAD - panics on invalid input
fn parse_config(input: &str) -> Config {
    let value: Config = serde_json::from_str(input).unwrap();
    value
}

// GOOD - propagates error to caller
fn parse_config(input: &str) -> Result<Config, serde_json::Error> {
    serde_json::from_str(input)
}
```

`unwrap()` is acceptable in: tests, examples, and after a check that guarantees success (e.g., `if option.is_some() { option.unwrap() }` — though `.unwrap()` after match/if-let is cleaner).

### 2. Errors Without Context

Bare `?` propagation loses the "what was being attempted" context, making debugging difficult.

```rust
// BAD - caller sees "file not found" with no context
fn load_config(path: &Path) -> Result<Config, Error> {
    let contents = std::fs::read_to_string(path)?;
    let config: Config = toml::from_str(&contents)?;
    Ok(config)
}

// GOOD - each operation adds context
fn load_config(path: &Path) -> Result<Config, Error> {
    let contents = std::fs::read_to_string(path)
        .map_err(|e| Error::ConfigRead { path: path.to_owned(), source: e })?;
    let config: Config = toml::from_str(&contents)
        .map_err(|e| Error::ConfigParse { path: path.to_owned(), source: e })?;
    Ok(config)
}
```

With `anyhow`, use `.context()` / `.with_context()`:

```rust
use anyhow::Context;

fn load_config(path: &Path) -> anyhow::Result<Config> {
    let contents = std::fs::read_to_string(path)
        .with_context(|| format!("reading config from {}", path.display()))?;
    let config: Config = toml::from_str(&contents)
        .context("parsing config TOML")?;
    Ok(config)
}
```

### 3. Stringly-Typed Errors

Using `String` as an error type loses structured information and makes error matching impossible.

```rust
// BAD - callers can't match on error types
fn validate(input: &str) -> Result<(), String> {
    if input.is_empty() {
        return Err("input is empty".to_string());
    }
    Ok(())
}

// GOOD - structured error types
#[derive(Debug, thiserror::Error)]
pub enum ValidationError {
    #[error("input is empty")]
    Empty,
    #[error("input too long: {len} chars (max {max})")]
    TooLong { len: usize, max: usize },
}

fn validate(input: &str) -> Result<(), ValidationError> {
    if input.is_empty() {
        return Err(ValidationError::Empty);
    }
    Ok(())
}
```

### 4. Panic for Recoverable Errors

`panic!` should be reserved for unrecoverable states (violated invariants, programmer bugs). Expected failures like I/O errors, parse failures, or network issues should return `Result`.

```rust
// BAD
fn connect(url: &str) -> Connection {
    TcpStream::connect(url).unwrap_or_else(|e| panic!("connection failed: {e}"))
}

// GOOD
fn connect(url: &str) -> Result<Connection, ConnectionError> {
    let stream = TcpStream::connect(url)
        .map_err(|e| ConnectionError::TcpFailed { url: url.to_owned(), source: e })?;
    Ok(Connection::new(stream))
}
```

### 5. Swallowing Errors

Discarding errors silently makes failures invisible.

```rust
// BAD - error silently ignored
let _ = save_to_disk(&data);

// GOOD - log if you can't propagate
if let Err(e) = save_to_disk(&data) {
    tracing::error!(error = %e, "failed to save data to disk");
}
```

The exception: some errors are genuinely unactionable (e.g., `write!` to stderr, `close()` on a file you're done with). In those cases, `let _ =` with a brief comment is acceptable.

## Let-Else for Early Returns

Rust's `let-else` pattern (stable since 1.65) is cleaner than `match` for early returns on failure:

```rust
// GOOD - flat, readable early return
let Ok(json) = serde_json::from_str(&input) else {
    return Err(MyError::InvalidJson);
};

// GOOD - continue/break in loops
for item in items {
    let Some(value) = item.value() else {
        continue;
    };
    process(value);
}

// Use if-let when the else branch needs computation
if let Some(result) = cache.get(&key) {
    return Ok(result.clone());
} else {
    let computed = expensive_compute(&key)?;
    cache.insert(key, computed.clone());
    return Ok(computed);
}

// NOTE (Edition 2024): Temporaries in if-let conditions are dropped
// at the end of the condition, not the end of the block. If the
// matched value borrows a temporary, bind it explicitly first.
// See ownership-borrowing.md for details.
```

## Prevent Early Allocation

Use `_else` variants when the fallback involves allocation or computation:

```rust
// BAD - format! runs even when x is Some
let val = x.ok_or(ParseError::Missing(format!("key {key}")));

// GOOD - closure only runs on None
let val = x.ok_or_else(|| ParseError::Missing(format!("key {key}")));

// BAD - Vec::new() allocates even on Ok path
let items = result.unwrap_or(Vec::new());

// GOOD - use unwrap_or_default for Default types
let items = result.unwrap_or_default();
```

## Logging and Transforming Errors

Use `inspect_err` to log and `map_err` to transform errors in a chain:

```rust
let result = do_something()
    .inspect_err(|err| tracing::error!("do_something failed: {err}"))
    .map_err(|err| AppError::from(("do_something", err)))?;
```

## Custom Error Structs

When a module has only one error type, a struct is simpler than an enum:

```rust
#[derive(Debug, thiserror::Error, PartialEq)]
#[error("Request failed with code `{code}`: {message}")]
struct HttpError {
    code: u16,
    message: String,
}
```

## Async Error Bounds

Errors in async code must be `Send + Sync + 'static` for spawned tasks:

```rust
// Ensure error types work across await boundaries
#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    Ok(())
}
```

Avoid `Box<dyn std::error::Error>` (without Send + Sync) in libraries.

## Panic Alternatives

Prefer these over `panic!` for expected incomplete code:

| Macro | Use When |
|-------|----------|
| `todo!()` | Code not yet written — alerts compiler of missing implementation |
| `unreachable!()` | Logic guarantees this branch can't execute |
| `unimplemented!()` | Feature intentionally not implemented, with reason |

## thiserror Patterns

`thiserror` generates `Display` and `Error` implementations from derive macros. It's the standard choice for library error types.

```rust
#[derive(Debug, thiserror::Error)]
pub enum Error {
    // Transparent: delegates Display and source() to inner error
    #[error(transparent)]
    Io(#[from] std::io::Error),

    // Structured: carries context alongside the cause
    #[error("failed to parse config at {path}")]
    ConfigParse {
        path: PathBuf,
        #[source]
        source: toml::de::Error,
    },

    // Simple: no underlying cause
    #[error("workflow not found: {0}")]
    NotFound(Uuid),

    // Multiple sources via transparent wrapping
    #[error(transparent)]
    Database(#[from] sqlx::Error),
}
```

Hierarchical errors: subsystem error types wrap into a top-level error via `#[from]`:

```rust
#[derive(Debug, thiserror::Error)]
pub enum AppError {
    #[error(transparent)]
    Workflow(#[from] WorkflowError),
    #[error(transparent)]
    Driver(#[from] DriverError),
}
```

## Result Type Alias Pattern

Crates commonly define a local `Result` alias to reduce boilerplate:

```rust
pub type Result<T> = std::result::Result<T, Error>;

// Now functions in this module just use:
pub fn load(path: &Path) -> Result<Config> { ... }
```

## Option Handling

`Option<T>` represents absence, not failure. Converting between `Option` and `Result` should be explicit about what "missing" means:

```rust
// BAD - ok_or with allocated string
let user = users.get(id).ok_or("user not found".to_string())?;

// GOOD - specific error type
let user = users.get(id).ok_or(Error::NotFound(id))?;

// GOOD - ok_or_else for expensive error construction
let user = users.get(id).ok_or_else(|| Error::NotFound(id))?;
```

## Error Trait Implementation Rules

Custom error types should implement the full Error contract for ecosystem compatibility:

1. **`Error` trait**: implement `std::error::Error`
2. **`Display`**: one-line, lowercase, no trailing punctuation — fits into larger error reports
3. **`Debug`**: usually `#[derive(Debug)]` is sufficient; include auxiliary info (ports, paths, request IDs)
4. **`Send + Sync`**: required for multithreaded contexts and `std::io::Error` wrapping
5. **`'static`**: enables downcasting and easy propagation up the call stack

```rust
#[derive(Debug)]
pub struct DecodeError {
    offset: usize,
    kind: DecodeErrorKind,
}

impl std::fmt::Display for DecodeError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        // lowercase, no trailing punctuation
        write!(f, "decode failed at offset {}: {}", self.offset, self.kind)
    }
}

impl std::error::Error for DecodeError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        self.kind.source()
    }
}
```

**Flag when**: a custom error type is missing `Display`, `Debug`, or `Error` implementations. With `thiserror`, these are derived automatically.

## Enumerated vs Opaque Error Strategy

Choose between enumerated and opaque errors based on whether callers need to distinguish error cases:

| Strategy | When to Use | Example |
|----------|-------------|---------|
| **Enumerated** (`enum`) | Callers take different actions per error variant | I/O vs parse vs auth errors in a web handler |
| **Opaque** (`Box<dyn Error>` or struct) | Callers only log/propagate, don't match on variants | Image decoder, internal library errors |

**Flag when**:
- A library exposes `Box<dyn Error>` when callers demonstrably need to match on specific error cases
- An error enum has 20+ variants that callers never match on — consider an opaque wrapper to simplify the API

## Error Chain Traversal with `source()`

`Error::source()` provides the underlying cause, enabling error chain traversal for backtraces and diagnostics.

```rust
fn print_error_chain(err: &dyn std::error::Error) {
    let mut current = Some(err);
    while let Some(e) = current {
        eprintln!("  caused by: {e}");
        current = e.source();
    }
}
```

**Check for**: error types that wrap an inner error but don't implement `source()` — the chain breaks and root cause is hidden.

With `thiserror`, `#[source]` and `#[from]` attributes handle this automatically:

```rust
#[derive(Debug, thiserror::Error)]
pub enum AppError {
    #[error("database query failed")]
    Database {
        #[source]  // wires up Error::source()
        source: sqlx::Error,
    },
}
```

## Type-Erased Error Composition

`Box<dyn Error + Send + Sync + 'static>` enables heterogeneous error handling in applications:

```rust
fn process() -> Result<(), Box<dyn std::error::Error + Send + Sync + 'static>> {
    let data = std::fs::read_to_string("input.txt")?; // io::Error
    let parsed: Config = toml::from_str(&data)?;       // toml::de::Error
    Ok(())
}
```

**Check for**: `Box<dyn Error>` (without `Send + Sync`) in library code — this prevents use in multithreaded contexts. Always prefer `Box<dyn Error + Send + Sync + 'static>` or a concrete type.

Note: `Box<dyn Error + Send + Sync + 'static>` itself does not implement `Error`. If you need a type-erased error that also implements `Error`, define a wrapper type or use `anyhow::Error`.

## Downcasting with `Error::downcast_ref()`

Downcasting recovers the concrete error type from a `dyn Error`. Requires the `'static` bound.

```rust
fn handle_error(err: &(dyn std::error::Error + 'static)) {
    if let Some(io_err) = err.downcast_ref::<std::io::Error>() {
        if io_err.kind() == std::io::ErrorKind::WouldBlock {
            // handle non-blocking retry
            return;
        }
    }
    // generic error handling
    eprintln!("error: {err}");
}
```

**Flag when**: error types are not `'static` — this prevents downcasting and limits composability. Avoid placing non-static references in error types unless strictly necessary.

## `From` Implementations for `?` Ergonomics

The `?` operator uses `From` to convert between error types. Implementing `From<SourceError> for MyError` enables seamless `?` propagation.

```rust
// Manual From implementation
impl From<std::io::Error> for AppError {
    fn from(err: std::io::Error) -> Self {
        AppError::Io(err)
    }
}

// With thiserror — #[from] generates the From impl
#[derive(Debug, thiserror::Error)]
pub enum AppError {
    #[error(transparent)]
    Io(#[from] std::io::Error),
}
```

**Check for**:
- Missing `From` implementations causing verbose `.map_err()` chains when `?` would suffice
- Implement `From`, not `Into` — the `?` operator uses `From` internally
- Conflicting `#[from]` attributes: two variants with `#[from]` for the same source type won't compile

## Try Blocks for Scoped Error Handling

Try blocks (still unstable as of Edition 2024, behind `#![feature(try_blocks)]`) scope `?` to a block instead of the entire function:

```rust
#![feature(try_blocks)]

fn do_work() -> Result<(), Error> {
    let resource = Resource::acquire()?;
    let result: Result<(), Error> = try {
        step_one(&resource)?;
        step_two(&resource)?;
    };
    resource.cleanup(); // always runs, even if steps failed
    result
}
```

**Check for**: functions that need cleanup before returning errors — `try` blocks avoid the pattern of manually catching and re-raising. Until stabilized, the drop-guard or RAII pattern is the stable alternative.

## Opaque vs Enumerated Errors

Jon Gjengset frames this as a binary choice driven by **caller need**, not author convenience: will the caller branch on the variant, or only log and propagate?

- **Enumerated** (`pub enum Error { ... }`) — caller takes different action per cause. Each variant should carry the underlying cause (e.g. `In(io::Error)` and `Out(io::Error)` are two `io::Error`s but the discriminant tells the caller *which* stream failed).
- **Opaque** — caller will only log/propagate. Two flavors: a struct with private fields and limited accessors (when bounded info is still useful — offset, status code), or `Box<dyn Error + Send + Sync + 'static>` (full erasure).

```rust
// Enumerated: callers branch on this
pub enum CopyError {
    In(std::io::Error),
    Out(std::io::Error),
}

// Opaque wrapper: callers cannot match, but can downcast if documented
pub struct MyError(Box<dyn std::error::Error + Send + Sync + 'static>);
```

Tradeoffs: enum locks in your variant set as a public API (adding a non-`#[non_exhaustive]` variant is a breaking change), but enables exhaustive pattern matching. Opaque keeps the variant set internal but forfeits pattern matching — callers can only inspect via `source()` or documented downcasts. See [interface-design.md](interface-design.md) for `#[non_exhaustive]` rules on public error enums.

**Flag**:

- [FILE:LINE] ENUM_VARIANTS_DROP_CAUSE — error enum variants like `In` / `Out` with no inner `io::Error` — wraps lose the only useful information.
- [FILE:LINE] OPAQUE_HIDES_BRANCH_INFO — opaque error hides info callers demonstrably branch on (retryable vs fatal) — promote to enum or expose an inspector.

## The Custom Error Trait Set

Any custom error type that ships in a public API should satisfy `Error + Display + Debug + Send + Sync + 'static`. Each bound is load-bearing:

- **`Error`** — `source()` is how the chain-traversal machinery walks to the root cause.
- **`Display`** — one-line, lowercase, no trailing punctuation, so it composes into larger error reports.
- **`Debug`** — carries auxiliary diagnostic info (ports, paths, request IDs) that doesn't belong in `Display`.
- **`Send + Sync`** — required in async/multithreaded code; without it the error can't cross an `await` or a `spawn`, and it won't compose with `std::io::Error` cleanly.
- **`'static`** — required by `dyn Error` for downcasting (`Any::type_id` vtable comparison) and to avoid lifetime contamination across the call stack.

```rust
// Audit fields: Rc<...>, RefCell<...>, raw pointers, or borrowed refs
// break Send/Sync/'static respectively.
#[derive(Debug, thiserror::Error)]
#[error("decode failed at offset {offset}")]
pub struct DecodeError { offset: usize, source_id: u64 }
```

**Flag**:

- [FILE:LINE] ERROR_FIELD_NOT_SEND — error type contains `Rc<T>` or `*const T` — breaks `Send + Sync`. Switch to `Arc` or owned data.
- [FILE:LINE] ERROR_BORROWS_INPUT — error type holds `&'a str` from request data — blocks `'static`, prevents downcasting and propagation. Own the data (`String`).

## Special Error Cases

Jon calls out four special cases worth flagging in review:

- **`Result<T, ()>` is usually wrong.** `()` doesn't implement `Error`, so the value can't be type-erased to `Box<dyn Error>` and is painful with `?`. If the failure carries no detail, switch to `Option<T>` (which says "nothing to return, no handling required"). If you must keep `Result` semantics for `#[must_use]`, define a unit struct that implements `Error`.
- **`std::thread::Result<T>` is `Result<T, Box<dyn Any + Send + 'static>>`** — note `Any`, not `Error`. The `Err` value is whatever was passed to `panic!`, often a `&'static str` or `String`. Calling `.source()` or `Display` on it is wrong; either downcast to a known payload type, propagate it via `resume_unwind`, or just `.unwrap()`.
- **The never type `!` / `Infallible`** for errors that cannot occur. `Result<T, Infallible>` lets you match a trait signature without panicking on `unwrap` — the compiler knows no `Err` value can ever be constructed.
- **Boxing on the hot path has allocation cost.** Errors are rare, so boxing a large variant keeps `Result<T, E>` small — but a fallible function called in a tight loop will pay the allocation cost on every error. Use `Cow<'static, str>` or fixed-shape errors for hot loops.

**Flag**:

- [FILE:LINE] RESULT_UNIT_USED_AS_OPTION — `fn f() -> Result<T, ()>` returned and callers treat it as absence — switch to `Option<T>` or a unit-struct error.
- [FILE:LINE] THREAD_RESULT_AS_ERROR — `JoinHandle::join()` payload treated as `dyn Error` (calling `.source()` or `Display`) — it's `Box<dyn Any>`. Downcast or `resume_unwind`.
- [FILE:LINE] BOXED_ERROR_HOT_LOOP — `Result<_, Box<MyError>>` returned from a function called per-iteration in a hot loop — allocation per failure; consider a fixed-shape error or unboxed enum.

## `?` Uses `From`, Not `Into`

`?` desugars to (roughly) `match expr { Ok(v) => v, Err(e) => return Err(From::from(e)) }`. The conversion is literally `From::from`, not `Into::into`. Implementing only `Into<OuterErr> for InnerErr` will *not* enable `?` propagation, even though `From` implies `Into`.

```rust
// Will NOT enable `?` from InnerErr to OuterErr
impl Into<OuterErr> for InnerErr { /* ... */ }

// Correct: implement From, get Into for free, and `?` works
impl From<InnerErr> for OuterErr { fn from(e: InnerErr) -> Self { /* ... */ } }
```

Old crates that only implement `Into` are common offenders — `?` will fail to compile against them with a confusing message about `From` not being implemented.

**Flag**:

- [FILE:LINE] INTO_NOT_FROM — error conversion implemented as `impl Into<Outer> for Inner` — `?` calls `From::from`, not `Into::into`. Reverse the impl direction.

## Deferred Cleanup with `?` — The Surprising Bug

A function that needs cleanup on the error path before propagating will *skip* the cleanup whenever `?` short-circuits:

```rust
fn do_the_thing() -> Result<(), Error> {
    let thing = Thing::setup()?;
    step_one(&thing)?;          // if this errors, cleanup is skipped
    step_two(&thing)?;
    thing.cleanup();            // only runs on the success path
    Ok(())
}
```

Three fixes, in order of preference:

- **RAII guard (stable, idiomatic).** Move cleanup into `Drop`. The compiler runs destructors on every exit path, including `?` early returns.
- **`try` blocks** (still unstable behind `#![feature(try_blocks)]`). Scope `?` to a block; cleanup runs after.
- **Explicit `match`.** Verbose but stable: bind the intermediate `Result`, run cleanup, then propagate.

```rust
struct Thing;
impl Drop for Thing { fn drop(&mut self) { /* cleanup */ } }
// Now `?` cannot skip cleanup — Drop fires on every exit.
```

**Flag**:

- [FILE:LINE] CLEANUP_SKIPPED_BY_QMARK — resource setup followed by `?` calls and a manual `cleanup()` / `close()` / `release()` after — the `?` early-return skips cleanup. Use `Drop` (RAII) or scope cleanup in a `try` block.
- [FILE:LINE] MANUAL_DROP_GUARD_LEAK — explicit `mem::forget` or `ManuallyDrop` on a guard followed by `?` — leaks the resource on error. Restructure so the guard owns the cleanup.

## `#[error(transparent)]` (thiserror)

`#[error(transparent)]` marks a variant that is a thin wrapper around an inner error type. `Display` and `source()` delegate to the inner error unchanged — the wrapper is invisible to logs and chain traversal.

```rust
#[derive(Debug, thiserror::Error)]
pub enum AppError {
    #[error(transparent)]
    Io(#[from] std::io::Error),     // displays exactly like the io::Error
    #[error("config invalid at {path}")]
    Config { path: PathBuf, #[source] source: toml::de::Error },
}
```

Use it when the variant adds no semantic information — the inner type is already the "real" error. Do *not* use it when you have context to add (a path, a request ID); use `#[error("...")]` with a `#[source]` field instead so the wrapping shows up in logs.

**Flag**:

- [FILE:LINE] TRANSPARENT_HIDES_CONTEXT — `#[error(transparent)]` on a variant that *should* be carrying context (path, ID) — the inner error's message alone won't tell users what was being attempted. Switch to `#[error("...")]` + `#[source]`.
- [FILE:LINE] TRANSPARENT_DUPLICATE_DISPLAY — `#[error(transparent)]` paired with a manual `Display` impl that also prints the inner error — double-prints in error chains. Drop one.

## Review Questions

1. Are all `unwrap()` / `expect()` calls in production code justified?
2. Do errors carry context about what operation failed?
3. Are error types structured (enums/structs) rather than stringly-typed?
4. Is `panic!` reserved for unrecoverable invariant violations?
5. Are errors propagated or logged, not silently swallowed?
6. Is `thiserror` used for library errors, `anyhow` for application errors?
7. Are `_else` variants used when fallbacks involve allocation?
8. Do async error types satisfy `Send + Sync + 'static` bounds?
9. Is `inspect_err` used for error logging instead of match arms?
10. Do custom error types implement the full contract (`Error`, `Display`, `Debug`, `Send + Sync + 'static`)?
11. Is `Error::source()` implemented for wrapped errors to enable chain traversal?
12. Are `From` implementations provided for `?` ergonomics instead of verbose `.map_err()` chains?
13. Is the error strategy (enumerated vs opaque) appropriate for how callers interact with errors?
