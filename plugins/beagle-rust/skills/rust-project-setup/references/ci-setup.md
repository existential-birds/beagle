# CI Setup

## GitHub Actions for Rust

### Complete Workflow

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  CARGO_TERM_COLOR: always
  RUSTFLAGS: -Dwarnings

jobs:
  check:
    name: Check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      - uses: Swatinem/rust-cache@v2
      - run: cargo check --workspace --all-targets

  clippy:
    name: Clippy
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          components: clippy
      - uses: Swatinem/rust-cache@v2
      - run: cargo clippy --workspace --all-targets --all-features -- -D warnings

  # Edition 2024: unsafe_op_in_unsafe_fn is warn-by-default (not deny).
  # With `-D warnings` above, clippy will fail on these. For projects
  # mixing editions, add explicit flags:
  #   -- -D warnings -W unsafe_op_in_unsafe_fn

  test:
    name: Test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      - uses: Swatinem/rust-cache@v2
      - run: cargo test --workspace

  fmt:
    name: Format
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          components: rustfmt
      - run: cargo fmt --all --check

  msrv:
    name: MSRV
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@master
        with:
          toolchain: "1.85"  # match rust-version in Cargo.toml
      - uses: Swatinem/rust-cache@v2
      - run: cargo check --workspace
```

## Key Actions

### dtolnay/rust-toolchain

Installs a specific Rust toolchain. More reliable than `actions-rs`:

```yaml
- uses: dtolnay/rust-toolchain@stable
  with:
    components: clippy, rustfmt
```

For MSRV testing:

```yaml
- uses: dtolnay/rust-toolchain@master
  with:
    toolchain: "1.85"
```

### Swatinem/rust-cache

Caches Cargo registry, build artifacts, and target directory:

```yaml
- uses: Swatinem/rust-cache@v2
```

Automatic cache key based on Cargo.lock and toolchain. Typical speedup: 2-5x on subsequent runs.

Options:

```yaml
- uses: Swatinem/rust-cache@v2
  with:
    cache-on-failure: true    # cache even if build fails
    shared-key: "shared"      # share cache across jobs
```

## MSRV Testing

Test against the minimum supported Rust version declared in `Cargo.toml`:

```toml
# Cargo.toml
rust-version = "1.85"
```

The MSRV job uses that exact version. If it breaks, either:
- Fix the code to work on the MSRV
- Bump `rust-version` in Cargo.toml

### Edition 2024 MSRV

Edition 2024 requires Rust 1.85 or later. For projects using edition 2024, the MSRV cannot be lower than `1.85`. If your workspace mixes editions (e.g., a member still on edition 2021), the MSRV job should test against the highest edition's minimum:

```yaml
  msrv:
    name: MSRV
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@master
        with:
          toolchain: "1.85"  # edition 2024 minimum
      - uses: Swatinem/rust-cache@v2
      - run: cargo check --workspace
```

Consider a matrix strategy if you support multiple toolchain versions:

```yaml
  msrv:
    name: MSRV
    strategy:
      matrix:
        toolchain: ["1.85", "stable"]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@master
        with:
          toolchain: ${{ matrix.toolchain }}
      - uses: Swatinem/rust-cache@v2
        with:
          shared-key: "msrv-${{ matrix.toolchain }}"
      - run: cargo check --workspace
```

## Doc Tests

`cargo nextest` does not run doc tests. Run them separately:

```yaml
  doc-test:
    name: Doc Tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      - uses: Swatinem/rust-cache@v2
      - run: cargo test --doc --workspace
```

## Security Audit

Check dependencies for known vulnerabilities:

```yaml
  audit:
    name: Security Audit
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: rustsec/audit-check@v2
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
```

## Release Builds

For release pipelines, optimize build settings:

```yaml
  release:
    name: Release Build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      - uses: Swatinem/rust-cache@v2
      - run: cargo build --release
      - uses: actions/upload-artifact@v4
        with:
          name: binary
          path: target/release/my-app
```

## Cross-Compilation

Build for multiple targets:

```yaml
  cross:
    name: Cross-compile
    strategy:
      matrix:
        target:
          - x86_64-unknown-linux-gnu
          - aarch64-unknown-linux-gnu
          - x86_64-apple-darwin
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          targets: ${{ matrix.target }}
      - run: cargo check --target ${{ matrix.target }}
```

For full cross-compilation builds, consider the `cross` tool:

```shell
cargo install cross
cross build --target aarch64-unknown-linux-gnu --release
```

## Caching Strategy

| What | How | Impact |
|------|-----|--------|
| Cargo registry | `Swatinem/rust-cache` (automatic) | Avoids re-downloading crates |
| Build artifacts | `Swatinem/rust-cache` (automatic) | Avoids recompiling unchanged deps |
| sccache | Manual setup with `RUSTC_WRAPPER=sccache` | Shares cache across branches |

For large workspaces, consider `sccache` for cross-branch cache sharing.

## Workflow Tips

- Run `cargo check` before `cargo test` -- it is faster and catches most issues
- Use `RUSTFLAGS: -Dwarnings` in env to fail on warnings across all jobs
- Keep MSRV job separate -- it runs less often and has different cache needs
- Use `cargo nextest` for faster test execution (parallel, better output)
