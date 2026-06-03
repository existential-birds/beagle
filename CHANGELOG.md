# Changelog

All notable changes to Beagle are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- **All plugins (commands → skills migration):** Unified all 28 former command workflows into the skills format across 144 total SKILL.md files, removing all `commands/` directories from the repository — skills are now the canonical source for all user-invocable workflows
- **beagle-core, beagle-docs, beagle-analysis:** Merged 4 commands into existing skills: `receive-feedback` (merged into `beagle-core:receive-feedback` skill), `review-ai-writing` (merged into `beagle-docs:review-ai-writing` skill), `humanize-beagle` (merged into `beagle-docs:humanize-beagle` skill), `llm-judge` (merged into `beagle-analysis:llm-judge` skill)
- **15 internal-only skills:** Marked as `user-invocable: false` to prevent unintended user triggering while preserving programmatic access

### Added
- **Codex support:** Added `.codex/INSTALL.md` installation guide and `docs/README.codex.md` reference for non-Claude agents

## [4.1.0] - 2026-05-31

### Changed
- **All active plugins (agent-agnostic skills):** Made every skill across the 10 active plugins (144 `SKILL.md` files) portable to non-Claude agents (Codex, opencode) and conformant to the [Agent Skills spec](https://agentskills.io/specification). Converted `<plugin>:<skill>` namespace tokens to relative `../<skill>/SKILL.md` links; replaced named harness tools (`Skill(skill:…)`, the Task/Skill/Edit/etc. tools, `AskUserQuestion`) and slash-command invocations with generic verbs; rewrote subagent fan-out in every review/orchestrator skill to a hedged-optional pattern ("if the agent supports subagents, dispatch in parallel; otherwise run sequentially with identical output"); neutralized "Claude Code"-as-agent and `CLAUDE.md` references; and made commit/PR attribution a generic optional footer. Removed wholly non-spec frontmatter keys (`autoContext`, `dependencies`, `triggers`) and split `agent-architecture-analysis` (558→130 lines) into `references/`. The Claude Code extensions `disable-model-invocation` and `user-invocable` are retained at top level as documented, accepted extensions (other agents ignore unknown keys). Added `scripts/check-portability.sh`, which gates all 493 skill `.md` files (entrypoints + references) against regressions ([#124](https://github.com/existential-birds/beagle/issues/124)).
- **beagle-analysis:write-plan**: after writing the plan, prompts "Do you want a prompt to execute this plan in a new session?" and, on yes, invokes `beagle-core:subagent-prompt` to generate the handoff prompt in-session instead of only instructing the user to run it manually.
- **beagle-analysis:write-plan**: skill is now model-invocable so it can auto-trigger when relevant, instead of being user-invocation-only ([#117](https://github.com/existential-birds/beagle/pull/117))

### Fixed
- **beagle-ai:** Add an anti-confabulation "gate 0" to the `beagle-ai` code-review skills so reviewers ground every finding in the actual diff before emitting it ([#127](https://github.com/existential-birds/beagle/pull/127))
- **all review skills:** Propagate anti-confabulation gate 0 to the remaining review skills across the marketplace, blocking confabulated findings consistently ([#126](https://github.com/existential-birds/beagle/pull/126))
- **beagle-core:** Harden the LLM-artifacts skills against confabulated findings ([#122](https://github.com/existential-birds/beagle/pull/122))

## [4.0.0] - 2026-05-27

### Added
- **beagle-core:** Add `review-skill` skill for automated skill PR review — validates structural validity, design quality, and marketplace consistency with reference checks for structure, design, and marketplace integration ([#111](https://github.com/existential-birds/beagle/pull/111))

### Changed
- **BREAKING:** Merged beagle-meta into beagle-core — `skill-builder` and `review-skill` now live under beagle-core
- **BREAKING:** Merged beagle-remix-v2 into beagle-react — all 12 Remix v2 skills now live under beagle-react
- **BREAKING:** Delisted beagle-ai from marketplace (deprecated; files preserved on disk but removed from marketplace.json)

### Removed
- `docling`, `github-projects`, `sqlite-vec` vendor skills from beagle-core
- beagle-meta plugin entry (merged into beagle-core)
- beagle-remix-v2 plugin entry (merged into beagle-react)
- beagle-ai plugin entry (delisted from marketplace)

## [3.11.0] - 2026-05-23

### Added
- **beagle-core:** Add the `review-structure` skill — a repo-wide structural-maintainability review (`/beagle-core:review-structure`) focused on implementation quality, abstraction quality, and codebase health ([#112](https://github.com/existential-birds/beagle/pull/112)). Pushes for "code-judo" restructurings that preserve behavior while simplifying, guards against pushing files past 1k lines, flags anti-spaghetti branching, enforces canonical-layer reuse, calls out magic/wrapper abstractions, and demands explicit type/boundary contracts. Ships `disable-model-invocation` (user-invoked only) with a severity-categorized output format and an explicit approval bar

## [3.10.0] - 2026-05-16

### Added
- **beagle-analysis:** Add spec/plan discipline for tool-behavior assumptions ([#109](https://github.com/existential-birds/beagle/pull/109)). `brainstorm-beagle` Key Decisions resting on tool behavior must cite a worked example or be tagged `needs-spike-before-planning`. `write-plan` gains Spike Before Plan-Lock (Task 0 spikes for unverified toolchain claims; failing spikes revise the spec rather than papering over with plan tasks), Parallel-Implementation Gate (final task asserts byte-identical observable behavior between implementations), failure-propagation policy banning `.unwrap_or(<plausible fallback>)` and silent `.ok()` in fallible contracts, Pattern Application Audit task after multi-site conversions (zero-remaining grep + production-config divergence enumeration + 3-site sample-verify), Step 4 broadened to run both the new test AND the relevant suite with copy-pasteable commands, and six new Final Review checklist rows
- **beagle-core:** `fetch-pr-feedback` skips resolved review threads by default ([#106](https://github.com/existential-birds/beagle/pull/106)). Fetches resolved review-thread comment databaseIds via GraphQL and excludes them from review-comments output. Adds `--include-resolved` opt-in flag mirroring `--include-author`. Issue comments are unaffected since they're not part of review threads

### Changed
- **beagle-core:** `receive-feedback` orchestrator may no longer defer valid findings or edit code itself ([#108](https://github.com/existential-birds/beagle/pull/108)). The skill previously asked users which items to fix and used "pre-existing", "out of scope", and "deferred" as escape hatches for valid reviewer findings. Workflow now: orchestrator verifies, asks a single "launch fixes for N,N,N?" confirmation, then spawns one subagent per valid item in parallel. User may reply with a subset of numbers to dispatch only those; excluded items are labeled "Not run this round (user-excluded)" — never deferred. Adds a fix-quality contract pasted verbatim into every subagent prompt (idiomatic clean fixes, no over-engineering, no excessive comments)

## [3.9.1] - 2026-05-15

### Added
- **beagle-rust:** Expand `ffi-code-review/references/safety-patterns.md` (+96 lines, 12 review checks) with calling-convention semantics (`extern "C"` vs `extern "system"` vs `extern "Rust"` vs `extern "C-unwind"`), allocator-ownership rule (whoever allocates also frees — `Box::from_raw` only on Rust-allocated pointers, `libc::free` only on C-allocated), callback marshaling via `extern "C" fn` trampoline + `Box::into_raw(Box::new(closure))` user_data + `catch_unwind`, symbol naming hygiene (`#[unsafe(no_mangle)]` in edition 2024), and the `-sys` crate split convention — distilled from *Rust for Rustaceans* Ch 11
- **beagle-rust:** Add Quick Reference row for "Wild Patterns" and "Destructors and Cleanup" + "Async APIs" sections to `rust-best-practices/SKILL.md` — surfaces the new dev-side content (drop guards, extension traits, index pointers, crate preludes, explicit `close()`/`shutdown()` pattern, cancel-safety documentation, runtime-agnostic library design) directly in the SKILL discovery surface, not only in references

### Fixed
- **beagle-core:** Tighten `gen-release-notes` Step 6 from a soft "verify" sentence into a **hard gate** with runnable shell commands that extract `NEW_VERSION` and `PREV_VERSION` from the staged `CHANGELOG.md`, then `grep -qE` for the exact `[NEW]: ...compare/vPREV...vNEW` footer line AND the advanced `[Unreleased]: ...compare/vNEW...HEAD` line. Exits with a named error on failure. Previously, the verification was prose-only and the 3.8.0 release shipped without its `[3.8.0]` footer compare link
- **release command:** Rewrite Step 3.5 of `.claude/commands/release.md` from soft "verify" prose into a hard gate that re-runs the same `gen-release-notes` Step 6 checks. Defense in depth — release flow now blocks at PR creation if footer compare links are missing

## [3.9.0] - 2026-05-15

### Added
- **beagle-rust:** Add `references/interface-design.md` to `rust-code-review` (351 lines, 64 review checks) — object safety mechanics (5 rules + `where Self: Sized` escape hatch), ergonomic blanket impls for `&T`/`&mut T`/`Box<T>`/`IntoIterator` for `&Self`, wrapper-type Deref discipline and the Deref-as-OOP anti-pattern, borrowed vs owned argument design with `Cow` discipline, fallible/blocking destructors with the explicit `close()`/`shutdown()` pattern and three Drop workarounds (`Option` newtype, per-field `mem::take`, `ManuallyDrop`), naming-convention review checks (`as_`/`to_`/`into_`/`try_` cost taxonomy), standard derive priority with the `Copy` caveat, and hidden contracts (re-exports, auto-trait propagation through `-> impl Trait`, the `fn is_normal<T: Sized + Send + Sync + Unpin>()` compile-time test pattern), distilled from *Rust for Rustaceans* Ch 3
- **beagle-rust:** Add `references/patterns-in-the-wild.md` to `rust-code-review` (192 lines, 26 review checks) — index pointers with generational keys (`slotmap`, `petgraph`) and the `Vec::swap_remove` invalidation hazard, drop guards with the `let _guard` vs `let _ = ...` immediate-drop trap and the `panic = "abort"` caveat, extension traits with the blanket-impl recipe (`trait Ext; impl<T: Bound> Ext for T`) and shadowing pitfalls, crate preludes with RFC 1105 SemVer rules, distilled from *Rust for Rustaceans* Ch 13
- **beagle-rust:** Add `references/concurrency-models.md` to `rust-code-review` (131 lines, 16 review checks) — shared-memory vs worker-pool vs actor model selection with hazards for each, async vs threads vs hybrid decision tree, data race (UB) vs race condition (logic bug) distinction, CAS-as-hardware-mutex with O(N²) contention cost, the `println!` heisenbug from `Stdout`'s `Mutex`, distilled from *Rust for Rustaceans* Ch 10
- **beagle-rust:** Expand `rust-code-review/references/error-handling.md` (+133 lines, 12 review checks) — opaque vs enumerated error tradeoffs with `Box<dyn Error + Send + Sync + 'static>` discipline, the custom error trait set (`Error + Display + Debug + Send + Sync + 'static`) and per-bound rationale, special error cases (`Result<T, ()>` antipattern, `std::thread::Result` as `Box<dyn Any>`, `!`/`Infallible`, hot-path boxing cost), `?` desugars to `From::from` not `Into`, the deferred-cleanup-with-`?` bug with RAII/`try`/explicit-match fixes, `#[error(transparent)]` semantics, distilled from *Rust for Rustaceans* Ch 4
- **beagle-rust:** Expand `rust-code-review/references/types-layout.md` (+118 lines, 13 review checks) — concrete padding numbers (`{bool, u32, u8, u64, u16}` 32 bytes `repr(C)` vs 16 bytes `repr(Rust)`), `repr(packed)` reference-to-field UB and `addr_of!`/`read_unaligned` fix, `repr(align(64))` for cache-line padding (128 on Apple Silicon), wide-pointer layout (2 × `usize`, slice vs vtable), `Sized`/`?Sized` discipline, auto-trait leakage through `-> impl Trait`, derive-bound trap with `Arc<T>`/`Rc<T>`/`Box<T>`, edition 2024 RPIT capture, distilled from *Rust for Rustaceans* Ch 1–2
- **beagle-rust:** Expand `rust-code-review/references/unsafe-deep.md` (+167 lines, 18 review checks) — validity vs safety distinction (Jon's keystone: validity is byte-level language-fixed, safety is author-defined invariants), two meanings of `unsafe` (declaring vs using), drop check with `#[may_dangle]` and `PhantomData<T>`, pointer provenance and strict-provenance APIs (`addr`/`with_addr`/`expose_addr`/`from_exposed_addr`), panic safety in unsafe code (partial init + drop, `set_len`-before-init, double-drop via `ptr::read`, `catch_unwind` at FFI boundaries), casting pitfalls (`as` lossy semantics, `transmute` validity requirements, `from_raw_parts` provenance), distilled from *Rust for Rustaceans* Ch 9
- **beagle-rust:** Expand `rust-code-review/references/async-concurrency.md` (+119 lines, 17 review checks) — the poll contract (register Waker BEFORE checking readiness or sleep forever), `Pin` wraps a pointer not a value with safety surface extending to `Deref`/`DerefMut`/`Drop` of the wrapping pointer, `Box::pin` vs `std::pin::pin!` macro tradeoffs, structural vs non-structural pinning with `PhantomPinned` and `pin-project-lite`, cancellation soundness (drop = cancel, cancel-safe taxonomy, `read_exact`/`write_all` data loss on cancel, defensive `spawn`+`JoinHandle` for non-cancellable work), `Send` propagation through `.await` and the `std::sync::MutexGuard` non-`Send` trap, cross-runtime compatibility (no internal spawn in libraries), distilled from *Rust for Rustaceans* Ch 8
- **beagle-rust:** Expand `rust-best-practices/references/api-design.md` (+135 lines, dev-side) — hidden contracts (re-exported foreign types, auto-trait propagation, `is_normal` compile-time test), object safety mechanics with the `where Self: Sized` escape hatch, wrapper types and `Deref` discipline (when right, when wrong), fallible/blocking destructors with explicit `close()`/`shutdown()` pattern and `ManuallyDrop`/`Option`-newtype workarounds, ergonomic blanket impls (eagerly add `impl<T: MyTrait + ?Sized> MyTrait for &T`/`&mut T`/`Box<T>`), standard derive priority with Jon's ordered list and explicit `Copy` caveat, distilled from *Rust for Rustaceans* Ch 3
- **beagle-rust:** Expand `rust-best-practices/references/coding-idioms.md` (+121 lines, dev-side) — drop guards with the `let _guard = ...` vs `let _ = ...` immediate-drop contrast, extension trait recipe with blanket-impl pattern (real examples: `itertools::Itertools`, `futures::TryStreamExt`, `tower::ServiceExt`), index pointers via `slotmap`/`petgraph` with generational-key discipline, crate prelude curation with RFC 1105 SemVer note, distilled from *Rust for Rustaceans* Ch 13
- **beagle-rust:** Expand `rust-best-practices/references/performance.md` (+133 lines, dev-side) — monomorphization budgets with the type-independent inner-function pattern, cache-line alignment to avoid false sharing (`#[repr(align(64))]` or `crossbeam::utils::CachePadded`, `align(128)` on Apple Silicon), criterion benchmark discipline (statistical confidence, `--save-baseline main` for CI regression detection, `black_box(input.as_ptr())` for pointer inputs, `iter_batched` for per-iteration setup, `--profile bench`, I/O isolation), compile-time as a perf concern at workspace scale (`[profile.dev.package.X]` overrides for slow proc-macro deps, `cargo-bloat`/`cargo-llvm-lines`/`cargo-show-asm`, `-Zthreads=8`), distilled from *Rust for Rustaceans* Ch 2 and Ch 6
- **beagle-rust:** Expand `rust-project-setup/references/features-conditional.md` (+91 lines, 12 review checks) — additive-features-only rule with the unification trap, optional dependencies as features with `dep:` syntax (Cargo 1.60+), workspace-vs-published-version type-identity gotcha with two-mode CI strategy, MSRV discipline (minor-bump policy, `cargo +nightly update -Z minimal-versions` workflow), `[target.cfg(feature = ...)]` is silently ignored hygiene rule, distilled from *Rust for Rustaceans* Ch 5
- **beagle-rust:** Expand `rust-project-setup/references/workspace-layout.md` (+81 lines, 8 review checks) — `[profile.release]` tuning with concrete tradeoffs (`lto = "thin"`/`"fat"`, `codegen-units = 1`, `panic = "abort"` audit requirement, `strip = "symbols"`), `[profile.dev.package."<slow-dep>"]` opt-level override for proc-macro deps, workspace compile-time budgets at scale (`sccache`/`cargo-nextest`/member partitioning), full `[package]` metadata completeness list for crates.io publication, distilled from *Rust for Rustaceans* Ch 5
- **beagle-rust:** Expand `rust-testing-code-review/references/advanced-testing.md` (+163 lines, 23 review checks) — test-augmentation taxonomy distinguishing stub/fake/mock/spy with the trait-as-seam pattern, test-generation strategies (`rstest` matrix, `paste!` macro, `build.rs`-generated tests), criterion specifics (statistical confidence, baseline persistence for CI regression detection, `black_box` with `as_ptr()` for pointer inputs, `iter_batched` for per-iteration setup, `--profile bench`, I/O isolation), trybuild UI tests with `.stderr` rustc-version stability strategy, clippy lint-group strategy (correctness deny / suspicious warn / pedantic warn-with-justified-`#[expect]` / nursery off / restriction opt-in), distilled from *Rust for Rustaceans* Ch 6
- **beagle-rust:** Expand `macros-code-review/references/declarative-macros.md` (+74 lines, 9 review checks) — hygiene boundaries (variables hygienic, types/modules/functions shared), `$crate` and absolute `::core::`/`::alloc::` paths for `no_std`-friendly macros, TT-muncher pattern with recursion-limit hazards, fragment-matcher follow restrictions (`expr` cannot be followed by `<`, etc.), Jon's decl-vs-proc decision tree (`const fn` → generics → decl → proc), distilled from *Rust for Rustaceans* Ch 7
- **beagle-rust:** Expand `macros-code-review/references/procedural-macros.md` (+78 lines, 10 review checks) — span hygiene (`Span::call_site` vs `Span::def_site` vs `Span::mixed_site` — `mixed_site` is the default for introduced helpers), error reporting via `syn::Error::new_spanned`/`combine`/`to_compile_error` (never `panic!`), `parse_quote!` vs `quote!` for AST-vs-token-stream results, `syn` feature audit (compile-time cost of `features = ["full"]` vs `["derive"]`), trybuild `.stderr` rustc-version sensitivity, `proc_macro2` re-export rule for downstream compatibility, distilled from *Rust for Rustaceans* Ch 7
- **beagle-rust:** Wire new references into `rust-code-review/SKILL.md` (3 new Quick Reference rows, 4 new checklist sections — Interface Design, Patterns in the Wild, Concurrency Design, plus expanded Error/Layout/Async/Unsafe checks), `rust-testing-code-review/SKILL.md` (5 new checklist sections — Test Augmentation, Performance Tests, Test Generation, trybuild UI Tests, Clippy Lint Groups), `macros-code-review/SKILL.md` (expanded Quick Reference and proc-macro span/error checklist), `rust-best-practices/SKILL.md` (hidden-contracts + drop-guards + extension-traits + criterion summary lines), and `review-rust/SKILL.md` (6 new detection commands and 5 new conditional-skill routing rows)

## [3.8.0] - 2026-05-15

### Added
- **beagle-rust:** Add `references/memory-ordering.md` to `rust-code-review` — Mara Bos's decision tree for `Relaxed`/`Acquire`/`Release`/`AcqRel`/`SeqCst`, fences, the `compare_exchange` success/failure ordering pair, `compare_exchange_weak` vs strong CAS, ABA, out-of-thin-air, ARM-vs-x86 hazards, with 33 `[FILE:LINE] ISSUE_TITLE` review checks distilled from *Rust Atomics and Locks* Ch 3
- **beagle-rust:** Add `references/lock-free-patterns.md` to `rust-code-review` — when to hand-roll vs use std/`crossbeam`/`arc-swap`/`parking_lot`, spinlocks with `spin_loop` and backoff, hand-rolled channels (Drop/panic safety, `MaybeUninit`, park/unpark races), hand-rolled `Arc`/`Weak` (clone-`Relaxed` / drop-`Release` / `fence(Acquire)` on last decrement, two-counter Weak layout), CAS loops with `fetch_update`, seqlock, three-state futex mutex, condvar counter-before-unlock and spurious-wakeup loops, with 34 review checks distilled from *Rust Atomics and Locks* Ch 4–9
- **beagle-rust:** Add `references/concurrency-testing.md` to `rust-testing-code-review` — `loom` setup (the `#[cfg(loom)]` import shim, `RUSTFLAGS="--cfg loom"`, `LOOM_MAX_PREEMPTIONS`), `cargo +nightly miri test` with `MIRIFLAGS` for strict provenance, tree borrows, and many-seeds, the loom+miri pairing, complementary tools (`shuttle`, ThreadSanitizer, `kani`), CI matrix, and patterns that should always have a concurrency test, with 24 review checks
- **beagle-rust:** Expand `rust-code-review/references/concurrency-primitives.md` with `UnsafeCell` invariants, `MaybeUninit` atomic-init patterns, `Mutex`/`RwLock` poisoning + `clear_poison` (1.77) including the `LazyLock` poisoning asymmetry, Send/Sync deep cuts (`MutexGuard`, `Rc` vs `Arc`, `unsafe impl` bounds, `PhantomData<*const ()>` opt-outs), ABA and out-of-thin-air clarifications, and an Atomic Types Survey covering `target_has_atomic` gating and `fetch_update`
- **beagle-rust:** Expand `tokio-async-code-review/references/sync-primitives.md` with the std-vs-`tokio`-vs-`parking_lot` decision matrix, the `std::sync::Mutex` held across `.await` footgun (with the `drop(guard)` workaround), `tokio::sync::RwLock` write-preferring/starvation, "atomics beat locks" rule for single-value state, `tokio::sync::Notify` lost-wakeup hazards, `tokio::sync::Semaphore` for back-pressure, and `OnceCell`/`OnceLock`/`LazyLock` selection
- **beagle-rust:** Expand `ffi-code-review/references/safety-patterns.md` with atomics and shared state across FFI — Rust `AtomicXxx` vs C `_Atomic` ABI compatibility, raw-pointer `Send`/`Sync` boundary patterns, `UnsafeCell` requirements for shared-mutation interfaces, Rust thread vs C-spawned thread differences (`thread_local!` destructors, `park`/`unpark`)
- **beagle-rust:** Wire the new references into `rust-code-review/SKILL.md`, `rust-testing-code-review/SKILL.md`, and `review-rust/SKILL.md` (Quick Reference table, When to Load References, Review Checklist concurrency subsection, severity calibration for memory-ordering data races, and tech-detection routing for `std::sync::atomic`, `loom`/`miri`, `crossbeam`, `arc-swap`, `parking_lot`)

## [3.7.0] - 2026-05-15

### Added
- **beagle-core:** Add `subagent-prompt` skill — produces a self-contained orchestration prompt that hands the current session's work off to a fresh session for sub-agent execution, with explicit per-task verification commands and a final integration check before reporting success. User-invocable, `disable-model-invocation: true` ([#104](https://github.com/existential-birds/beagle/pull/104))
- **beagle-analysis:** Add `write-plan` skill — turns a finalized `brainstorm-beagle` spec at `.beagle/concepts/<slug>/spec.md` into a bite-sized, TDD-driven implementation plan at `.beagle/concepts/<slug>/plan.md`. Reads the spec, scans `CLAUDE.md` conventions, designs file structure, decomposes work into 2-5 minute steps with exact paths/commands, self-reviews against the spec, gets user approval, then writes. References `references/plan-template.md` and `references/plan-reviewer.md` for the document skeleton and the optional reviewer-subagent prompt ([#104](https://github.com/existential-birds/beagle/pull/104))

### Fixed
- **beagle-react:** `review-frontend` now routes to `review-remix-v2` when Remix v2 is detected, ensuring Remix projects get the dedicated review skill instead of generic React review ([#104](https://github.com/existential-birds/beagle/pull/104))

## [3.6.0] - 2026-05-15

### Added
- **beagle-remix-v2:** New plugin (v0.1.0) with 12 skills covering Remix v2 code review and best practices — `review-remix-v2` orchestrator plus paired build/review skills for routing, data flow (loaders/actions/defer/revalidation), forms (Form/fetcher/optimistic UI/uploads), meta + sessions (meta v2, links, sessions, auth/CSRF), error boundaries (root + nested, throw Response, v1 holdovers), and performance/SSR (hydration, headers/caching, prefetch/streaming, server-client split) ([#102](https://github.com/existential-birds/beagle/pull/102))

## [3.5.0] - 2026-05-03

### Added
- **beagle-analysis:** Extend `strategy-review` judge artifact schema to v1.1 — adds optional `strengths`, `recommended_next_steps`, `review_id`, and `notes_cross_reference` fields. Backward compatible: `schema_version` stays `"1.0"` ([#86](https://github.com/existential-birds/beagle/issues/86))
- **beagle-analysis:** Add two `strategy-review` pressure-test scenarios — happy-path (all Strong) and durable-state + judge-mode interaction ([#86](https://github.com/existential-birds/beagle/issues/86))

## [3.4.0] - 2026-05-02

### Added
- **beagle-core:** Add `verify-llm-artifacts` skill — second-pass adjudication of `review-llm-artifacts` JSON that classifies each finding as confirmed, false positive, or inconclusive before deletes happen, and carries the original `fix_action` field through to `fix-llm-artifacts` unchanged. Includes a verification checklist with mechanical detection rules (e.g. monorepo trigger fires when `[workspace]`, `workspaces`, `pnpm-workspace.yaml`, `lerna.json`, or `turbo.json` is present) instead of judgment-call prose ([#98](https://github.com/existential-birds/beagle/pull/98))
- **beagle-core:** Add `--all` flag to `review-llm-artifacts` for opt-in full-project scans; default remains files changed since merge-base with `main` ([#98](https://github.com/existential-birds/beagle/pull/98))
- **beagle-core:** Extend `review-llm-artifacts` JSON schema with `scope` and `target` fields so downstream skills can reproduce the original invocation ([#98](https://github.com/existential-birds/beagle/pull/98))

### Changed
- **all plugins:** Roll out rule→gate sequencing across every `SKILL.md` in the marketplace (130+ files). Soft rules become sequenced Gates with objective pass conditions backed by evidence on disk or in tool output, and each gate blocks the next step until its condition is met. Background: <https://blog.fsck.com/2026/04/07/rules-and-gates/> ([#98](https://github.com/existential-birds/beagle/pull/98))
- **beagle-core:** `fix-llm-artifacts` now reads `scope` and `target` from the stale review JSON and re-invokes `review-llm-artifacts` with the original arguments (preserving `--all` or narrowed paths) instead of falling back to the default scope. Pre-schema review JSON without those fields falls back to a full-project re-run with a cancellable warning ([#98](https://github.com/existential-birds/beagle/pull/98))
- **beagle-core:** `review-llm-artifacts` full scan replaces `find ! -path` filters with `-type d ... -prune` so `node_modules`, `.git`, `target`, `build`, etc. are never descended into — prevents minutes-long hangs on large repos ([#98](https://github.com/existential-birds/beagle/pull/98))

### Fixed
- **beagle-core:** `fetch-pr-feedback` no longer drops sections after the first `---` separator. The `clean_body` jq filter previously stripped everything from `\n---\n` to EOF to remove bot footer boilerplate, silently dropping real findings from claude[bot] and human reviewers who use `---` as a section separator. Replaced with a marker-guarded version that only removes a trailing `---` block when it begins with a known bot-footer signature ([#98](https://github.com/existential-birds/beagle/pull/98))
- **beagle-core:** `review-llm-artifacts --since-main` resolves `main`/`origin/main`/`master`/`origin/master` explicitly and exits non-zero when none exist, instead of wrapping `git merge-base` in `|| true` and silently reporting "no files to scan" in repos without a local main ([#98](https://github.com/existential-birds/beagle/pull/98))
- **beagle-testing:** `gen-test-plan` Gate 3 swaps `grep -E` alternation (passed if any one key matched) for a python YAML parse plus explicit four-key presence check, so plans missing `metadata`, `setup`, or `tests` can no longer slip through. Also parameterizes `BASE_BRANCH` so Gate 1 evidence matches commands for non-main bases ([#98](https://github.com/existential-birds/beagle/pull/98))
- **beagle-testing:** `run-test-plan` Step 1 parameterizes `PLAN_PATH` so `--plan` works before Step 3's gate runs ([#98](https://github.com/existential-birds/beagle/pull/98))
- **beagle-docs:** `improve-doc` Gate replaces spot-check with full block equality so mid-section edits in `skip` sections cannot pass unnoticed ([#98](https://github.com/existential-birds/beagle/pull/98))
- **beagle-elixir, beagle-ios, beagle-python, beagle-go:** Require canonical `[FILE:LINE] ISSUE_TITLE` header on review evidence gates (`elixir-docs-review`, `swiftdata-code-review`, `swiftui-code-review`, `python-code-review`, `wish-ssh-code-review`); symbols and snippets supplement but cannot replace the anchor ([#98](https://github.com/existential-birds/beagle/pull/98))
- **beagle-ai:** `deepagents-code-review` SKILL.md trimmed back under the 500-line cap (509 → 476) by extracting the Code Review Checklist to `references/checklist.md` ([#98](https://github.com/existential-birds/beagle/pull/98))
- **beagle-rust:** `ffi-code-review` resolves an "at minimum Gate 4" / "in order" contradiction by requiring Gates 1–4 in order ([#98](https://github.com/existential-birds/beagle/pull/98))

## [3.3.0] - 2026-04-18

### Added
- **beagle-analysis:** Add `web-research` skill — reusable research primitive that turns a sharp research question into a written plan, parallel-subagent findings, and a cited synthesis report (`TL;DR` / `Findings` / `Gaps & Limitations` / `Sources`) on disk. Dual-mode: directly invocable by users and programmatically invocable by companion skills (`prfaq-beagle`, `brainstorm-beagle`, `strategy-interview`) via a documented contract ([#96](https://github.com/existential-birds/beagle/pull/96))
- **beagle-analysis:** Add `artifact-analysis` skill — sibling primitive to `web-research` that scans local documents and project knowledge (auto-discovering `.beagle/concepts/`, `.planning/`, `docs/`, and root README/brief files by default) via parallel subagents and produces a path-cited synthesis report with fixed sections (`Documents Found` / `Key Insights` / `User / Market Context` / `Technical Context` / `Ideas & Decisions` / `Raw Detail Worth Preserving` / `Gaps & Limitations`). Dual-mode with the same companion contract used by `prfaq-beagle`, `brainstorm-beagle`, and `strategy-interview` ([#96](https://github.com/existential-birds/beagle/pull/96))
- **beagle-analysis:** Add `prfaq-beagle` skill — hardcore Working Backwards PRFAQ coach that runs a 5-stage gauntlet (Ignition → Press Release → Customer FAQ → Internal FAQ → Verdict) to filter weak product, internal-tool, or OSS concepts before they consume `brainstorm-beagle` cycles. Detects concept type in Ignition and calibrates later stages; invokes `web-research` and `artifact-analysis` serially for grounding with graceful degradation on `web-tools-unavailable` and resume-by-default on `prior-run-present`. Binary pass/fail verdict — on pass, produces a concept brief at `.beagle/concepts/<slug>/brief.md` that `brainstorm-beagle` auto-ingests; on fail, produces targeted feedback naming exactly what stage to re-enter and what would need to be true ([#96](https://github.com/existential-birds/beagle/pull/96))

### Changed
- **beagle-analysis:** Update `brainstorm-beagle` — relocate spec output from `docs/specs/YYYY-MM-DD-<topic>.md` to `.beagle/concepts/<slug>/spec.md`; auto-detect `brief.md` at startup and ingest it to skip most discovery; when invoking `web-research` or `artifact-analysis` mid-session, land their outputs under the shared `.beagle/concepts/<slug>/research/` and `.beagle/concepts/<slug>/analysis/` folders so the whole concept-forging audit trail lives in one place ([#96](https://github.com/existential-birds/beagle/pull/96))

## [3.2.0] - 2026-04-18

### Added
- **beagle-analysis:** Add `resolve-beagle` skill — follow-up to `brainstorm-beagle` that orchestrates parallel research subagents (with sequential inline fallback) to close Open Questions and latent gaps in a spec, presents proposals one at a time for approval, and rewrites the spec in place ([#94](https://github.com/existential-birds/beagle/pull/94))

### Fixed
- **beagle-core:** Make `gen-release-notes` Step 5 explicit about updating `[Unreleased]` and inserting the new `[VERSION]` footer compare links, with an example diff and a verification grep — prevents the recurring CodeRabbit feedback that release PRs were missing footer reference links ([#95](https://github.com/existential-birds/beagle/pull/95))
- **release command:** Add Step 3.5 verification gate that fails the release flow if CHANGELOG footer compare links for the new version are missing ([#95](https://github.com/existential-birds/beagle/pull/95))

## [3.1.0] - 2026-04-11

### Added
- **beagle-rust:** Add `macros-code-review` skill for macro_rules!, proc macros, hygiene, fragment specifiers, and span handling ([#92](https://github.com/existential-birds/beagle/pull/92))
- **beagle-rust:** Add `ffi-code-review` skill for extern "C", repr(C), CStr/CString, callbacks, and bindgen patterns ([#92](https://github.com/existential-birds/beagle/pull/92))
- **beagle-rust:** Add 10 new reference files across existing skills: lifetime-variance, types-layout, unsafe-deep, concurrency-primitives, api-design, ecosystem-patterns, advanced-testing, features-conditional, no-std, pinning-cancellation ([#92](https://github.com/existential-birds/beagle/pull/92))

### Changed
- **beagle-rust:** Update all skills for Rust 2024 edition — RPIT lifetime capture, unsafe_op_in_unsafe_fn, async fn in traits, LazyCell/LazyLock, resolver v3 ([#92](https://github.com/existential-birds/beagle/pull/92))
- **beagle-rust:** Update `review-rust` orchestrator to detect and route macros/FFI to new skills ([#92](https://github.com/existential-birds/beagle/pull/92))
- **beagle-rust:** Expand verification protocol with macro, FFI, and concurrency false positive rules ([#92](https://github.com/existential-birds/beagle/pull/92))

## [3.0.0] - 2026-04-11

### Removed
- **beagle-analysis:** Remove deprecated `12-factor-apps` and `12-factor-apps-analysis` skills, superseded by `agent-architecture-analysis` ([#90](https://github.com/existential-birds/beagle/pull/90))

### Changed
- **BREAKING:** Rename `brainstorm` skill to `brainstorm-beagle` to resolve ClawHub slug conflict ([#90](https://github.com/existential-birds/beagle/pull/90))
- **BREAKING:** Rename `humanize` skill to `humanize-beagle` to resolve ClawHub slug conflict ([#90](https://github.com/existential-birds/beagle/pull/90))
- **beagle-analysis:** Optimize skill descriptions for improved triggering accuracy ([#90](https://github.com/existential-birds/beagle/pull/90))

### Fixed
- **beagle-analysis:** Remove stale reference to deleted `12-factor-apps` skill in `agent-architecture-analysis` description ([#90](https://github.com/existential-birds/beagle/pull/90))

## [2.12.1] - 2026-04-10

### Changed
- **beagle-analysis:** Improve strategy skill discoverability with expanded marketplace tags and refined trigger phrases ([#88](https://github.com/existential-birds/beagle/pull/88))

## [2.12.0] - 2026-04-10

### Added
- **beagle-analysis:** Add `strategy-interview` skill for structured strategy interviews using kernel framework with landscape mapping, choice cascade, and value innovation lenses ([#85](https://github.com/existential-birds/beagle/pull/85))
- **beagle-analysis:** Add `strategy-review` skill to pressure-test strategy documents for kernel integrity, bad-strategy patterns, coherence gaps, and untested assumptions ([#85](https://github.com/existential-birds/beagle/pull/85))

### Changed
- **beagle-docs:** Refactor `humanize` skill to use `references/` directory for vocabulary swaps, fix strategies, and developer voice guidelines ([#85](https://github.com/existential-birds/beagle/pull/85))
- **beagle-docs:** Add 10 new humanize fix categories: em dash overuse, thematic breaks, title case headings, curly quotes, negative parallelism, challenges-and-prospects formula, rule of three, inline-header lists, unnecessary tables, regression to mean ([#85](https://github.com/existential-birds/beagle/pull/85))
- Remove deprecated `beagle` plugin entry from marketplace manifest ([#85](https://github.com/existential-birds/beagle/pull/85))

## [2.11.0] - 2026-04-04

### Added
- **beagle-rust:** Add `rust-best-practices` skill for idiomatic Rust patterns, ownership guidelines, and error handling conventions ([#83](https://github.com/existential-birds/beagle/pull/83))
- **beagle-rust:** Add `rust-project-setup` skill for project scaffolding, Cargo workspace configuration, and toolchain setup ([#83](https://github.com/existential-birds/beagle/pull/83))

## [2.10.1] - 2026-04-04

### Fixed
- **beagle-core:** Allow `receive-feedback` skill to be invoked by other skills ([#81](https://github.com/existential-birds/beagle/pull/81))

## [2.10.0] - 2026-04-03

### Added
- **beagle-testing:** Enforce E2E-only test plans — prohibit wrapping automated test suites (cargo test, pytest, npm test) and require real user-facing actions ([#79](https://github.com/existential-birds/beagle/pull/79))
- **beagle-testing:** Add Rust and Elixir stack detection, CLI/database test templates, and structured setup format ([#79](https://github.com/existential-birds/beagle/pull/79))

### Changed
- **beagle-testing:** `run-test-plan` updated to handle both new and legacy setup formats ([#79](https://github.com/existential-birds/beagle/pull/79))

## [2.9.0] - 2026-03-30

### Added
- **codex:** Add OpenAI Codex support with install guide and skill linking instructions ([#77](https://github.com/existential-birds/beagle/pull/77))
- **codex:** Add `AGENTS.md` for Codex agent discovery ([#77](https://github.com/existential-birds/beagle/pull/77))

### Changed
- Unify all command workflows into skills format across all plugins, making skills the canonical format ([#77](https://github.com/existential-birds/beagle/pull/77))

## [2.8.0] - 2026-03-27

### Added
- **beagle-analysis:** Brainstorm skill for idea-to-spec workflow with structured spec generation and review ([#74](https://github.com/existential-birds/beagle/pull/74))

### Fixed
- **beagle-core:** Fix suggestion-block stripping order in `fetch-pr-feedback` — suggestion markers are now removed before blanket HTML comment removal ([#74](https://github.com/existential-birds/beagle/pull/74))

## [2.7.1] - 2026-03-21

### Fixed
- **beagle-core:** Preserve substantive details blocks in `fetch-pr-feedback` command ([#72](https://github.com/existential-birds/beagle/pull/72))

### Changed
- Update beagle-ios skill count in README (12 → 15) ([#71](https://github.com/existential-birds/beagle/pull/71))

## [2.7.0] - 2026-03-21

### Added
- **beagle-ios:** iOS animation skills for design, implementation, and code review ([#69](https://github.com/existential-birds/beagle/pull/69))
  - Skills: `ios-animation-design` (motion patterns, timing guidelines), `ios-animation-implementation` (SwiftUI animations, Core Animation, gesture animations, transitions), `ios-animation-code-review` (performance, accessibility, SwiftUI animation patterns, transitions)
  - Updated `review-ios` command with animation tech detection

## [2.6.0] - 2026-03-13

### Added
- **beagle-rust:** New plugin with Rust code review skills covering ownership, lifetimes, error handling, async/tokio, serde, sqlx, and axum patterns ([#67](https://github.com/existential-birds/beagle/pull/67))
  - Skills: `rust-code-review`, `tokio-async-code-review`, `axum-code-review`, `serde-code-review`, `sqlx-code-review`, `rust-testing-code-review`, `review-verification-protocol`
  - Command: `review-rust` with automatic tech detection for tokio, axum, serde, and sqlx

## [2.5.0] - 2026-03-13

### Changed
- **beagle-go:** Improved `go-code-review` skill with enhanced guidance for common mistakes, concurrency patterns, error handling, and interface design ([#65](https://github.com/existential-birds/beagle/pull/65))

## [2.4.0] - 2026-02-12

### Added
- **beagle-docs:** `review-ai-writing` skill and command — detect AI-generated writing patterns in docs, docstrings, commits, PR descriptions, and code comments using parallel subagents. Includes 6 reference files covering content, vocabulary, formatting, communication, filler, and code docs patterns ([#63](https://github.com/existential-birds/beagle/pull/63))
- **beagle-docs:** `humanize` skill and command — apply fixes from a prior `review-ai-writing` run to humanize AI-generated developer text with safe/risky classification and developer voice guidelines ([#63](https://github.com/existential-birds/beagle/pull/63))

## [2.3.1] - 2026-02-11

### Fixed
- **beagle-core:** `fetch-pr-feedback` and `respond-pr-feedback` commands use file-based jq filters to avoid shell escaping issues with `!=`, regex patterns, `<`, `>` operators ([#61](https://github.com/existential-birds/beagle/pull/61))
- **beagle-testing:** `gen-test-plan` now prioritizes core functionality tests over config-only coverage — previously a new feature could generate 6 settings page tests but zero tests exercising the actual feature ([#61](https://github.com/existential-birds/beagle/pull/61))

## [2.3.0] - 2026-02-10

### Added
- **reviews:** Review Convergence rules added to all 6 review commands (`review-python`, `review-go`, `review-tui`, `review-elixir`, `review-ios`, `review-frontend`) — ensures reviews complete in 1-2 iterations instead of 5+ with single-pass completeness, scope rules, fix complexity budget, and iteration policy ([#59](https://github.com/existential-birds/beagle/pull/59))
- **reviews:** Informational severity category added to all 6 verification protocols — observations that don't require changes are now captured separately from actionable issues ([#59](https://github.com/existential-birds/beagle/pull/59))

### Changed
- **reviews:** Verdict criteria updated to only block on Critical/Major issues; Minor issues no longer block approval ([#59](https://github.com/existential-birds/beagle/pull/59))

## [2.2.0] - 2026-02-07

### Added
- **beagle-elixir:** `elixir-writing-docs` skill — Elixir documentation authoring patterns for `@moduledoc`, `@doc`, doctests, admonitions, and cross-references ([#57](https://github.com/existential-birds/beagle/pull/57))
- **beagle-elixir:** `exdoc-config` skill — ExDoc configuration for mix.exs, cheatsheets, livebooks, extras, and advanced formatting ([#57](https://github.com/existential-birds/beagle/pull/57))
- **beagle-elixir:** `elixir-docs-review` skill — review Elixir documentation for quality, spec coverage, and completeness ([#57](https://github.com/existential-birds/beagle/pull/57))

## [2.1.1] - 2026-02-07

### Fixed
- **beagle-core:** Move noise stripping into jq pipelines for `fetch-pr-feedback` command — bot reviewer comments (e.g. CodeRabbit) contained massive `<details>` blocks and HTML noise inflating feedback files; stripping now happens at the jq level with a 4000-char per-comment safety net ([#55](https://github.com/existential-birds/beagle/pull/55))

## [2.1.0] - 2026-02-07

### Added
- **beagle-go:** `go-architect` skill — project structure, dependency injection, graceful shutdown patterns
- **beagle-go:** `go-concurrency-web` skill — worker pools, rate limiting, race detection for web services
- **beagle-go:** `go-data-persistence` skill — sqlx/pgx patterns, transactions, migrations, connection pooling
- **beagle-go:** `go-middleware` skill — net/http middleware chains, slog structured logging, context propagation, error handling
- **beagle-go:** `go-web-expert` skill — net/http server patterns, request validation, handler testing

### Changed
- **beagle-go:** Enhanced `go-code-review` with functional options and sync.Pool patterns
- **beagle-go:** Enhanced `go-testing-code-review` with benchmarks, fuzz tests, HTTP handler tests, and golden file patterns
- **docs:** Add DeepWiki badge to README

## [2.0.3] - 2026-02-06

### Fixed
- **beagle-elixir:** Bump plugin version to 1.0.1 to ensure `review-elixir` command is picked up by plugin cache on update

## [2.0.2] - 2026-02-06

### Fixed
- **marketplace:** Add deprecated `beagle` stub plugin for backward compatibility — users with the pre-v2 `beagle@existential-birds` reference no longer get load errors on startup ([#49](https://github.com/existential-birds/beagle/pull/49))

### Changed
- **license:** Switch from MIT to Apache License 2.0

### Added
- Upgrade notice in README with uninstall instructions for the old monolithic plugin

## [2.0.1] - 2026-02-06

### Fixed
- **marketplace:** Use `./plugins/` prefix in all plugin source paths to conform to marketplace schema (bare names like `"beagle-core"` are not valid source values)

## [2.0.0] - 2026-02-05

### Removed
- **BREAKING**: Monolith `beagle` plugin removed. Users must now install individual plugins.

### Changed
- **BREAKING**: All skill references use new plugin prefixes (e.g., `beagle-python:python-code-review`)

### Added
- `beagle-core` plugin: shared workflows, verification protocol, git commands, feedback handling
- `beagle-python` plugin: Python, FastAPI, SQLAlchemy, PostgreSQL, pytest code review
- `beagle-go` plugin: Go, BubbleTea, Wish SSH, Prometheus code review
- `beagle-ios` plugin: Swift, SwiftUI, SwiftData, iOS frameworks code review
- `beagle-react` plugin: React, React Flow, React Router, shadcn/ui, Tailwind, Vitest, Zustand
- `beagle-ai` plugin: Pydantic AI, LangGraph, DeepAgents, Vercel AI SDK
- `beagle-docs` plugin: documentation quality using Diataxis principles
- `beagle-analysis` plugin: 12-Factor compliance, ADRs, LLM-as-judge
- `beagle-testing` plugin: test plan generation and execution

### Changed
- Repository is now a marketplace-only structure under `plugins/`
- Root-level `skills/` and `commands/` directories removed

## [1.14.0] - 2026-02-05

### Added
- Marketplace structure for selective plugin installation
- `beagle-elixir` plugin: standalone Elixir/Phoenix/LiveView code review
  - Skills: elixir-code-review, elixir-security-review, elixir-performance-review
  - Skills: phoenix-code-review, liveview-code-review, exunit-code-review
  - Command: review-elixir

### Changed
- Repository now functions as both a plugin and a marketplace
- Users can install individual plugins via `/plugin install beagle-elixir@existential-birds`

## [1.13.1] - 2026-02-05

### Fixed

- **marketplace:** Remove `pluginRoot` from marketplace.json that caused beagle plugin source to resolve to wrong directory, breaking installation and auto-updates ([#45](https://github.com/existential-birds/beagle/pull/45))

## [1.13.0] - 2026-02-05

### Added

- **commands:** Add `review-elixir` command for comprehensive Elixir/Phoenix code review with optional parallel agents ([#43](https://github.com/existential-birds/beagle/pull/43))
- **skills:** Add 6 Elixir code review skills: `elixir-code-review` (idiomatic patterns, OTP, documentation), `phoenix-code-review` (controllers, contexts, routing, plugs), `liveview-code-review` (lifecycle, assigns/streams, components, security), `elixir-performance-review` (GenServer bottlenecks, memory, concurrency), `elixir-security-review` (code injection, atom exhaustion, secret handling), and `exunit-code-review` (test patterns, Mox boundary mocking, test adapters) ([#43](https://github.com/existential-birds/beagle/pull/43))
- **marketplace:** Add `beagle-elixir` as standalone plugin for installing Elixir review skills independently ([#43](https://github.com/existential-birds/beagle/pull/43))

### Removed

- **cursor:** Remove Cursor IDE command support (15 command files) in favor of Claude Code-only workflow ([#42](https://github.com/existential-birds/beagle/pull/42))
- **feedback:** Remove `.feedback-log.csv` tracking from receive-feedback skill and command ([#42](https://github.com/existential-birds/beagle/pull/42))

## [1.12.0] - 2026-01-24

### Added

- **commands:** Add `gen-test-plan` command for generating structured test plans from feature specs, user stories, or existing code using multi-agent architecture ([#38](https://github.com/existential-birds/beagle/pull/38))
- **commands:** Add `run-test-plan` command for executing test plans with browser automation via the agent-browser skill, producing structured test reports ([#38](https://github.com/existential-birds/beagle/pull/38))

## [1.11.0] - 2026-01-24

### Added

- **docs:** Add `draft-docs` command for generating first-draft technical documentation with two-phase workflow (draft to `docs/drafts/`, then publish) ([#5](https://github.com/existential-birds/beagle/pull/5))
- **docs:** Add `improve-doc` command for analyzing and refining existing documentation using the Diátaxis framework with interactive refinement workflow ([#5](https://github.com/existential-birds/beagle/pull/5))
- **skills:** Add `docs-style` skill with core writing principles for technical documentation (voice, tone, structure) ([#5](https://github.com/existential-birds/beagle/pull/5))
- **skills:** Add `reference-docs` skill with patterns for API reference and configuration documentation ([#5](https://github.com/existential-birds/beagle/pull/5))
- **skills:** Add `howto-docs` skill with patterns for task-oriented how-to guides ([#5](https://github.com/existential-birds/beagle/pull/5))
- **skills:** Add `tutorial-docs` skill with patterns for learning-oriented tutorials ([#5](https://github.com/existential-birds/beagle/pull/5))
- **skills:** Add `explanation-docs` skill with patterns for understanding-oriented explanations ([#5](https://github.com/existential-birds/beagle/pull/5))

## [1.10.0] - 2026-01-13

### Added

- **review:** Add verification protocol to reduce false positives with mandatory verification steps before flagging issues ([#33](https://github.com/existential-birds/beagle/pull/33))
- **skills:** Add `review-verification-protocol` skill with evidence requirements and false positive prevention guidelines ([#33](https://github.com/existential-birds/beagle/pull/33))

### Changed

- **review:** Update all review commands (review-frontend, review-go, review-ios, review-python, review-tui) to integrate verification protocol ([#33](https://github.com/existential-birds/beagle/pull/33))
- **skills:** Enhance code review skills (fastapi, go, python, react-router, shadcn) with verification requirements ([#33](https://github.com/existential-birds/beagle/pull/33))

## [1.9.0] - 2026-01-11

### Added

- **ios:** Add comprehensive iOS/SwiftUI code review system with 12 new skills covering Swift, SwiftUI, SwiftData, Combine, URLSession, HealthKit, CloudKit, WatchOS, WidgetKit, App Intents, and Swift Testing ([#29](https://github.com/existential-birds/beagle/pull/29))
- **commands:** Add `review-ios` command for iOS codebase reviews with automatic technology detection ([#29](https://github.com/existential-birds/beagle/pull/29))
- **commands:** Add `release` and `release-tag` commands for automated release workflow with changelog generation and GitHub releases ([#30](https://github.com/existential-birds/beagle/pull/30))

## [1.8.0] - 2026-01-04

### Added

- **llm-judge:** Add LLM-as-judge comparison command for evaluating implementations against requirements using structured scoring rubrics, fact extraction, and parallel judge agents ([#24](https://github.com/existential-birds/beagle/pull/24))

## [1.7.0] - 2026-01-03

### Added

- **llm-artifacts-detection:** New skill for detecting common LLM coding agent artifacts (over-abstraction, dead code, DRY violations, verbose comments, defensive overkill)
- **review-llm-artifacts:** New command to detect LLM artifacts using 4 parallel subagents (tests, dead code, abstraction, style) with JSON report output
- **fix-llm-artifacts:** New command to apply fixes from review with safe/risky classification, dry-run support, and post-fix verification

## [1.6.1] - 2026-01-03

### Fixed

- **adr:** Resolve decision display, numbering, and frontmatter issues ([#18](https://github.com/existential-birds/beagle/pull/18))

## [1.6.0] - 2026-01-02

### Added

- **adr-decision-extraction:** New skill for extracting architectural decisions from conversation context
- **adr-writing:** New skill for writing MADR-formatted Architecture Decision Records with templates and validation
- **write-adr:** New command to generate ADRs from decisions made in the current session ([#15](https://github.com/existential-birds/beagle/pull/15))

## [1.5.1] - 2025-12-31

### Fixed

- **commands:** Add explicit `Skill` tool instructions to all commands that load skills, fixing issue where Claude Code would manually search for skill files instead of using the Skill tool ([#11](https://github.com/existential-birds/beagle/pull/11))

## [1.5.0] - 2025-12-31

### Added

- **review-feedback-schema:** New skill providing structured CSV schema for logging code review outcomes (verdict, rationale, rule source) to enable feedback-driven skill improvement
- **review-skill-improver:** New skill that analyzes feedback logs to identify false positive patterns and suggest specific skill modifications

## [1.4.0] - 2025-12-30

### Added

- **deepagents-architecture:** New skill for architectural decisions when building Deep Agents applications - backend selection, subagent patterns, middleware architecture, and decision checklists
- **deepagents-implementation:** New skill covering `create_deep_agent` API, streaming, backends, subagents, human-in-the-loop, custom middleware, MCP integration, and production patterns
- **deepagents-code-review:** New skill with 23 anti-patterns across 6 categories (critical, backend, subagent, middleware, system prompt, performance) plus comprehensive review checklist

## [1.3.0] - 2025-12-23

### Added

- **bubbletea:** Add false positive prevention for Elm architecture patterns to avoid flagging intentional BubbleTea designs ([#1](https://github.com/existential-birds/beagle/pull/1))
- **bubbletea:** Add comprehensive Bubbles component coverage with patterns for list, table, viewport, textinput, textarea, spinner, progress, filepicker, help, key, and paginator components ([#1](https://github.com/existential-birds/beagle/pull/1))
- **bubbletea:** Add reference documentation for Elm architecture, component composition, and Bubbles library integration ([#1](https://github.com/existential-birds/beagle/pull/1))

## [1.2.0] - 2025-12-21

### Added

- New `prompt-improver` command for optimizing code-related prompts following Claude best practices
- Cursor IDE version of `prompt-improver` command

## [1.1.0] - 2025-12-21

### Changed

- Renamed `review-backend` command to `review-python` for clarity

## [1.0.0] - 2025-12-21

### Added

- Initial release
- Frontend skills: React Flow, React Router v7, Tailwind v4, shadcn/ui, Zustand, Vitest
- Backend (Python) skills: FastAPI, SQLAlchemy, PostgreSQL, pytest, Pydantic AI
- Backend (Go) skills: BubbleTea, Wish SSH, Prometheus, Go testing
- AI framework skills: LangGraph, Vercel AI SDK
- Utility skills: Docling, SQLite Vec, GitHub Projects, 12-Factor Apps
- Review commands: `review-python`, `review-frontend`, `review-go`, `review-tui`, `review-plan`
- Git commands: `commit-push`, `create-pr`, `gen-release-notes`
- PR feedback commands: `fetch-pr-feedback`, `respond-pr-feedback`
- Analysis commands: `12-factor-apps-analysis`, `receive-feedback`
- Development commands: `skill-builder`, `ensure-docs`
- Cursor IDE command equivalents

[Unreleased]: https://github.com/existential-birds/beagle/compare/v4.1.0...HEAD
[4.1.0]: https://github.com/existential-birds/beagle/compare/v4.0.0...v4.1.0
[4.0.0]: https://github.com/existential-birds/beagle/compare/v3.11.0...v4.0.0
[3.11.0]: https://github.com/existential-birds/beagle/compare/v3.10.0...v3.11.0
[3.10.0]: https://github.com/existential-birds/beagle/compare/v3.9.1...v3.10.0
[3.9.1]: https://github.com/existential-birds/beagle/compare/v3.9.0...v3.9.1
[3.9.0]: https://github.com/existential-birds/beagle/compare/v3.8.0...v3.9.0
[3.8.0]: https://github.com/existential-birds/beagle/compare/v3.7.0...v3.8.0
[3.7.0]: https://github.com/existential-birds/beagle/compare/v3.6.0...v3.7.0
[3.6.0]: https://github.com/existential-birds/beagle/compare/v3.5.0...v3.6.0
[3.5.0]: https://github.com/existential-birds/beagle/compare/v3.4.0...v3.5.0
[3.4.0]: https://github.com/existential-birds/beagle/compare/v3.3.0...v3.4.0
[3.3.0]: https://github.com/existential-birds/beagle/compare/v3.2.0...v3.3.0
[3.2.0]: https://github.com/existential-birds/beagle/compare/v3.1.0...v3.2.0
[3.1.0]: https://github.com/existential-birds/beagle/compare/v3.0.0...v3.1.0
[3.0.0]: https://github.com/existential-birds/beagle/compare/v2.12.1...v3.0.0
[2.12.1]: https://github.com/existential-birds/beagle/compare/v2.12.0...v2.12.1
[2.12.0]: https://github.com/existential-birds/beagle/compare/v2.11.0...v2.12.0
[2.11.0]: https://github.com/existential-birds/beagle/compare/v2.10.1...v2.11.0
[2.10.1]: https://github.com/existential-birds/beagle/compare/v2.10.0...v2.10.1
[2.10.0]: https://github.com/existential-birds/beagle/compare/v2.9.0...v2.10.0
[2.9.0]: https://github.com/existential-birds/beagle/compare/v2.8.0...v2.9.0
[2.8.0]: https://github.com/existential-birds/beagle/compare/v2.7.1...v2.8.0
[2.7.0]: https://github.com/existential-birds/beagle/compare/v2.6.0...v2.7.0
[2.6.0]: https://github.com/existential-birds/beagle/compare/v2.5.0...v2.6.0
[2.5.0]: https://github.com/existential-birds/beagle/compare/v2.4.0...v2.5.0
[2.4.0]: https://github.com/existential-birds/beagle/compare/v2.3.1...v2.4.0
[2.3.1]: https://github.com/existential-birds/beagle/compare/v2.3.0...v2.3.1
[2.3.0]: https://github.com/existential-birds/beagle/compare/v2.2.0...v2.3.0
[2.2.0]: https://github.com/existential-birds/beagle/compare/v2.1.1...v2.2.0
[2.1.1]: https://github.com/existential-birds/beagle/compare/v2.1.0...v2.1.1
[2.1.0]: https://github.com/existential-birds/beagle/compare/v2.0.3...v2.1.0
[2.0.3]: https://github.com/existential-birds/beagle/compare/v2.0.2...v2.0.3
[2.0.2]: https://github.com/existential-birds/beagle/compare/v2.0.1...v2.0.2
[2.7.1]: https://github.com/existential-birds/beagle/compare/v2.7.0...v2.7.1
[2.0.1]: https://github.com/existential-birds/beagle/compare/v2.0.0...v2.0.1
[2.0.0]: https://github.com/existential-birds/beagle/compare/v1.14.0...v2.0.0
[1.14.0]: https://github.com/existential-birds/beagle/compare/v1.13.1...v1.14.0
[1.13.1]: https://github.com/existential-birds/beagle/compare/v1.13.0...v1.13.1
[1.13.0]: https://github.com/existential-birds/beagle/compare/v1.12.0...v1.13.0
[1.12.0]: https://github.com/existential-birds/beagle/compare/v1.11.0...v1.12.0
[1.11.0]: https://github.com/existential-birds/beagle/compare/v1.10.0...v1.11.0
[1.10.0]: https://github.com/existential-birds/beagle/compare/v1.9.0...v1.10.0
[1.9.0]: https://github.com/existential-birds/beagle/compare/v1.8.0...v1.9.0
[1.8.0]: https://github.com/existential-birds/beagle/compare/v1.7.0...v1.8.0
[1.7.0]: https://github.com/existential-birds/beagle/compare/v1.6.1...v1.7.0
[1.6.1]: https://github.com/existential-birds/beagle/compare/v1.6.0...v1.6.1
[1.6.0]: https://github.com/existential-birds/beagle/compare/v1.5.1...v1.6.0
[1.5.1]: https://github.com/existential-birds/beagle/compare/v1.5.0...v1.5.1
[1.5.0]: https://github.com/existential-birds/beagle/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/existential-birds/beagle/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/existential-birds/beagle/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/existential-birds/beagle/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/existential-birds/beagle/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/existential-birds/beagle/releases/tag/v1.0.0
