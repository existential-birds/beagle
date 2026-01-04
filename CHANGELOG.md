# Changelog

All notable changes to Beagle are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
