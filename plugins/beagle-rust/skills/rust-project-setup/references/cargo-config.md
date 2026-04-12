# Cargo.toml Configuration

## Package Metadata

```toml
[package]
name = "my-crate"
version = "0.1.0"
edition = "2024"          # latest stable edition
rust-version = "1.85"     # minimum supported Rust version (MSRV)
description = "What this crate does"
license = "MIT OR Apache-2.0"
repository = "https://github.com/org/repo"
```

### Edition Selection

| Edition | When to Use |
|---------|-------------|
| 2024 | New projects (latest, best defaults) |
| 2021 | Projects supporting older Rust versions |
| 2018 | Legacy compatibility only |

Each edition enables new language features and changes some defaults. Editions are opt-in and backward compatible.

#### Edition 2024 Key Behavioral Changes

- **`unsafe_op_in_unsafe_fn` = deny**: Unsafe operations inside `unsafe fn` require explicit `unsafe {}` blocks
- **`unsafe extern` blocks**: `extern "C" {}` must be `unsafe extern "C" {}`
- **`unsafe` attributes**: `#[no_mangle]` becomes `#[unsafe(no_mangle)]`, same for `#[export_name]`
- **`gen` keyword reserved**: Use `r#gen` if you have identifiers named `gen`
- **RPIT lifetime capture**: `-> impl Trait` captures all in-scope lifetimes; use `+ use<'a, T>` for precise control
- **`never_type_fallback`**: `!` falls back to `!` instead of `()`
- **Temporary drop scopes**: Temporaries in `if let` conditions and tail expressions drop earlier
- **`IntoIterator` for `Box<[T]>`**: Now available without explicit conversion

Run `cargo fix --edition` to auto-migrate most mechanical changes when upgrading.

### MSRV (Minimum Supported Rust Version)

Set `rust-version` to declare the oldest Rust version your crate supports. CI should test against this version.

```toml
rust-version = "1.85"
```

## Dependencies

### Version Specification

```toml
[dependencies]
# Libraries: semver range (compatible updates)
serde = "1"
tokio = { version = "1", features = ["rt-multi-thread", "macros"] }

# Binaries: exact pinning (reproducible builds)
reqwest = "=0.12.5"

# Git dependencies (development only, never publish with these)
my-fork = { git = "https://github.com/user/fork", branch = "fix" }

# Path dependencies (workspace members)
shared-types = { path = "../shared-types" }

[dev-dependencies]
insta = { version = "1", features = ["yaml"] }
rstest = "0.23"
pretty_assertions = "1"
tokio = { version = "1", features = ["test-util"] }

[build-dependencies]
# Only for build.rs scripts
```

### Version Specifier Patterns

| Specifier | Meaning | Use When |
|-----------|---------|----------|
| `"1"` | `>=1.0.0, <2.0.0` | Library deps (wide compatibility) |
| `"1.4"` | `>=1.4.0, <2.0.0` | You need features added in 1.4 |
| `"1.4.3"` (or `"^1.4.3"`) | `>=1.4.3, <2.0.0` | Default caret behavior |
| `"~1.4.3"` | `>=1.4.3, <1.5.0` | Lock to a specific minor version |
| `"=1.4.3"` | Exactly `1.4.3` | Binary pinning, reproducibility |
| `">=1.4, <1.7"` | Range | Avoid known-broken versions |

Set the **minimum version that actually works**, not the latest. Use `cargo +nightly -Zminimal-versions check` to verify your lower bounds are correct. If your code needs something added in 1.6, don't specify `"1"` when `"1.6"` is the honest minimum.

### Patching Dependencies

Override any dependency source temporarily for testing fixes or unreleased changes:

```toml
[patch.crates-io]
regex = { path = "/home/dev/regex" }
serde = { git = "https://github.com/serde-rs/serde.git", branch = "fix" }
```

Patches apply globally across the dependency graph but are not carried into published crates. Use for development only.

### Feature Flags

Define optional features to reduce compile time and binary size:

```toml
[features]
default = ["json"]
json = ["dep:serde_json"]
full = ["json", "yaml", "toml-support"]
yaml = ["dep:serde_yaml"]
toml-support = ["dep:toml"]
```

Use `dep:` prefix (Rust 1.60+) to avoid implicit feature names from optional dependencies.

### Feature Composability Rules

Features must be **additive**. Enabling a feature should never remove types, modules, or function signatures. Cargo takes the **union** of all requested features when multiple crates depend on the same dependency with different features — mutually exclusive features break downstream builds.

Key gotchas:

- **Conditional public items**: If a public struct field or enum variant is gated by a feature, mark the type `#[non_exhaustive]`. Otherwise, dependents without the feature may stop compiling when another crate enables it.
- **Feature-gated trait impls**: Adding a trait impl behind a feature is safe. Removing one is breaking.
- **Test all combinations**: Use `cargo hack check --feature-powerset --no-dev-deps` to verify every combination compiles.

### Workspace Dependency Inheritance

Define dependency versions once at the workspace root, reference in members:

```toml
# Root Cargo.toml
[workspace.dependencies]
serde = { version = "1", features = ["derive"] }
tokio = { version = "1", features = ["rt-multi-thread", "macros"] }
tracing = "0.1"
```

```toml
# Member Cargo.toml
[dependencies]
serde.workspace = true
tokio = { workspace = true, features = ["test-util"] }  # extend features per-member
```

Members can add features on top of the workspace baseline. Version and base features stay consistent across the workspace.

### Deprecated Dependency Replacements

With Rust 1.80+ (required for edition 2024), several popular crates have stdlib replacements:

| Crate | Replacement | Since |
|-------|-------------|-------|
| `once_cell` | `std::sync::LazyLock`, `std::cell::LazyCell` | 1.80 |
| `lazy_static` | `std::sync::LazyLock` | 1.80 |

```rust
// BAD: external dependency for edition 2024 projects
use once_cell::sync::Lazy;
static CONFIG: Lazy<Config> = Lazy::new(|| Config::load());

// GOOD: stdlib LazyLock (stable since 1.80)
use std::sync::LazyLock;
static CONFIG: LazyLock<Config> = LazyLock::new(|| Config::load());
```

## Profiles

### Release Profile

```toml
[profile.release]
lto = true           # link-time optimization (slower build, faster binary)
codegen-units = 1    # single codegen unit (slower build, better optimization)
strip = true         # strip debug symbols (smaller binary)
panic = "abort"      # smaller binary, no unwinding (not for libraries)
```

### Development Profile

```toml
[profile.dev]
opt-level = 0        # fast compilation (default)

[profile.dev.package."*"]
opt-level = 2        # optimize dependencies but not your code
```

### Test Profile

```toml
[profile.test]
opt-level = 1        # slightly faster test execution
```

### Custom Profiles

Define profiles beyond dev/release for specialized builds:

```toml
[profile.profiling]
inherits = "release"
debug = true          # debug symbols for perf/flamegraph
strip = false

[profile.embedded]
inherits = "release"
opt-level = "s"       # optimize for binary size
lto = true
codegen-units = 1
panic = "abort"
```

Use with `cargo build --profile profiling`. Each profile gets its own `target/<profile-name>/` output directory.

### Per-Dependency Profile Overrides

Optimize specific dependencies differently from your own code:

```toml
[profile.dev.package.serde]
opt-level = 3         # full optimization for serde even in debug

[profile.dev.package."*"]
opt-level = 2         # moderate optimization for all other deps
```

Useful when a dependency is prohibitively slow in debug mode (compression, video encoding, crypto). Note: generic code monomorphized in your crate uses your crate's profile settings, not the dependency override.

## Supply Chain Auditing with cargo-deny

Configure `cargo-deny` for automated dependency auditing in CI:

```shell
cargo install cargo-deny
cargo deny init       # creates deny.toml
cargo deny check      # run all checks
```

```toml
# deny.toml
[licenses]
allow = ["MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause"]

[bans]
multiple-versions = "warn"
wildcards = "deny"

[advisories]
vulnerability = "deny"
unmaintained = "warn"

[sources]
allow-git = []
```

Also run `cargo audit` for security vulnerability checks. Both tools complement each other: `cargo-deny` covers licenses and duplicates, `cargo-audit` focuses on CVEs.

## Clippy and Lint Configuration

### Package-Level Lints

```toml
[lints.clippy]
all = { level = "deny", priority = 10 }
redundant_clone = { level = "deny", priority = 9 }
pedantic = { level = "warn", priority = 3 }

[lints.rust]
future-incompatible = "warn"
nonstandard_style = "deny"
unsafe_code = "deny"          # for crates that should never use unsafe
# unsafe_op_in_unsafe_fn is deny-by-default in edition 2024 — no explicit entry needed
```

#### Edition 2024 Lint Defaults

These lints are deny-by-default in edition 2024 and do not need explicit configuration:

| Lint | Effect |
|------|--------|
| `unsafe_op_in_unsafe_fn` | Unsafe ops in `unsafe fn` require explicit `unsafe {}` blocks |
| `never_type_fallback_flowing_into_unsafe` | Prevents `!` fallback into unsafe contexts |

Use `#[expect(lint)]` instead of `#[allow(lint)]` for temporary suppressions — it warns when the suppression becomes unnecessary:

```rust
#[expect(clippy::needless_pass_by_value, reason = "required by framework trait")]
fn handler(req: Request) -> Response { /* ... */ }
```

### Workspace-Level Lints

Define once, inherit everywhere:

```toml
# Root Cargo.toml
[workspace.lints.clippy]
all = { level = "deny", priority = 10 }
pedantic = { level = "warn", priority = 3 }
```

```toml
# Member Cargo.toml
[lints]
workspace = true
```

## rustfmt.toml

```toml
edition = "2024"
max_width = 100
reorder_imports = true
imports_granularity = "Crate"
group_imports = "StdExternalCrate"
use_field_init_shorthand = true
```

Place in the repository root. Runs automatically with `cargo fmt`.

## Cargo.lock Policy

| Project Type | Commit Cargo.lock? | Reason |
|-------------|-------------------|--------|
| Binary / Application | Yes | Reproducible builds |
| Library | No | Consumers resolve their own versions |
| Workspace with binaries | Yes | Binary members need reproducible builds |

For libraries, add to `.gitignore`:

```gitignore
Cargo.lock
```

## Useful Commands

```shell
cargo check           # fast type checking without building
cargo build --release # optimized build
cargo test            # run all tests
cargo doc --open      # generate and view documentation
cargo tree            # show dependency tree
cargo audit           # check for security vulnerabilities
cargo update          # update dependencies within semver constraints
cargo clippy --fix    # auto-fix clippy suggestions
```
