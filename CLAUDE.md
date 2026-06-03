# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Beagle is a Claude Code plugin marketplace providing framework-aware code review skills and verification workflows for pre-push reviews and GitHub bot feedback handling. It contains 10 focused plugins with 144 skills.

## Marketplace Architecture

```text
beagle/
├── .claude-plugin/
│   └── marketplace.json         # Marketplace manifest (10 plugins)
└── plugins/
    ├── beagle-core/             # Shared workflows, verification, git workflows, skill tooling (19 skills)
    ├── beagle-python/           # Python, FastAPI, SQLAlchemy, PostgreSQL, pytest (7 skills)
    ├── beagle-go/               # Go, BubbleTea, Wish SSH, Prometheus (13 skills)
    ├── beagle-elixir/           # Elixir, Phoenix, LiveView, ExUnit, ExDoc (11 skills)
    ├── beagle-ios/              # Swift, SwiftUI, SwiftData, iOS frameworks (16 skills)
    ├── beagle-react/            # React, React Flow, shadcn/ui, Tailwind, Vitest, Remix v2 (28 skills)
    ├── beagle-rust/             # Rust, tokio, axum, sqlx, serde (12 skills)
    ├── beagle-ai/               # Pydantic AI, LangGraph, DeepAgents, Vercel AI SDK (deprecated)
    ├── beagle-docs/             # Documentation quality, AI writing detection (10 skills)
    ├── beagle-analysis/         # Brainstorming, ADRs, strategy, LLM-as-judge, spec resolution, PRFAQ filter, TDD plan writing (13 skills)
    └── beagle-testing/          # Test plan generation and execution (2 skills)
```

Each plugin is self-contained with its own `plugin.json` and `skills/` directory.

## Local Development

Test the marketplace during development:

```bash
# In Claude Code settings (~/.claude/settings.json)
{
  "plugins": ["/path/to/your/beagle"]
}
```

Restart Claude Code after changes to reload. Skills are discovered from plugin `skills/` directories and trigger keywords in skill frontmatter. Codex support files are in [.codex/INSTALL.md](.codex/INSTALL.md) and [docs/README.codex.md](docs/README.codex.md).

## Skills vs Commands

See [Agent Skills](https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview) for the canonical format.

**Skills** (`plugins/<name>/skills/` folders): Auto-loaded by Claude when relevant. Structure: `skill-name/SKILL.md` with optional `references/` folder and frontmatter such as `disable-model-invocation` and `user-invocable`.

Commands have been unified into the skills format. All 144 SKILL.md files across 10 plugins constitute the canonical source; no separate `commands/` directories exist in the codebase.

## Creating New Skills

See [Agent Skills best practices](https://docs.claude.com/en/docs/agents-and-tools/agent-skills/best-practices) for authoring guidance.

Beagle-specific:
- Keep SKILL.md under 500 lines; use `references/` for details
- Some skills use multiple root-level .md files (e.g., react-router-v7)
- Code review skills: use format `[FILE:LINE] ISSUE_TITLE`
- Place new skills in the appropriate plugin directory
- Mark workflow skills with `disable-model-invocation: true`
- Mark internal-only reference skills with `user-invocable: false`

## Key Skills

| Plugin | Skill | Purpose |
|--------|---------|---------|
| beagle-python | `review-python` | Python/FastAPI code review with tech detection |
| beagle-react | `review-frontend` | React/TypeScript code review with tech detection |
| beagle-go | `review-go` | Go code review with BubbleTea/Wish/Prometheus detection |
| beagle-go | `review-tui` | BubbleTea TUI code review with Elm architecture focus |
| beagle-ios | `review-ios` | iOS/SwiftUI code review |
| beagle-elixir | `review-elixir` | Elixir/Phoenix/LiveView code review |
| beagle-rust | `review-rust` | Rust/tokio/axum/sqlx/serde code review |
| beagle-react | `review-remix-v2` | Remix v2 code review (loaders, actions, forms, sessions, perf/SSR) |
| beagle-core | `review-plan` | Review implementation plans before execution |
| beagle-core | `review-structure` | Repo-wide structural-maintainability review (code-judo restructurings, 1k-line file guard, anti-spaghetti branching, canonical-layer enforcement, anti-magic abstractions, explicit type/boundary contracts) |
| beagle-core | `commit-push` | Commit with Conventional Commits format |
| beagle-core | `create-pr` | Create PR with structured template |
| beagle-core | `gen-release-notes` | Generate changelog from git history |
| beagle-core | `skill-builder` | Guided skill creation workflow |
| beagle-core | `review-skill` | Automated skill PR review for structural validity, design quality, and marketplace consistency |
| beagle-core | `receive-feedback` | Process code review feedback with verification |
| beagle-core | `fetch-pr-feedback` | Fetch and evaluate bot review comments from PR |
| beagle-core | `respond-pr-feedback` | Post replies to bot review comments |
| beagle-core | `review-llm-artifacts` | Detect LLM coding artifacts |
| beagle-core | `verify-llm-artifacts` | Adjudicate review findings (confirm/false-positive/inconclusive) before deletes |
| beagle-core | `fix-llm-artifacts` | Fix detected artifacts |
| beagle-core | `prompt-improver` | Optimize prompts |
| beagle-core | `subagent-prompt` | Hand off the current session's work to a fresh session as an orchestrator-plus-subagents prompt, with per-task verification commands and a final integration check |
| beagle-analysis | `llm-judge` | Compare implementations using LLM-as-judge |
| beagle-analysis | `write-adr` | Generate ADRs from decisions |
| beagle-analysis | `web-research` | Parallel web-search research with cited, gap-flagged synthesis report |
| beagle-analysis | `artifact-analysis` | Parallel-subagent scan of local docs with cited, structured extraction |
| beagle-analysis | `prfaq-beagle` | Hardcore Working Backwards PRFAQ coach — 5-stage filter (Ignition → Press Release → Customer FAQ → Internal FAQ → Verdict) producing binary pass/fail; on pass hands off to `brainstorm-beagle` via a concept brief |
| beagle-analysis | `write-plan` | Turn a finalized `brainstorm-beagle` spec at `.beagle/concepts/<slug>/spec.md` into a bite-sized, TDD-driven implementation plan at `.beagle/concepts/<slug>/plan.md` |
| beagle-docs | `draft-docs` | Generate documentation drafts |
| beagle-docs | `improve-doc` | Improve docs using Diataxis principles |
| beagle-docs | `ensure-docs` | Documentation coverage check |
| beagle-docs | `review-ai-writing` | Detect AI writing patterns in docs and code |
| beagle-docs | `humanize-beagle` | Fix AI writing with safe/risky classification |
| beagle-testing | `gen-test-plan` | Generate YAML test plan from branch changes |
| beagle-testing | `run-test-plan` | Execute test plan, stop on first failure |

## Conventions

- **Commits**: Conventional Commits format (feat, fix, docs, refactor, test, chore)
- **Versioning**: Semantic versioning in marketplace.json and each plugin's `plugin.json`
- **Release notes**: Keep a Changelog format, generated via `/beagle-core:gen-release-notes`
- **Skill references**: Use `<plugin-name>:<skill-name>` format (e.g., `beagle-python:python-code-review`)

## No Build System

This is a pure markdown plugin marketplace. No npm, no build, no tests. Validation is manual inspection of markdown syntax and YAML frontmatter.

## Release Process

1. **Update CHANGELOG.md** - Add new version section with changes (Keep a Changelog format)
2. **Bump version** - Update `version` in `.claude-plugin/marketplace.json` and affected plugin.json files (semver)
3. **Commit** - `chore(release): bump version to X.Y.Z`
4. **Push** - `git push origin main`
5. **Tag** - `git tag -a vX.Y.Z -m "Release vX.Y.Z - Summary"` and `git push origin vX.Y.Z`
6. **Release** - `gh release create vX.Y.Z --title "vX.Y.Z" --notes "..."`

Version bumping:
- **Patch** (x.y.Z): Bug fixes, documentation
- **Minor** (x.Y.0): New skills or features
- **Major** (X.0.0): Breaking changes to existing skills
