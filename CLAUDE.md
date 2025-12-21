# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Beagle is a Claude Code plugin providing technology knowledge bases and development workflows. It contains 40 skills (auto-loaded by Claude when relevant) and 14 commands (user-invoked via `/beagle:<command>`).

## Plugin Architecture

```
beagle/
├── .claude-plugin/          # Plugin manifest and marketplace config
├── commands/                # User-invoked slash commands (14 files)
├── skills/                  # Model-invoked agent skills (40 skills)
│   ├── Frontend/            # React Flow, React Router v7, Tailwind v4, shadcn/ui, Zustand, Vitest
│   ├── Backend (Python)/    # FastAPI, SQLAlchemy, PostgreSQL, pytest
│   ├── Backend (Go)/        # BubbleTea, Wish SSH, Prometheus, Go testing
│   ├── AI Frameworks/       # Pydantic AI (6), LangGraph (3), Vercel AI SDK
│   └── Utilities/           # Docling, SQLite Vec, GitHub Projects, 12-Factor Apps
└── docs/                    # Reference documentation and design plans
```

## Skills vs Commands

**Skills** (in `skills/` folder):
- Claude loads automatically when relevant keywords appear in conversation
- Provide passive technology-specific guidance
- Structure: `skill-name/SKILL.md` with optional `references/` folder
- Frontmatter: `name`, `description` (include trigger keywords), optional `allowed-tools`

**Commands** (in `commands/` folder):
- User invokes explicitly with `/beagle:<command-name>`
- Provide step-by-step workflows for complex tasks
- Structure: Single markdown file with frontmatter `description`

## Creating New Skills

Each skill folder contains:
```
skill-name/
├── SKILL.md                 # Required: frontmatter + instructions (under 500 lines)
└── references/              # Optional: supporting documentation
```

Frontmatter format:
```yaml
---
name: skill-name-here          # lowercase-hyphen, max 64 chars
description: What it does and when to use it. Include trigger keywords so Claude knows when to invoke.
---
```

Key principles:
- Assume Claude is smart; only add context it wouldn't know
- Use progressive disclosure: core content in SKILL.md, details in references
- Include quick start examples and checklists for complex workflows
- For code review skills: use consistent issue format `[FILE:LINE] ISSUE_TITLE`

## Creating New Commands

Commands are single markdown files in `commands/`:
```yaml
---
description: What the command does
---

Step-by-step instructions...
```

Common patterns:
- Start with context gathering (git diff, grep for tech detection)
- Load relevant skills based on detected technologies
- Include output format templates
- End with verification steps

## Key Commands

| Command | Purpose |
|---------|---------|
| `review-backend` | Python/FastAPI code review with tech detection |
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
