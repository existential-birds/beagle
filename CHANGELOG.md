# Changelog

All notable changes to Beagle are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[2.3.0]: https://github.com/existential-birds/beagle/compare/v2.2.0...v2.3.0
[2.2.0]: https://github.com/existential-birds/beagle/compare/v2.1.1...v2.2.0
[2.1.1]: https://github.com/existential-birds/beagle/compare/v2.1.0...v2.1.1
[2.1.0]: https://github.com/existential-birds/beagle/compare/v2.0.3...v2.1.0
[2.0.3]: https://github.com/existential-birds/beagle/compare/v2.0.2...v2.0.3
[2.0.2]: https://github.com/existential-birds/beagle/compare/v2.0.1...v2.0.2
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
