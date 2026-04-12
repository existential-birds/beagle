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
