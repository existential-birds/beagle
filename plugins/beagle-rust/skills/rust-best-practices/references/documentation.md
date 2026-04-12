# Documentation

## Comments vs Doc Comments

| Purpose | `// comment` | `/// doc` / `//! crate doc` |
|---------|-------------|---------------------------|
| Describe why | Yes -- explains reasoning | No |
| Describe API | No | Yes -- public interfaces, usage |
| Maintainable | Gets stale, not compiled | Tied to code, appears in `cargo doc` |
| Testable | No | Yes -- doc examples run with `cargo test` |
| Visibility | Local to source | Exported to users and tools |

## When to Use `//` Comments

Use when something can't be expressed clearly in code:

```rust
// SAFETY: ptr is guaranteed non-null and aligned by caller contract
unsafe { std::ptr::copy_nonoverlapping(src, dst, len); }

// PERF: Caching root cert store avoids repeated OS calls on macOS
// See ADR-12: TLS startup latency
let tls_store = cached_root_store();
```

### Good Comments

- Safety invariants: `// SAFETY: ...`
- Performance reasoning: `// PERF: ...`
- Design context: `// CONTEXT: See ADR-42 for rationale`
- Workarounds: `// WORKAROUND: upstream bug #123`

### Bad Comments

```rust
// BAD - restates the obvious
counter += 1; // increment counter by 1

// BAD - wall of text that should be a doc comment or ADR
// This function was originally written in 2023 for the legacy API...
// [20 more lines of history]
```

## Replace Comments with Code

If you're writing a long comment explaining "what" or "how", refactor instead:

```rust
// DON'T
fn process_request(req: Request) -> Result<(), Error> {
    // validate headers, then decode body, then authorize, then dispatch
    // ...100 lines...
}

// DO
fn process_request(req: Request) -> Result<(), Error> {
    validate_headers(&req)?;
    let body = decode_body(&req)?;
    authorize(&body)?;
    dispatch(body)
}
```

Structure and naming replace commentary. Tests serve as living documentation.

## TODO Discipline

Don't leave orphan TODOs. Link to a tracked issue:

```rust
// TODO(#42): Remove workaround after upstream fix lands
```

## When to Use `///` Doc Comments

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
- **`# Errors`** -- when it returns `Err` (for Result-returning functions)
- **`# Panics`** -- when it can panic (if applicable)
- **`# Safety`** -- invariants for `unsafe` functions

### Doc Test Tips

- Hide setup lines with `#` prefix
- Examples run with `cargo test` (but NOT `cargo nextest` -- run `cargo test --doc` separately)
- Use `compile_fail` attribute for wrong-usage examples
- Use `no_run` for side-effect examples (network, file I/O)

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
| `missing_docs` | Warn on undocumented public items |
| `broken_intra_doc_links` | Detect broken `[links]` in doc comments |
| `missing_panics_doc` | Require `# Panics` section when function can panic |
| `missing_errors_doc` | Require `# Errors` for Result-returning functions |
| `missing_safety_doc` | Require `# Safety` for unsafe public functions |
| `empty_docs` (clippy) | Prevent empty doc comments that bypass `missing_docs` |

Run `cargo doc --open` to preview your documentation output.

## Checklist

- [ ] All public items have `///` doc comments
- [ ] `//!` at top of lib.rs/mod.rs explaining purpose
- [ ] `# Examples` with runnable code on key functions
- [ ] `# Errors` and `# Panics` sections where applicable
- [ ] `// SAFETY:` comments on all `unsafe` blocks
- [ ] No stale comments that describe old behavior
- [ ] Every `TODO` links to a tracked issue
- [ ] `#![deny(missing_docs)]` enabled for library crates
