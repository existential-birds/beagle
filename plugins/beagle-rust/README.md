# beagle-rust

Rust, tokio, axum, sqlx, and serde code review. Part of the [beagle](https://github.com/existential-birds/beagle) Agent Skills marketplace — see the [full skill catalog](../../SKILLS.md).

## Installation

For any coding agent that supports [Agent Skills](https://agentskills.io):

```bash
npx skills add existential-birds/beagle
```

For Claude Code:

```bash
claude plugin marketplace add https://github.com/existential-birds/beagle
claude plugin install beagle-rust@existential-birds
```

## Skills

| Skill | Description |
|-------|-------------|
| `review-rust` | Comprehensive Rust review that fans out across detected technology areas, running in parallel when subagents are available |
| `rust-code-review` | Reviews ownership, borrowing, lifetimes, error handling, trait design, and unsafe usage for Rust 2024 idioms |
| `rust-best-practices` | Guidance for idiomatic Rust: borrowing vs cloning, Result-based errors, dispatch choices, perf, clippy, doc tests |
| `rust-project-setup` | Scaffolds new Rust projects and workspaces with Cargo.toml, CI, and clippy/rustfmt configuration |
| `tokio-async-code-review` | Reviews tokio runtime usage: task management, sync primitives, channels, runtime config, and tower/hyper integration |
| `axum-code-review` | Reviews axum 0.7+ services for routing, extractors, middleware, state management, and error handling |
| `sqlx-code-review` | Reviews sqlx code for compile-time query checking, pool management, migrations, offline mode, and PostgreSQL usage |
| `serde-code-review` | Reviews serde code for derive patterns, enum representations, custom impls, and format-specific serialization bugs |
| `rust-testing-code-review` | Reviews unit, integration, async, mock, and property-based tests including Rust 2024 testing changes |
| `ffi-code-review` | Reviews extern blocks, `#[repr(C)]` types, string handling, callbacks, and unsafe boundary correctness |
| `macros-code-review` | Reviews `macro_rules!` and procedural, derive, and attribute macros for hygiene, fragment misuse, and compile-time impact |
| `review-verification-protocol` | Reference: mandatory verification steps loaded before reporting any review findings to reduce false positives |

## See Also

- [Skill catalog](../../SKILLS.md) — every skill in the marketplace
- [beagle-core](../beagle-core/README.md) — shared workflows, verification, and git skills
- [beagle marketplace](https://github.com/existential-birds/beagle) — the full Agent Skills marketplace
