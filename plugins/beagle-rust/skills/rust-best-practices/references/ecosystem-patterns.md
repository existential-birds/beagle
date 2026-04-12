# Ecosystem Patterns

## Evaluating Crates

Before adding a dependency, assess it across these dimensions:

| Signal | What to Check |
|--------|---------------|
| Downloads | crates.io recent download trend, not just total |
| Maintenance | Commit recency, open issue response time, release cadence |
| Documentation | Docs.rs quality, examples, module-level guides |
| Dependencies | `cargo tree -i <crate>` -- how much does it pull in? |
| Compile time | Test with `cargo build --timings` before committing |
| Soundness | Check for `unsafe` usage, look for past CVEs |

Prefer crates that are narrowly scoped, have few transitive dependencies, and gate optional features behind Cargo features.

## Error Handling: anyhow vs thiserror vs eyre

| Crate | Use When | Returns |
|-------|----------|---------|
| `thiserror` | Library code with structured error types | `enum MyError { ... }` |
| `anyhow` | Application/binary code, rapid prototyping | `anyhow::Result<T>` |
| `eyre` | Application code needing custom reporters | `eyre::Result<T>` |

**Decision framework:**

- Writing a library others depend on? Use `thiserror` so callers can match on variants.
- Writing a binary or CLI? Use `anyhow` for ergonomic context chaining.
- Need custom error formatting (color, structured logs)? Use `eyre` with a custom handler.
- Never use `anyhow` in library public APIs -- it erases error types that downstream callers need.

```rust
// Library: structured errors with thiserror
#[derive(Debug, thiserror::Error)]
pub enum StorageError {
    #[error("key not found: {key}")]
    NotFound { key: String },
    #[error("connection failed")]
    Connection(#[from] std::io::Error),
}

// Binary: contextual errors with anyhow
use anyhow::{Context, Result};
fn main() -> Result<()> {
    let config = load_config()
        .context("failed to load configuration")?;
    run(config)
}
```

## Common Design Patterns

### Newtype

Wrap a primitive to add meaning and prevent mixing up arguments of the same underlying type.

```rust
struct UserId(u64);
struct OrderId(u64);
// Can't accidentally pass UserId where OrderId is expected
```

Also used to work around the orphan rule when implementing foreign traits on foreign types.

### Type State

Encode workflow stages in generic parameters so invalid transitions are compile errors. See [type-state-pattern.md](type-state-pattern.md).

### Sealed Traits

Prevent external implementations while keeping the trait usable. See [api-design.md](api-design.md) for the pattern.

### Builder

Construct complex types step-by-step with validation at build time. Use for types with more than 3-4 optional fields. See [api-design.md](api-design.md).

## Orphan Rule Strategies

You cannot implement a foreign trait for a foreign type. Workarounds:

1. **Newtype wrapper** -- wrap the foreign type and implement the trait on the wrapper
2. **Extension trait** -- define a new trait with the methods you need, blanket-implement it
3. **Upstream PR** -- contribute the implementation to the crate that owns the type or trait

```rust
// Extension trait pattern
trait IteratorExt: Iterator {
    fn sum_by<F, S>(self, f: F) -> S
    where
        F: FnMut(Self::Item) -> S,
        S: std::iter::Sum;
}

impl<I: Iterator> IteratorExt for I {
    fn sum_by<F, S>(self, f: F) -> S
    where
        F: FnMut(Self::Item) -> S,
        S: std::iter::Sum,
    {
        self.map(f).sum()
    }
}
```

## When to Vendor vs Depend

**Prefer a dependency when:**
- The crate is well-maintained and narrowly scoped
- You'd have to replicate significant correctness-sensitive logic
- Security-sensitive code (crypto, parsing) -- defer to audited crates

**Prefer vendoring or writing it yourself when:**
- The crate pulls in heavy transitive dependencies for a small feature
- You need only a tiny fraction of the crate's functionality
- The crate is unmaintained or has no recent releases
- Build times are a critical constraint

Use `cargo-udeps` to detect unused dependencies and `cargo-deny` to audit licenses and vulnerabilities.

## Edition Migration

Rust editions (2015, 2018, 2021, 2024) are opt-in per crate via `Cargo.toml`. Different crates in a dependency tree can use different editions and interoperate.

**Migration process:**
1. Run `cargo fix --edition` to apply automated fixes
2. Update `edition = "2024"` in `Cargo.toml`
3. Run `cargo clippy` and fix new warnings
4. Review edition-specific changes (see [coding-idioms.md](coding-idioms.md) for 2024 specifics)

Avoid skipping editions -- migrate incrementally. The automated tooling handles most changes, but review the edition guide for semantic differences.

## Essential Tools

| Tool | Purpose |
|------|---------|
| `cargo-deny` | Lint dependency graph for licenses, vulnerabilities, duplicates |
| `cargo-udeps` | Find unused dependencies |
| `cargo-outdated` | Detect available updates including major version bumps |
| `cargo-expand` | Inspect macro expansion output |
| `cargo-hack` | Test all feature combinations |
| `cargo-llvm-lines` | Find monomorphization-heavy code increasing compile time |

## Staying Current

- **This Week in Rust** (this-week-in-rust.org) -- weekly ecosystem digest
- **Rust Blog** (blog.rust-lang.org) -- release announcements and feature highlights
- **Rust RFCs** (github.com/rust-lang/rfcs) -- upcoming language changes
- **Clippy** -- enable it always; it surfaces new language features and idioms
- **Edition Guide** (doc.rust-lang.org/edition-guide) -- what changed per edition
- **caniuse.rs** -- look up when a specific feature landed on stable
