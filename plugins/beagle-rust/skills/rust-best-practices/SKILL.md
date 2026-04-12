---
name: rust-best-practices
description: >
  Development guidance for writing idiomatic Rust. Use when:
  (1) writing new Rust functions or modules,
  (2) choosing between borrowing, cloning, or ownership patterns,
  (3) implementing error handling with Result types,
  (4) optimizing Rust code for performance,
  (5) configuring clippy and linting for a project,
  (6) deciding between static and dynamic dispatch,
  (7) writing documentation or doc tests.
---

# Rust Best Practices

Guidance for writing idiomatic, performant, and safe Rust code. This is a development skill, not a review skill -- use it when building, not reviewing.

## Quick Reference

| Topic | Key Rule | Reference |
|-------|----------|-----------|
| Ownership | Borrow by default, clone only when you need a separate owned copy | [references/coding-idioms.md](references/coding-idioms.md) |
| Clippy | Run `cargo clippy -- -D warnings` on every commit; configure workspace lints | [references/clippy-config.md](references/clippy-config.md) |
| Performance | Don't guess, measure. Profile with `--release` first | [references/performance.md](references/performance.md) |
| Generics | Static dispatch by default, dynamic dispatch when you need mixed types | [references/generics-dispatch.md](references/generics-dispatch.md) |
| Type State | Encode state in the type system when invalid operations should be compile errors | [references/type-state-pattern.md](references/type-state-pattern.md) |
| Documentation | `//` for why, `///` for what and how, `//!` for module/crate purpose | [references/documentation.md](references/documentation.md) |
| Pointers | Choose pointer types based on ownership needs and threading model | [references/pointer-types.md](references/pointer-types.md) |
| API Design | Unsurprising, flexible, obvious, constrained -- encode invariants in types | [references/api-design.md](references/api-design.md) |
| Ecosystem | Evaluate crates, pick error handling strategy, stay current | [references/ecosystem-patterns.md](references/ecosystem-patterns.md) |

## Coding Idioms

Prefer `&T` over `.clone()`, use `&str`/`&[T]` in parameters, and chain iterators instead of index-based loops. For Option/Result, use `let Ok(x) = expr else { return }` for early returns and `?` for propagation. See [references/coding-idioms.md](references/coding-idioms.md) for ownership, iterator, and import patterns.

## Error Handling

Return `Result<T, E>` for fallible operations. Use `thiserror` for library error types, `anyhow` for binaries. Propagate with `?`, never `unwrap()` outside tests. See [references/coding-idioms.md](references/coding-idioms.md) for Option/Result patterns.

## Clippy Discipline

Run `cargo clippy --all-targets --all-features -- -D warnings` on every commit. Configure workspace lints in `Cargo.toml` and use `#[expect(clippy::lint)]` (not `#[allow]`) as the standard for lint suppression -- it warns when the suppression becomes stale. See [references/clippy-config.md](references/clippy-config.md) for lint configuration and key lints.

## Performance Mindset

Always benchmark with `--release`, profile before optimizing, and avoid cloning in loops or premature `.collect()` calls. Keep small types on the stack and heap-allocate only recursive structures and large buffers. See [references/performance.md](references/performance.md) for profiling tools and allocation guidance.

## Generics and Dispatch

Use static dispatch (`impl Trait` / `<T: Trait>`) by default for zero-cost monomorphization. Switch to `dyn Trait` only for heterogeneous collections or plugin architectures, preferring `&dyn Trait` over `Box<dyn Trait>` when ownership isn't needed. In edition 2024, `-> impl Trait` captures all in-scope lifetimes by default -- use `+ use<'a, T>` for precise capture control. Prefer native `async fn` in traits over the `async-trait` crate for static dispatch. See [references/generics-dispatch.md](references/generics-dispatch.md) for dispatch trade-offs, RPIT capture rules, and async trait guidance.

## Type State Pattern

Encode valid states in the type system so invalid operations become compile errors. Use for builders with required fields, protocol state machines, and workflow pipelines. See [references/type-state-pattern.md](references/type-state-pattern.md) for implementation patterns and when to avoid.

## Documentation

Use `//` for why, `///` for what/how on public APIs, and `//!` for module purpose. Every `TODO` needs a linked issue and library crates should enable `#![deny(missing_docs)]`. Use `#[diagnostic::on_unimplemented]` to provide custom compiler errors for your public traits. See [references/documentation.md](references/documentation.md) for doc test patterns, comment conventions, and diagnostic attributes.

## API Design

Follow four principles: unsurprising (reuse standard names and traits), flexible (use generics and `impl Trait` to avoid unnecessary restrictions), obvious (encode invariants in the type system so misuse is a compile error), and constrained (expose only what you can commit to long-term). Use `#[non_exhaustive]` for types that may grow, seal traits you need to extend without breaking changes, and wrap foreign types in newtypes to control your SemVer surface. See [references/api-design.md](references/api-design.md) for builder patterns, sealed traits, and SemVer implications.

## Ecosystem Patterns

Evaluate crates by recent download trends, maintenance activity, documentation quality, and transitive dependency weight. Use `thiserror` for library error types, `anyhow` for binaries, and `eyre` when you need custom error reporters. Prefer vendoring or writing code yourself when a crate pulls heavy dependencies for a small feature. Run `cargo-deny` for license and vulnerability auditing and `cargo-udeps` to trim unused dependencies. See [references/ecosystem-patterns.md](references/ecosystem-patterns.md) for crate evaluation criteria, edition migration, and essential tooling.

## Pointer Types

Choose pointer types based on ownership and threading: `Box<T>` for single-owner heap allocation, `Rc<T>`/`Arc<T>` for shared ownership, `Cell`/`RefCell`/`Mutex`/`RwLock` for interior mutability. Use `LazyLock`/`LazyCell` (stable since 1.80) instead of `lazy_static` or `once_cell`. See [references/pointer-types.md](references/pointer-types.md) for the full single-thread vs multi-thread decision table and migration guidance.
