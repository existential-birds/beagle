# Workspace Layout

## When to Use Workspaces

Use a workspace when you have multiple related crates that:

- Share dependencies (reduces compile time and disk usage)
- Need coordinated versioning
- Have separate build targets (binary + library, multiple binaries)
- Benefit from a shared CI pipeline

Don't use a workspace for a single crate. The overhead isn't worth it.

## Basic Structure

```text
my-workspace/
  Cargo.toml            # workspace root
  rustfmt.toml          # shared formatting
  .github/
    workflows/ci.yml    # shared CI
  crates/
    core/               # shared types and logic
      Cargo.toml
      src/lib.rs
    api/                # HTTP server binary
      Cargo.toml
      src/main.rs
    cli/                # CLI binary
      Cargo.toml
      src/main.rs
  tests/                # workspace-level integration tests (optional)
```

## Workspace Cargo.toml

```toml
[workspace]
resolver = "3"                    # default for edition 2024; explicit for clarity
members = [
    "crates/core",
    "crates/api",
    "crates/cli",
]

[workspace.package]
edition = "2024"
rust-version = "1.85"
license = "MIT"
repository = "https://github.com/org/repo"

[workspace.dependencies]
serde = { version = "1", features = ["derive"] }
tokio = { version = "1", features = ["rt-multi-thread", "macros"] }
thiserror = "2"
tracing = "0.1"

[workspace.lints.clippy]
all = { level = "deny", priority = 10 }
pedantic = { level = "warn", priority = 3 }

[workspace.lints.rust]
future-incompatible = "warn"
```

## Member Cargo.toml

Members inherit from workspace:

```toml
[package]
name = "my-api"
version = "0.1.0"
edition.workspace = true
rust-version.workspace = true
license.workspace = true

[dependencies]
my-core = { path = "../core" }      # path dependency to workspace member
serde.workspace = true               # inherit version and features
tokio.workspace = true
axum = "0.8"                         # member-specific dependency

[lints]
workspace = true                      # inherit lint config
```

## Edition Inheritance in Workspaces

Edition 2024 introduces important workspace-level behaviors:

- **Edition inherits from workspace**: Members using `edition.workspace = true` inherit the workspace edition. All members get edition 2024 semantics (unsafe block requirements, lifetime capture rules, etc.)
- **Mixed editions**: Members can override with a local `edition = "2021"` if needed, but this creates inconsistent behavior across crates — avoid when possible
- **Resolver**: Edition 2024 defaults to resolver `"3"` (MSRV-aware); edition 2021 defaults to `"2"`. Setting it explicitly in the workspace root is good practice for clarity
- **Lint inheritance**: `[workspace.lints.rust]` applies uniformly, but edition 2024 deny-by-default lints (like `unsafe_op_in_unsafe_fn`) activate per-member based on that member's edition

```toml
# Root Cargo.toml — all members inherit edition 2024
[workspace.package]
edition = "2024"
rust-version = "1.85"

# Member Cargo.toml — inherits edition 2024 and MSRV
[package]
name = "my-crate"
version = "0.1.0"
edition.workspace = true
rust-version.workspace = true
```

## Shared Dependencies

Define versions once in `[workspace.dependencies]`, reference with `.workspace = true` in members:

```toml
# Root Cargo.toml
[workspace.dependencies]
serde = { version = "1", features = ["derive"] }

# Member Cargo.toml
[dependencies]
serde.workspace = true
```

To add features for a specific member:

```toml
[dependencies]
tokio = { workspace = true, features = ["test-util"] }
```

## Path Dependencies

Members reference each other with path dependencies:

```toml
[dependencies]
core = { path = "../core" }
```

These are resolved at build time. Cargo ensures all workspace members use compatible versions.

## Feature Flags Across Workspace

Define features in individual crates and propagate through path dependencies:

```toml
# crates/core/Cargo.toml
[features]
default = []
postgres = ["dep:sqlx"]
metrics = ["dep:prometheus"]

# crates/api/Cargo.toml
[dependencies]
core = { path = "../core", features = ["postgres", "metrics"] }
```

## Running Commands

```shell
# Run across all members
cargo check --workspace
cargo test --workspace
cargo clippy --workspace --all-targets -- -D warnings

# Run for a specific member
cargo test -p my-api
cargo run -p my-cli

# Build specific binary
cargo build --release -p my-api
```

## Common Patterns

### Shared Types Crate

A `core` or `types` crate containing shared types, error definitions, and traits:

```text
crates/core/src/
  lib.rs          # re-exports
  error.rs        # shared error types
  types.rs        # domain types
  traits.rs       # shared trait definitions
```

### Binary + Library Split

Separate the binary entry point from logic for testability:

```text
crates/api/src/
  main.rs         # entry point, minimal
  lib.rs          # all logic, imported by main.rs and tests
```

### Internal Crates

Mark crates as internal (not published) by omitting `version` or adding `publish = false`:

```toml
[package]
name = "internal-utils"
publish = false
```
