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

## Additive Features Only

Cargo unifies feature sets across the dependency graph: if any crate in the build enables feature `X` on crate `C`, every dependent of `C` sees `X` enabled. Features must therefore be **purely additive** — enabling one must never remove, replace, or change the signature of behavior another caller relies on. Mutually exclusive features (`std` vs `no_std`, `tokio` vs `async-std`, `sync` vs `async`) silently break downstream consumers the moment two transitive deps disagree.

A common anti-pattern is a "default-on" / "default-off" pair where enabling both yields broken behavior:

```toml
# Anti-pattern: mutually exclusive runtimes
[features]
default = ["tokio"]
tokio = ["dep:tokio"]
async-std = ["dep:async-std"]  # enabling BOTH compiles two runtimes
```

The correct shape splits incompatible behavior into separate crates (`mycrate-tokio`, `mycrate-async-std`) or picks one runtime as the only supported choice. See [workspace-layout.md](workspace-layout.md) for the multi-crate facade pattern.

## Optional Dependencies Are Features

Adding `optional = true` to a dependency automatically creates a same-named feature. Cargo 1.60+ supports `dep:` syntax to suppress the implicit feature and keep dep names out of the feature namespace:

```toml
[dependencies]
serde = { version = "1", optional = true }
serde_json = { version = "1", optional = true }

[features]
default = []
serialization = ["dep:serde", "dep:serde_json"]
```

Without `dep:`, `serde` becomes a public feature whether you wanted it or not, and renaming the dep becomes a breaking change. Pair this with `cargo-hack` to test the full feature powerset in CI:

```shell
cargo hack check --feature-powerset --no-dev-deps
```

## Workspace vs Published Version Type Identity

A workspace member that depends on a sibling via `path = "../othercrate"` produces a **different type identity** than the same crate downloaded from crates.io. If your published `mycrate` lists `othercrate = "1.0"` and a downstream consumer pulls `othercrate = "1.1"`, types crossing that boundary are *not* the same — even though the source is identical. The symptom is a baffling `expected Foo, found Foo` error.

Rule: use `path` deps between workspace members **only** for unpublished changes. Once a sibling has a release that matches, switch to `version = "1.0"` (or keep both: `{ path = "../other", version = "1.0" }`). CI strategy: add a "consumer build" job that depends on the published crate via crates.io alongside the workspace-internal build. See [workspace-layout.md](workspace-layout.md) for the dual-CI matrix.

## MSRV (Minimum Supported Rust Version) Discipline

Declare MSRV in the package manifest; Cargo refuses to compile on older toolchains:

```toml
[package]
rust-version = "1.85"
```

Policy rules:

- **Bumping MSRV is a minor-version break.** Bump the minor (`2.6.0` → `2.7.0`), not the patch, so users pinned to the old MSRV can stay on `2.6.x` and still receive security patches.
- **CI must test MSRV.** Add a job: `rustup install 1.85 && cargo +1.85 check --all-targets --all-features`.
- **Minimal-version testing.** Run `cargo +nightly update -Z minimal-versions && cargo +nightly check` to resolve every dep to the *lowest* version matching its semver range. Catches the bug where you wrote `serde = "1"` but actually use a method added in `1.0.150`.

## Conditional Compilation Hygiene

`[target.cfg(...).dependencies]` is evaluated **before** features and contexts are known. Only built-in target cfgs are available: `unix`, `windows`, `target_os`, `target_arch`, `target_pointer_width`, `target_env`, `target_endian`. Feature cfgs and `test` are silently ignored.

```toml
# BROKEN: silently ignored, dep never pulled in
[target.'cfg(feature = "compression")'.dependencies]
flate2 = "1"

# CORRECT: optional dep with feature gate
[dependencies]
flate2 = { version = "1", optional = true }

[features]
compression = ["dep:flate2"]
```

`#[cfg(test)]` is set **only** when compiling the current crate as a test binary. It is *not* visible to integration tests (`tests/`) compiled against your library, and not visible to dependents. Use a dedicated `testing` feature or `pub(crate)` test helpers instead.

## Review Checks (Features and Versioning)

- [Cargo.toml:LINE] MUTUALLY_EXCLUSIVE_FEATURES — feature pair where enabling both breaks the build (e.g. `tokio` + `async-std`, `std` + `no-std`). Cargo unifies feature sets; the broken combination *will* appear in some downstream graph. Split into separate crates.
- [.github/workflows/ci.yml:LINE] NO_FEATURE_POWERSET_IN_CI — CI runs only `cargo build` or `cargo test --all-features`; add `cargo hack check --feature-powerset --no-dev-deps` to catch combinations that don't compile.
- [Cargo.toml:LINE] WORKSPACE_PATH_ONLY_NO_CONSUMER_BUILD — workspace member depends on sibling via `path = "..."` with no `version`, and CI never tests the published-version path. Add a consumer-build job or pin `version = "..."` alongside the path.
- [.github/workflows/ci.yml:LINE] MSRV_CLAIMED_BUT_NOT_TESTED — `rust-version = "1.85"` set in Cargo.toml but CI matrix has only `stable`. Add a `1.85` job; otherwise the MSRV claim drifts silently.
- [Cargo.toml:LINE] FEATURE_CFG_IN_TARGET_DEPS — `[target.'cfg(feature = "x")'.dependencies]` is silently ignored at dep resolution. Move to `[dependencies]` with `optional = true` and a `[features]` entry using `dep:` syntax.
- [src/lib.rs:LINE] DEFAULT_FEATURE_GATES_BEHAVIOR_REMOVAL — disabling a default feature removes a public method or changes a type signature; non-additive. Restructure so the feature only *adds* items.
- [Cargo.toml:LINE] OPTIONAL_DEP_NO_DEP_PREFIX — `[features] foo = ["serde"]` instead of `["dep:serde"]` leaks the dep name as a public feature. Use `dep:` (requires MSRV `>= 1.60`).
- [CHANGELOG.md:LINE] MSRV_BUMP_PATCH_RELEASE — MSRV raised from `1.80` to `1.85` in version `2.6.1` (patch). Bump minor instead so pinned users stay on `2.6.x` for security fixes.
- [src/lib.rs:LINE] PER_FEATURE_DOCTEST_MISSING — public item gated `#[cfg(feature = "json")]` has a doctest that only runs with default features; add `#[cfg_attr(not(feature = "json"), doc = "...")]` or run doctests under `cargo hack`.
- [src/lib.rs:LINE] FEATURE_GATED_ITEM_DOC_DESYNC — `pub fn` is `#[cfg(feature = "x")]`-gated but rustdoc shows it unconditionally (or vice versa); add `#[doc(cfg(feature = "x"))]` (nightly) and set `[package.metadata.docs.rs] all-features = true` so docs.rs renders the gate.
- [Cargo.toml:LINE] DEP_VERSION_TOO_LAX_FOR_API_USED — listed `serde = "1"` but code calls a method added in `1.0.150`; verify via `cargo +nightly -Z minimal-versions update` and tighten to `"1.0.150"`.
- [Cargo.toml:LINE] PUBLIC_FEATURE_GATED_ITEM_NOT_NON_EXHAUSTIVE — `pub enum E { #[cfg(feature = "x")] Variant }` without `#[non_exhaustive]`; transitive enabling will break downstream `match` arms.
