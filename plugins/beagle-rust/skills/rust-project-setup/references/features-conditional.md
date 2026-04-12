# Features and Conditional Compilation

## Feature Flag Design

Features must be **additive and composable**. Enabling a feature should never remove functionality or break compilation. If crate A compiles with some set of features on crate C, it must also compile with all features enabled on crate C.

Cargo takes the **union** of all requested features when multiple dependents enable different features on the same crate. Mutually exclusive features break downstream builds.

### Default Features

Curate defaults for the common case. Let users opt out of heavy dependencies:

```toml
[features]
default = ["json", "logging"]
json = ["dep:serde_json"]
logging = ["dep:tracing"]
full = ["json", "logging", "yaml", "compression"]
yaml = ["dep:serde_yaml"]
compression = ["dep:flate2"]
```

Use `dep:` prefix (Rust 1.60+) to avoid implicit feature names from optional dependencies.

### `std` Feature Pattern for no_std Crates

Use an additive `std` feature, not a subtractive `no-std` feature:

```toml
[features]
default = ["std"]
std = []
alloc = []
```

```rust
#![cfg_attr(not(feature = "std"), no_std)]

#[cfg(feature = "alloc")]
extern crate alloc;

#[cfg(feature = "std")]
pub fn read_file(path: &str) -> std::io::Result<Vec<u8>> {
    std::fs::read(path)
}
```

This way, any crate in the dependency graph enabling `std` adds functionality rather than removing it.

### Feature Documentation

Document what each feature enables. Users should not have to read source to understand features:

```toml
[package.metadata.docs.rs]
all-features = true  # build docs with all features enabled
```

### Testing Feature Combinations

Use `cargo-hack` to verify all feature combinations compile:

```shell
cargo install cargo-hack
cargo hack check --feature-powerset --no-dev-deps
```

Configure CI to run this check. Any combination of features must compile.

## Conditional Compilation

### `#[cfg(...)]` Attribute

Place on items (functions, types, impl blocks, modules, use statements, struct fields):

```rust
#[cfg(feature = "metrics")]
mod metrics;

#[cfg(target_os = "linux")]
fn platform_init() { /* linux-specific */ }

#[cfg(all(feature = "std", target_arch = "x86_64"))]
fn optimized_path() { /* ... */ }
```

### `cfg_attr` for Conditional Attributes

Apply attributes only when a condition holds:

```rust
#[cfg_attr(feature = "serde", derive(serde::Serialize, serde::Deserialize))]
pub struct Config {
    pub name: String,
}

#[cfg_attr(miri, ignore)]
#[test]
fn expensive_test() { /* skipped under Miri */ }
```

### Common cfg Options

| Option | Example | Use |
|--------|---------|-----|
| `feature = "name"` | `cfg(feature = "json")` | Feature-gated code |
| `target_os` | `cfg(target_os = "macos")` | OS-specific code |
| `unix` / `windows` | `cfg(unix)` | OS family shorthand |
| `target_arch` | `cfg(target_arch = "aarch64")` | Architecture-specific |
| `test` | `cfg(test)` | Test-only code (current crate only) |
| `debug_assertions` | `cfg(debug_assertions)` | Debug mode only |

Combine with `all()`, `any()`, `not()`:

```rust
#[cfg(any(target_os = "linux", target_os = "macos"))]
fn unix_like_setup() { /* ... */ }
```

### Conditional Dependencies

Gate platform-specific dependencies in Cargo.toml:

```toml
[target.'cfg(windows)'.dependencies]
winapi = { version = "0.3", features = ["winuser"] }

[target.'cfg(unix)'.dependencies]
nix = "0.29"
```

Note: only target-based cfg options work here. Feature and context options are not available at dependency resolution time.

## Build Scripts (build.rs)

Use build scripts for compile-time code generation and native library compilation:

```rust
// build.rs
fn main() {
    // Link a native library
    println!("cargo:rustc-link-lib=static=mylib");
    println!("cargo:rustc-link-search=native=/usr/local/lib");

    // Set a custom cfg option
    println!("cargo:rustc-cfg=has_feature_x");

    // Rerun only when this file changes
    println!("cargo:rerun-if-changed=wrapper.h");
}
```

Declare build script dependencies separately:

```toml
[build-dependencies]
cc = "1"          # compile C/C++ code
bindgen = "0.72"  # generate FFI bindings
```

## Project Directory Organization

### Examples Directory

Place runnable examples in `examples/`:

```text
examples/
  basic.rs           # cargo run --example basic
  advanced/
    main.rs          # cargo run --example advanced
    helper.rs
```

### Benchmarks Directory

Place benchmarks in `benches/`:

```text
benches/
  throughput.rs      # cargo bench --bench throughput
```

Use `criterion` for stable benchmarks (the built-in `#[bench]` is nightly-only):

```toml
[[bench]]
name = "throughput"
harness = false

[dev-dependencies]
criterion = { version = "0.8", features = ["html_reports"] }
```

## Dependency Auditing

See [cargo-config.md](cargo-config.md) for `cargo-deny` setup covering license compliance, duplicate detection, and vulnerability scanning.
