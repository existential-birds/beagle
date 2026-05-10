# Changelog

All notable changes to Beagle are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **beagle-latex:** New plugin for LaTeX document creation, code review, bibliography hygiene, compilation, and Quarto book authoring. Six skills: `latex-document` (single-file create/compile with auto-detected engine and bundled article/report/resume-ats/beamer/IEEE/book templates), `latex-code-review` (audits `.tex` for the 9 long-form anti-patterns plus encoding/float/hardcoded-dimension issues, hooks `beagle-core:review-verification-protocol`), `latex-bibliography` (BibTeX/biblatex/biber selection, DOI/arXiv `fetch_bibtex.sh`, citation hygiene checklist), `latex-compilation` (latexmk, `\include`/`\includeonly` for fast incremental builds, log error parsing), `quarto-book` (multi-chapter `.qmd` book projects with bundled starter assets including `_quarto.yml`, `metadata.yaml`, sample chapters, and a kaobook Pandoc bridge template), and `textbook-typography` (kaobook vs Eisvogel+scrbook vs tufte-book class selection with `pandoc-sidenote` filter setup). Plugin README ships a `PostToolUse` hook recipe for auto-recompile on `*.tex`/`*.qmd` edits.

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

[Unreleased]: https://github.com/existential-birds/beagle/compare/v3.5.0...HEAD
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
