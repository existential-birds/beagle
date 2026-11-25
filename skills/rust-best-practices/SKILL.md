---
name: rust-best-practices
description: "Development guidance for writing idiomatic, performant, and safe Rust. Use when writing new Rust modules, designing library APIs, configuring Cargo workspace lints and features, optimizing monomorphization or cache alignment, or migrating to Rust Edition 2024."
---

# Rust Best Practices

Guidance for writing idiomatic, performant, and safe Rust code. This is a development skill, not a review skill -- use it when building, not reviewing.

## Quick Reference

| Topic | Key Rule | Reference |
|-------|----------|-----------|
| Idioms & Edition 2024 | `LazyLock`/`OnceLock`, Edition 2024 rules, drop guards, extension traits, index pointers, preludes | [references/coding-idioms.md](references/coding-idioms.md) |
| Clippy | Run `cargo clippy -- -D warnings`; set `priority = -1` on lint groups in `[workspace.lints.clippy]` | [references/clippy-config.md](references/clippy-config.md) |
| Performance | Profile `--release`; watch monomorphization budgets, cache-line alignment, `std::hint::black_box` | [references/performance.md](references/performance.md) |
| Generics & Dispatch | Edition 2024 RPIT `+ use<>`, AFIT vs `async-trait`, variance, dyn compatibility, blanket impls | [references/generics-dispatch.md](references/generics-dispatch.md) |
| Documentation | `///` sections, `nextest` `--doc` caveat, `#[diagnostic::on_unimplemented]`, doc lints | [references/documentation.md](references/documentation.md) |
| API Design | Unsurprising, flexible, obvious, constrained — hidden contracts, sealed traits, fallible `close()` | [references/api-design.md](references/api-design.md) |

## Gates

Short **sequences with pass conditions** before claiming outcomes that need evidence (not an internal “I checked”).

### Clippy clean

1. From the workspace root (or with `-p <crate>`), run: `cargo clippy --all-targets --all-features -- -D warnings`.
2. **Pass:** exit status is `0` and the invocation finishes without Clippy-deny failures.

### Performance claim

1. Build with `cargo build --release` (or your benchmark harness) under the same profile you ship or measure.
2. Capture a **before** and **after** number from the same tool and metric (name both), e.g. Criterion `ns/iter`, `heaptrack` allocations, or a flamegraph path on disk.
3. **Pass:** you can cite both measurements, **or** you explicitly state that only correctness or readability changed and you are **not** claiming a performance delta.

### Docs for symbols you changed

1. Run `cargo doc --no-deps` for the crate you edited (add `-p <crate>` in workspaces).
2. **Pass:** the doc build succeeds; if `#![deny(missing_docs)]` (or crate policy) applies, there are no new missing-doc errors for those symbols.

## Coding Idioms & Edition 2024

Borrow by default, prefer `std::sync::LazyLock` / `OnceLock` (stable since 1.80) over `once_cell` / `lazy_static`, and watch Edition 2024 changes (`gen` reserved keyword, `if let` / tail temporary drop order, `!` fallback). For scoped state changes, use **drop guards** (`let _guard = ...`, never `let _ = ...`) with `mem::replace` or `scopeguard::defer!`. Add methods to foreign types via **extension traits**, prefer **index pointers** (`slotmap::DefaultKey`) for cyclic graphs without unsafe, and curate a lean **crate prelude** (additions are semver-minor per RFC 1105). See [references/coding-idioms.md](references/coding-idioms.md).

## Error Handling & Crate Hygiene

- **Error crates**: Use `thiserror` in libraries (structured enums callers can match on), `anyhow` in binaries/CLIs (ergonomic context chaining), and `eyre` when custom error reporters are needed. Never expose `anyhow::Error` in a library's public API.
- **Auditing**: Run `cargo-deny` in CI for licenses, advisories, and duplicate bans; use `cargo-machete` (works on stable) or `cargo-udeps` (nightly) to prune unused dependencies.

## Cargo Feature & Workspace Pitfalls

- **Use `dep:` syntax** (Rust 1.60+) for optional dependencies (`json = ["dep:serde_json"]`) so dependency names do not leak into your public feature namespace.
- **Keep features additive**: Cargo takes the union of all enabled features across the dependency graph; verify combinations compile with `cargo hack check --feature-powerset --no-dev-deps` and verify MSRV lower bounds with `cargo +nightly update -Z minimal-versions && cargo +nightly check`.
- **`[target.'cfg(feature = "...")'.dependencies]` is silently ignored** — dependency resolution runs before features are evaluated; use `optional = true` + `[features]` instead.
- **Workspace `path` vs crates.io `version` identity**: Depending on a sibling via `path = "../foo"` without a published `version` can yield distinct `Foo` types when downstream consumers resolve `foo` from crates.io; specify `{ path = "../foo", version = "..." }` for published workspaces.
- **Compile-time overrides**: Set `[profile.dev.package.<slow-dep>] opt-level = 3` (or `opt-level = 3` on heavy proc-macro/crypto deps) to keep debug test builds fast.

## Clippy Discipline

Run `cargo clippy --all-targets --all-features -- -D warnings` on every commit. Configure workspace lints in `Cargo.toml` with negative priorities on lint groups (`priority = -1`) so individual lints override them, and use `#[expect(clippy::lint)]` (not `#[allow]`) as the standard for lint suppression. See [references/clippy-config.md](references/clippy-config.md).

## Performance Mindset

Benchmark with `--release`, profile with `samply` or `cargo flamegraph`, and avoid premature `.collect()` or stack-allocating large buffers before boxing (`vec![0u8; N].into_boxed_slice()`). Watch **monomorphization budgets** (extract non-generic inner functions) and **false sharing** (`#[repr(align(64))]` or `align(128)` on Apple Silicon, or `crossbeam::utils::CachePadded`). Benchmark with `criterion` — save baselines (`--save-baseline main`), use `std::hint::black_box` (with `as_ptr()` for pointer inputs), and isolate setup in `iter_batched`. See [references/performance.md](references/performance.md).

## Generics and Dispatch

Use static dispatch (`impl Trait` / `<T: Trait>`) by default; switch to `dyn Trait` for heterogeneous collections or compile-time boundaries. In Edition 2024, `-> impl Trait` captures all in-scope lifetimes by default — use `+ use<'a, T>` for precise capture. Prefer native `async fn` in traits over `async-trait` for static dispatch. See [references/generics-dispatch.md](references/generics-dispatch.md).

## Documentation & API Design

Document public items with `# Examples`, `# Errors`, `# Panics`, and `# Safety`, remember `cargo nextest` skips doctests (`cargo test --doc`), and use `#[diagnostic::on_unimplemented]` (Rust 1.78+) on complex public traits. See [references/documentation.md](references/documentation.md).

Follow the four API principles (unsurprising, flexible, obvious, constrained), guard against **hidden contracts** (re-exported foreign types, silent `!Send` auto-trait regressions checked with `is_normal<T>()`), ship blanket impls (`&T`, `&mut T`, `Box<T>`) early, keep traits **dyn-compatible** where needed, and expose explicit `close()`/`shutdown()` for fallible or async cleanup. See [references/api-design.md](references/api-design.md).

## Async APIs

`async fn` lowers to a state machine returning an anonymous `impl Future`. Lock down the **Send-ness** contract on public APIs with `-> impl Future<...> + Send + '_` — auto-trait propagation through `-> impl Trait` is silent and a single `Rc<...>` or `std::sync::MutexGuard` held across `.await` downgrades the whole future to `!Send`. Add `+ 'static` only when the future must be spawned onto a multi-threaded executor. **Drop equals cancel**: document **cancel-safety** on every public `async fn` (`recv` vs `read_exact`/`write_all`). Use `std::pin::pin!` for stack-pinned local futures; `Box::pin` only when heap allocation is needed.
