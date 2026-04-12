# Clippy Configuration

## Daily Workflow Command

Run on every commit or PR:

```shell
cargo clippy --all-targets --all-features --locked -- -D warnings
```

- `--all-targets`: checks library, tests, benches, examples
- `--all-features`: enables all feature flags to catch conditional code
- `--locked`: requires Cargo.lock to be up-to-date (omit for library crates that don't commit `Cargo.lock`)
- `-D warnings`: treats warnings as errors

Add to your Makefile, Justfile, xtask, or CI pipeline.

## Workspace Lint Configuration

Configure in `Cargo.toml` for consistent enforcement:

```toml
[workspace.lints.rust]
future-incompatible = "warn"
nonstandard_style = "deny"

[workspace.lints.clippy]
all = { level = "deny", priority = 10 }
redundant_clone = { level = "deny", priority = 9 }
manual_while_let_some = { level = "deny", priority = 4 }
pedantic = { level = "warn", priority = 3 }
```

Individual crates inherit workspace lints:

```toml
[lints]
workspace = true
```

Higher priority numbers win when lints conflict.

## Key Lints to Enforce

| Lint | Why | Category |
|------|-----|----------|
| `redundant_clone` | Detects unnecessary clones with performance impact | perf |
| `large_enum_variant` | Warns about oversized variants -- consider Boxing | perf |
| `needless_collect` | Prevents unnecessary intermediate collection allocation | nursery |
| `needless_borrow` | Removes redundant `&` borrowing | style |
| `clone_on_copy` | Catches `.clone()` on Copy types like `u32` | complexity |
| `unnecessary_wraps` | Function always returns Some/Ok -- drop the wrapper | pedantic |
| `manual_ok_or` | Suggests `.ok_or_else()` over match | style |

Run the perf lint group specifically:

```shell
cargo clippy -- -D clippy::perf
```

## Lint Suppression

### Use `#[expect]` as the Default

`#[expect]` (stable since Rust 1.81) is the standard for lint suppression. It warns when the lint no longer triggers, preventing stale suppressions from accumulating. Always use `#[expect]` instead of `#[allow]`:

```rust
// BAD - stale allow stays forever unnoticed
#[allow(clippy::large_enum_variant)]
enum Message { /* ... */ }

// GOOD - compiler warns when lint is no longer needed
#[expect(clippy::large_enum_variant)]
enum Message { /* ... */ }
```

When migrating an existing codebase, replace all `#[allow(lint)]` with `#[expect(lint)]`. The compiler will immediately flag any suppressions that are no longer needed, letting you clean up dead lint suppression.

For crate-level suppression where `#![expect(...)]` is not practical (e.g., generated code), `#![allow(...)]` remains acceptable with a comment explaining why.

### Always Add Justification

```rust
// Intentionally large for cache-line alignment
#[expect(clippy::large_enum_variant, reason = "cache-line alignment")]
enum Packet {
    Header(u8),
    Payload([u8; 1024]),
}
```

The `reason` parameter (stable since 1.81) documents intent inline and shows up in compiler output when the expect becomes unfulfilled.

### Handling False Positives

1. Try refactoring to satisfy the lint
2. If the code is genuinely correct, suppress **locally** with `#[expect]` and a reason
3. Avoid global suppression unless it is a known framework issue (e.g., Bevy engine patterns)

## CI Integration

Add clippy to your CI pipeline:

```yaml
# GitHub Actions (application/binary crates that commit Cargo.lock)
- name: Clippy
  run: cargo clippy --all-targets --all-features --locked -- -D warnings

# Library crates (Cargo.lock not committed — omit --locked)
- name: Clippy
  run: cargo clippy --all-targets --all-features -- -D warnings
```

Consider adding pedantic and nursery for stricter checks:

```shell
cargo clippy -- -W clippy::pedantic -W clippy::nursery
```

## Optional Stricter Lints

| Group | When to Use |
|-------|-------------|
| `pedantic` | Strict style checks, occasional false positives |
| `nursery` | New lints under development, may be noisy |
| `perf` | Performance-focused checks (always recommended) |
| `restriction` | Very strict, use selectively (e.g., `clippy::unwrap_used`) |
