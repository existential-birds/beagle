# beagle

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/existential-birds/beagle)

![Apollo 10 astronaut Thomas P. Stafford pats the nose of a stuffed Snoopy](assets/Stafford_and_Snoopy.jpg)

*Image: NASA, Public Domain. [Source](https://www.nasa.gov/multimedia/imagegallery/image_feature_572.html)*

Beagle is a Claude Code plugin marketplace with 126 skills across code review, documentation, testing, architectural analysis, and git workflows. Use it to review before you push, detect AI-generated artifacts, draft and improve docs, generate test plans, and analyze codebases — across Python, Go, Rust, Elixir, React, iOS/Swift, and AI frameworks.

Used with [Amelia](https://github.com/existential-birds/amelia) for agent-based workflows and [Daydream](https://github.com/existential-birds/daydream) for automated review-fix-test loops.

## Installation

**Prerequisites:**
- [Claude Code](https://claude.ai/code) CLI installed
- [agent-browser](https://github.com/vercel-labs/agent-browser) for the `run-test-plan` skill (optional)

```bash
# Add the marketplace
claude plugin marketplace add https://github.com/existential-birds/beagle

# Install the plugins you need
claude plugin install beagle-core@existential-birds
claude plugin install beagle-python@existential-birds
claude plugin install beagle-react@existential-birds
```

Verify installation by opening a new Claude Code session and running `/beagle-core:commit-push` — if the skill loads, the plugin is active.

To update:
```bash
claude plugin marketplace update existential-birds && claude plugin update <plugin-name>
```

**Troubleshooting:**
- "Marketplace file not found": Remove stale entries from `~/.claude/plugins/known_marketplaces.json` and restart Claude Code.
- Plugin not updating: Run `claude plugin marketplace update existential-birds` to refresh the marketplace.

### Other Agents

Use the [skills CLI](https://skills.sh/docs/cli) to install beagle skills for other AI agents:

```bash
npx skills add existential-birds/beagle
```

This downloads the skills and configures them for your agent.

**Codex users:** Link each plugin into `~/.agents/skills/` — see [.codex/INSTALL.md](.codex/INSTALL.md) for setup instructions.

## Plugins

| Plugin | Skills | Category |
|--------|--------|----------|
| **beagle-core** | 18 | Shared workflows, verification, git |
| **beagle-python** | 7 | Python, FastAPI, SQLAlchemy, pytest |
| **beagle-go** | 13 | Go, BubbleTea, Wish SSH, Prometheus |
| **beagle-elixir** | 11 | Elixir, Phoenix, LiveView, ExUnit, ExDoc |
| **beagle-ios** | 16 | Swift, SwiftUI, SwiftData, iOS frameworks |
| **beagle-react** | 16 | React, React Flow, shadcn/ui, Tailwind |
| **beagle-rust** | 10 | Rust, tokio, axum, sqlx, serde |
| **beagle-ai** | 13 | Pydantic AI, LangGraph, DeepAgents |
| **beagle-docs** | 10 | Documentation quality, AI writing detection (Diataxis) |
| **beagle-analysis** | 10 | Brainstorming, 12-Factor, ADRs, strategy, LLM-as-judge |
| **beagle-testing** | 2 | Test plan generation and execution |
| **Total** | **126** | — |

## Skills

These are the canonical skill entry points for Beagle.

### beagle-core

| Skill | Description |
|---------|-------------|
| `review-plan <path>` | Review implementation plans |
| `review-llm-artifacts` | Detect LLM coding artifacts |
| `fix-llm-artifacts` | Fix detected artifacts |
| `commit-push` | Commit and push changes |
| `create-pr` | Create PR with template |
| `gen-release-notes <tag>` | Generate release notes |
| `receive-feedback <path>` | Process review feedback |
| `fetch-pr-feedback` | Fetch bot comments from PR |
| `respond-pr-feedback` | Reply to bot comments |
| `skill-builder` | Create new skills |
| `prompt-improver` | Optimize prompts |

### Code Review Skills

| Skill | Plugin | Description |
|---------|--------|-------------|
| `review-python` | beagle-python | Python/FastAPI code review |
| `review-frontend` | beagle-react | React/TypeScript code review |
| `review-go` | beagle-go | Go code review |
| `review-tui` | beagle-go | BubbleTea TUI code review |
| `review-ios` | beagle-ios | iOS/SwiftUI code review |
| `review-elixir` | beagle-elixir | Elixir/Phoenix code review |
| `review-rust` | beagle-rust | Rust/tokio/axum code review |

### Documentation & Analysis Skills

| Skill | Plugin | Description |
|---------|--------|-------------|
| `draft-docs <prompt>` | beagle-docs | Generate documentation drafts |
| `improve-doc <path>` | beagle-docs | Improve docs using Diataxis |
| `ensure-docs` | beagle-docs | Documentation coverage check |
| `review-ai-writing` | beagle-docs | Detect AI writing patterns |
| `humanize-ai-writing` | beagle-docs | Fix AI writing with safe/risky classification |
| `12-factor-apps-analysis` | beagle-analysis | 12-Factor compliance check |
| `llm-judge` | beagle-analysis | Compare implementations |
| `write-adr` | beagle-analysis | Generate ADRs from decisions |
| `strategy-interview` | beagle-analysis | Build strategy through guided conversation |
| `strategy-review` | beagle-analysis | Pressure-test existing strategy documents |

### Testing Skills

| Skill | Plugin | Description |
|---------|--------|-------------|
| `gen-test-plan` | beagle-testing | Generate YAML test plan |
| `run-test-plan` | beagle-testing | Execute test plan |
