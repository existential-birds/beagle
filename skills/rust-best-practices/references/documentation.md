# Documentation

## Public API Doc Comments (`///`)

Document all public items: functions, structs, traits, enums, constants.

```rust
/// Loads a user profile from disk.
///
/// # Errors
///
/// Returns [`AppError::NotFound`] if the file is missing.
/// Returns [`AppError::InvalidFormat`] if the content is not valid JSON.
///
/// # Examples
///
/// ```rust
/// # use my_crate::load_user;
/// let user = load_user("profiles/alice.json")?;
/// assert_eq!(user.name, "Alice");
/// # Ok::<(), my_crate::AppError>(())
/// ```
pub fn load_user(path: &str) -> Result<User, AppError> { /* ... */ }
```

### Required Sections

- **Purpose** -- what the item does (first line)
- **`# Examples`** -- runnable code showing usage
- **`# Errors`** -- when it returns `Err` (for `Result`-returning functions)
- **`# Panics`** -- when it can panic (if applicable)
- **`# Safety`** -- invariants for `unsafe` functions

### Doc Test Tips

- Hide setup lines with `#` prefix inside `/// ```rust` blocks (not in plain markdown guides).
- Examples run with `cargo test` (but NOT `cargo nextest` -- run `cargo test --doc` separately in CI).
- Use `compile_fail` attribute for wrong-usage examples.
- Use `no_run` for side-effect examples (network, file I/O).

## Module-Level Docs with `//!`

Place at the top of `lib.rs` or `mod.rs`:

```rust
//! HTTP client with retry and circuit-breaker support.
//!
//! This module provides a resilient HTTP client that wraps `reqwest`
//! with automatic retries and circuit-breaker patterns.
//!
//! # Examples
//!
//! ```rust
//! let client = http::Client::builder().retries(3).build();
//! let response = client.get("https://api.example.com").await?;
//! ```
```

## Custom Error Messages with `#[diagnostic::on_unimplemented]`

Since Rust 1.78, you can provide custom compiler error messages when a trait is not implemented. This dramatically improves developer experience for library traits:

```rust
#[diagnostic::on_unimplemented(
    message = "`{Self}` is not a valid handler function",
    label = "this type does not implement `Handler`",
    note = "Handler functions must accept a `Request` and return `impl IntoResponse`"
)]
trait Handler {
    fn call(&self, req: Request) -> Response;
}
```

When someone tries to use a type that doesn't implement `Handler`, they see your custom message instead of the generic "trait bound not satisfied" error.

Use this for:
- Public library traits where users frequently hit confusing errors
- Trait bounds with non-obvious requirements (e.g., axum handlers, tower services)
- Domain-specific traits where the fix is not obvious from the trait name

## Documentation Lints

Enable for library crates:

```rust
// In lib.rs
#![deny(missing_docs)]
```

| Lint | Purpose |
|------|---------|
| `missing_docs` | Warn/deny on undocumented public items |
| `broken_intra_doc_links` | Detect broken `[links]` in doc comments |
| `missing_panics_doc` | Require `# Panics` section when function can panic |
| `missing_errors_doc` | Require `# Errors` for Result-returning functions |
| `missing_safety_doc` | Require `# Safety` for unsafe public functions |
| `empty_docs` (clippy) | Prevent empty doc comments that bypass `missing_docs` |

Run `cargo doc --no-deps --open` to preview your documentation output.

## Inline Comment Discipline

- Safety invariants: `// SAFETY: ...` on every `unsafe` block
- Performance reasoning: `// PERF: ...`
- Tracked TODOs: `// TODO(#42): ...` (never orphan TODOs without an issue reference)
