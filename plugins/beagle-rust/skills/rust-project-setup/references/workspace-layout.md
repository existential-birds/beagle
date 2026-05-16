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

## Profile Tuning for Release Builds

The default `[profile.release]` leaves serious performance on the table. The knobs that matter for shipped binaries:

- `opt-level = 3` — full optimization (default). Drop to `"s"` or `"z"` only for size-constrained targets (wasm, embedded).
- `lto = "thin"` — parallel cross-crate inlining. The sweet spot for most projects. Use `"fat"` (or `true`) for whole-program LTO when binary size and runtime matter more than build time.
- `codegen-units = 1` — sacrifices build parallelism for better optimization. Combine with LTO. Only worth it for the final shipped artifact.
- `panic = "abort"` — smaller binary, no unwinding tables. **Destructors do not run on panic** and `catch_unwind` becomes a no-op. The setting is global across all deps — audit every dep's reliance on unwinding before flipping.
- `strip = "symbols"` (Cargo 1.59+) — removes debug symbols from the final binary, often shrinking it 50-80%.

```toml
[profile.release]
opt-level = 3        # full speed
lto = "thin"         # cross-crate inlining
codegen-units = 1    # max optimization for shipped binary
panic = "abort"      # audit deps first!
strip = "symbols"    # smaller binary, lose backtrace names
```

See [cargo-config.md](cargo-config.md) for `RUSTFLAGS` interactions with these knobs.

## `profile.dev.package` Overrides for Slow Deps

Heavy dependencies stay painful in debug mode unless overridden. Compile expensive deps in release mode once; they cache in `target/` and never recompile slowly again:

```toml
[profile.dev.package."*"]
opt-level = 0          # default: dev profile for our code

[profile.dev.package.serde_derive]
opt-level = 3          # proc-macro compiled once, reused forever

[profile.dev.package.regex]
opt-level = 3          # CPU-bound, kills test wall time in debug
```

Best targets: proc-macro deps (`serde_derive`, `tokio-macros`, `async-trait`) and CPU-bound deps (`regex`, `image`, `zstd`, `ring`). Caveat: overrides only affect code compiled inside that crate — generics monomorphized in your crate use your profile.

## Workspace Compile-Time Budgets at Scale

When a workspace crosses ~20 members and 100k LOC, build time dominates dev iteration. Strategies that compound:

- **Split feature flags** so dev disables expensive deps (typed-builder, derive-heavy serde features). See [features-conditional.md](features-conditional.md).
- **Shared target dir**: `CARGO_TARGET_DIR=/shared/target` across workspaces, or `sccache` for cross-machine caching.
- **`cargo-nextest`** for test parallelism — scales beyond `cargo test`'s per-binary model on workspaces with many crates.
- **Member partitioning**: heavy proc-macro deps live in a single leaf crate; leaves only rebuild on `cargo build -p leaf`.
- **`RUSTFLAGS="-Zthreads=8"`** on nightly enables the parallel rustc frontend, a measurable win on workspaces with many small crates.

## Cargo.toml Metadata Completeness

For any crate intended for crates.io, the `[package]` block must be filled out completely. Missing fields silently make your crate undiscoverable or ship the wrong files.

```toml
[package]
name = "mycrate"
version = "0.1.0"
edition = "2024"
rust-version = "1.85"
description = "Concise one-line summary."   # required for publish
license = "MIT OR Apache-2.0"
repository = "https://github.com/org/repo"
documentation = "https://docs.rs/mycrate"   # explicit, not inferred
readme = "README.md"
keywords = ["cli", "parser"]                 # max 5
categories = ["command-line-utilities"]      # from crates.io/category_slugs
include = ["src/**/*", "Cargo.toml", "README.md", "LICENSE-*"]
```

Missing `categories`/`keywords` and crates.io search ranks you nowhere. Missing `include` and `cargo publish` ships your `target/`, `.env`, fixture data, and any dotfile not in `.gitignore`.

## Additional Review Checks

- [Cargo.toml] PANIC_ABORT_IN_RELEASE_WITHOUT_AUDIT — `panic = "abort"` set globally; review every `catch_unwind` site and `Drop` impl that performs cleanup. The setting is global across all deps.
- [Cargo.toml] MISSING_LTO_IN_RELEASE_PROFILE — release profile without `lto = "thin"` or `"fat"` leaves cross-crate inlining on the table; add when shipping a binary or hot library.
- [Cargo.toml] CODEGEN_UNITS_NOT_TUNED_FOR_BINARY — final binary uses default `codegen-units = 16`; consider `1` plus LTO for the shipped artifact.
- [Cargo.toml] PROC_MACRO_DEP_NOT_OVERRIDDEN — heavy proc-macro dep (`serde_derive`, `tokio-macros`) without `[profile.dev.package.X] opt-level = 3`; debug builds pay the cost every clean rebuild.
- [Cargo.toml] MISSING_METADATA_FOR_PUBLICATION — package missing `description`, `license`, or `repository` for crates.io; publish will fail or the crate will be undiscoverable.
- [Cargo.toml] MISSING_INCLUDE_OR_EXCLUDE — no `include` or `exclude`; `cargo publish` ships build artifacts, dotfiles, and fixtures not in `.gitignore`.
- [Cargo.toml] STRIP_NOT_SET_IN_RELEASE — release binary keeps debug symbols; `strip = "symbols"` reduces binary size 50-80% for typical Rust artifacts.
- [Cargo.toml] EDITION_NOT_DECLARED — `edition = "..."` missing from `[package]`; silently defaults to 2015 and disables most modern idioms.
