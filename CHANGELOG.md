# Changelog

All notable changes to Beagle are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[1.2.0]: https://github.com/existential-birds/beagle/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/existential-birds/beagle/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/existential-birds/beagle/releases/tag/v1.0.0
