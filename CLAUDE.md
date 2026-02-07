# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Beagle is a Claude Code plugin marketplace providing framework-aware code review skills and verification workflows. Designed to complement [superpowers](https://github.com/obra/superpowers) with pre-push reviews and GitHub bot feedback handling. It contains 10 focused plugins with 80 skills and 25 commands.

## Marketplace Architecture

```
beagle/
├── .claude-plugin/
│   └── marketplace.json         # Marketplace manifest (10 plugins)
└── plugins/
    ├── beagle-core/             # Shared workflows, verification, git commands (8 skills, 11 commands)
    ├── beagle-python/           # Python, FastAPI, SQLAlchemy, PostgreSQL, pytest (6 skills, 1 command)
    ├── beagle-go/               # Go, BubbleTea, Wish SSH, Prometheus (6 skills, 2 commands)
    ├── beagle-elixir/           # Elixir, Phoenix, LiveView, ExUnit, ExDoc (10 skills, 1 command)
    ├── beagle-ios/              # Swift, SwiftUI, SwiftData, iOS frameworks (12 skills, 1 command)
    ├── beagle-react/            # React, React Flow, shadcn/ui, Tailwind, Vitest (15 skills, 1 command)
    ├── beagle-ai/               # Pydantic AI, LangGraph, DeepAgents, Vercel AI SDK (13 skills)
    ├── beagle-docs/             # Documentation quality using Diataxis (5 skills, 3 commands)
    ├── beagle-analysis/         # 12-Factor, ADRs, LLM-as-judge (5 skills, 3 commands)
    └── beagle-testing/          # Test plan generation and execution (2 commands)
```

Each plugin is self-contained with its own `plugin.json`, `skills/`, and `commands/` directories.

## Local Development

Test the marketplace during development:

```bash
# In Claude Code settings (~/.claude/settings.json)
{
  "plugins": ["/path/to/your/beagle"]
}
```

Restart Claude Code after changes to reload. For skills, start a conversation using trigger keywords. For commands, run `/<plugin-name>:<command-name>` (e.g., `/beagle-core:commit-push`).

## Skills vs Commands

See [Agent Skills](https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview) and [Slash commands](https://docs.claude.com/en/docs/claude-code/slash-commands) for general concepts.

**Skills** (`plugins/<name>/skills/` folders): Auto-loaded by Claude when relevant. Structure: `skill-name/SKILL.md` with optional `references/` folder.

**Commands** (`plugins/<name>/commands/` folders): User-invoked with `/<plugin-name>:<command>`. Single markdown file per command.

## Creating New Skills

See [Agent Skills best practices](https://docs.claude.com/en/docs/agents-and-tools/agent-skills/best-practices) for authoring guidance.

Beagle-specific:
- Keep SKILL.md under 500 lines; use `references/` for details
- Some skills use multiple root-level .md files (e.g., react-router-v7)
- Code review skills: use format `[FILE:LINE] ISSUE_TITLE`
- Place new skills in the appropriate plugin directory

## Creating New Commands

Beagle command patterns:
- Start with context gathering (git diff, tech detection)
- Load relevant skills dynamically using `<plugin-name>:<skill-name>` format
- Include output format templates
- End with verification steps

## Key Commands

| Plugin | Command | Purpose |
|--------|---------|---------|
| beagle-python | `review-python` | Python/FastAPI code review with tech detection |
| beagle-react | `review-frontend` | React/TypeScript code review with tech detection |
| beagle-go | `review-go` | Go code review with BubbleTea/Wish/Prometheus detection |
| beagle-go | `review-tui` | BubbleTea TUI code review with Elm architecture focus |
| beagle-ios | `review-ios` | iOS/SwiftUI code review |
| beagle-elixir | `review-elixir` | Elixir/Phoenix/LiveView code review |
| beagle-core | `review-plan` | Review implementation plans before execution |
| beagle-core | `commit-push` | Commit with Conventional Commits format |
| beagle-core | `create-pr` | Create PR with structured template |
| beagle-core | `gen-release-notes` | Generate changelog from git history |
| beagle-core | `skill-builder` | Guided skill creation workflow |
| beagle-core | `receive-feedback` | Process code review feedback with verification |
| beagle-core | `fetch-pr-feedback` | Fetch and evaluate bot review comments from PR |
| beagle-core | `respond-pr-feedback` | Post replies to bot review comments |
| beagle-core | `review-llm-artifacts` | Detect LLM coding artifacts |
| beagle-core | `fix-llm-artifacts` | Fix detected artifacts |
| beagle-core | `prompt-improver` | Optimize prompts |
| beagle-analysis | `12-factor-apps-analysis` | Analyze codebase for 12-Factor compliance |
| beagle-analysis | `llm-judge` | Compare implementations using LLM-as-judge |
| beagle-analysis | `write-adr` | Generate ADRs from decisions |
| beagle-docs | `draft-docs` | Generate documentation drafts |
| beagle-docs | `improve-doc` | Improve docs using Diataxis principles |
| beagle-docs | `ensure-docs` | Documentation coverage check |
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
- **Minor** (x.Y.0): New commands, skills, or features
- **Major** (X.0.0): Breaking changes to existing commands/skills
