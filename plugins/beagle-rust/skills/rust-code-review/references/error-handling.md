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

## Review Questions

1. Are all `unwrap()` / `expect()` calls in production code justified?
2. Do errors carry context about what operation failed?
3. Are error types structured (enums) rather than stringly-typed?
4. Is `panic!` reserved for unrecoverable invariant violations?
5. Are errors propagated or logged, not silently swallowed?
6. Is `thiserror` used for library errors, `anyhow` for application errors?
