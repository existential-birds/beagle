# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Beagle is a Claude Code plugin providing code review skills and verification workflows. Designed to complement [superpowers](https://github.com/obra/superpowers) with pre-push reviews and GitHub bot feedback handling. It contains 45 skills (auto-loaded by Claude when relevant) and 14 commands (user-invoked via `/beagle:<command>`).

## Plugin Architecture

```
beagle/
├── .claude-plugin/          # Plugin manifest (plugin.json) and marketplace config
├── commands/                # User-invoked slash commands (14 files)
├── skills/                  # Model-invoked agent skills (45 skills, flat structure)
└── .cursor/commands/        # Cursor IDE versions (embedded skill content)
```

**Skill categories** (all in flat `skills/` folder):
- **Frontend**: react-flow*, react-router-v7, tailwind-v4, shadcn-ui*, zustand-state, vitest-testing, dagre-react-flow
- **Backend Python**: python-code-review, fastapi-*, sqlalchemy-code-review, postgres-code-review, pytest-code-review
- **Backend Go**: go-code-review, bubbletea-code-review, wish-ssh-code-review, prometheus-go-code-review, go-testing-code-review
- **AI Frameworks**: pydantic-ai-* (6 skills), langgraph-* (3 skills), vercel-ai-sdk
- **Utilities**: docling, sqlite-vec, github-projects, 12-factor-apps, ai-elements, agent-architecture-analysis, receive-feedback, review-feedback-schema, review-skill-improver

## Local Development

Test the plugin during development:

```bash
# In Claude Code settings (~/.claude/settings.json)
{
  "plugins": ["/path/to/your/beagle"]
}
```

Restart Claude Code after changes to reload. For skills, start a conversation using trigger keywords. For commands, run `/beagle:<command-name>`.

## Skills vs Commands

See [Agent Skills](https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview) and [Slash commands](https://docs.claude.com/en/docs/claude-code/slash-commands) for general concepts.

**Skills** (`skills/` folder): Auto-loaded by Claude when relevant. Structure: `skill-name/SKILL.md` with optional `references/` folder.

**Commands** (`commands/` folder): User-invoked with `/beagle:<name>`. Single markdown file per command.

## Creating New Skills

See [Agent Skills best practices](https://docs.claude.com/en/docs/agents-and-tools/agent-skills/best-practices) for authoring guidance.

Beagle-specific:
- Keep SKILL.md under 500 lines; use `references/` for details
- Some skills use multiple root-level .md files (e.g., react-router-v7)
- Code review skills: use format `[FILE:LINE] ISSUE_TITLE`

## Creating New Commands

Beagle command patterns:
- Start with context gathering (git diff, tech detection)
- Load relevant skills dynamically
- Include output format templates
- End with verification steps

## Key Commands

| Command | Purpose |
|---------|---------|
| `review-python` | Python/FastAPI code review with tech detection |
| `review-frontend` | React/TypeScript code review with tech detection |
| `review-go` | Go code review with BubbleTea/Wish/Prometheus detection |
| `review-tui` | BubbleTea TUI code review with Elm architecture focus |
| `review-plan` | Review implementation plans before execution |
| `commit-push` | Commit with Conventional Commits format |
| `create-pr` | Create PR with structured template |
| `gen-release-notes` | Generate changelog from git history |
| `skill-builder` | Guided skill creation workflow |
| `receive-feedback` | Process code review feedback with verification |
| `fetch-pr-feedback` | Fetch and evaluate bot review comments from PR |
| `respond-pr-feedback` | Post replies to bot review comments |
| `12-factor-apps-analysis` | Analyze codebase for 12-Factor compliance |
| `ensure-docs` | Documentation quality checking with language-specific standards |

## Conventions

- **Commits**: Conventional Commits format (feat, fix, docs, refactor, test, chore)
- **Versioning**: Semantic versioning in `.claude-plugin/plugin.json`
- **Release notes**: Keep a Changelog format, generated via `/beagle:gen-release-notes`

## No Build System

This is a pure markdown plugin. No npm, no build, no tests. Validation is manual inspection of markdown syntax and YAML frontmatter.

## Release Process

1. **Update CHANGELOG.md** - Add new version section with changes (Keep a Changelog format)
2. **Bump version** - Update `version` in `.claude-plugin/plugin.json` (semver)
3. **Commit** - `chore(release): bump version to X.Y.Z`
4. **Push** - `git push origin main`
5. **Tag** - `git tag -a vX.Y.Z -m "Release vX.Y.Z - Summary"` and `git push origin vX.Y.Z`
6. **Release** - `gh release create vX.Y.Z --title "vX.Y.Z" --notes "..."`

Version bumping:
- **Patch** (x.y.Z): Bug fixes, documentation
- **Minor** (x.Y.0): New commands, skills, or features
- **Major** (X.0.0): Breaking changes to existing commands/skills

## Cursor IDE Support

Cursor commands in `.cursor/commands/` are expanded versions with all skill content embedded (no dynamic skill loading). When updating skills, regenerate Cursor commands to keep them in sync.
