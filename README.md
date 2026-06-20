# beagle

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/existential-birds/beagle)

![Apollo 10 astronaut Thomas P. Stafford pats the nose of a stuffed Snoopy](assets/Stafford_and_Snoopy.jpg)

*Image: NASA, Public Domain. [Source](https://www.nasa.gov/multimedia/imagegallery/image_feature_572.html)*

Beagle is an [Agent Skills](https://agentskills.io/specification) marketplace: framework-aware code review, documentation, testing, architectural analysis, and git workflows for any compatible coding agent. Skills cover Python, Go, Rust, Elixir, React, Remix v2, and iOS/Swift.

Pairs with [Amelia](https://github.com/existential-birds/amelia) for agent-based workflows and [Daydream](https://github.com/existential-birds/daydream) for automated review-fix-test loops.

## Installation

**Prerequisites:**
- A coding agent that supports [Agent Skills](https://agentskills.io)
- [agent-browser](https://github.com/vercel-labs/agent-browser) for the `run-test-plan` skill (optional)

### Any coding agent

Install with the [skills CLI](https://skills.sh/docs/cli):

```bash
npx skills add existential-birds/beagle
```

This downloads the skills and configures them for your agent. Codex users: see [.codex/INSTALL.md](.codex/INSTALL.md) and [docs/README.codex.md](docs/README.codex.md).

### Claude Code

```bash
claude plugin marketplace add https://github.com/existential-birds/beagle
claude plugin install beagle-core@existential-birds
```

Install additional plugins as needed (for example `beagle-python@existential-birds`). Update with:

```bash
claude plugin marketplace update existential-birds && claude plugin update <plugin-name>
```

If a marketplace file is reported missing, remove stale entries from `~/.claude/plugins/known_marketplaces.json` and restart.

## Plugins

| Plugin | Coverage |
|--------|----------|
| beagle-core | Shared workflows, verification, git, skill tooling |
| beagle-python | Python, FastAPI, SQLAlchemy, pytest |
| beagle-go | Go, BubbleTea, Wish SSH, Prometheus |
| beagle-elixir | Elixir, Phoenix, LiveView, ExUnit, ExDoc |
| beagle-ios | Swift, SwiftUI, SwiftData, iOS frameworks |
| beagle-react | React, React Flow, shadcn/ui, Tailwind, Remix v2 |
| beagle-rust | Rust, tokio, axum, sqlx, serde |
| beagle-docs | Documentation quality, AI-writing detection (Diataxis) |
| beagle-analysis | Brainstorming, ADRs, strategy, LLM-as-judge, TDD planning |
| beagle-testing | Test plan generation and execution |

## Key skills

Your agent discovers every skill automatically; these are the headline ones.

**Code review** — `review-python`, `review-frontend`, `review-remix-v2` (beagle-react); `review-go`, `review-tui` (beagle-go); `review-rust`, `review-elixir`, `review-ios`.

**Git & feedback** — `commit-push`, `create-pr`, `gen-release-notes`, `fetch-pr-feedback`, `respond-pr-feedback`, `receive-feedback`.

**LLM artifacts** — `review-llm-artifacts`, `verify-llm-artifacts`, `fix-llm-artifacts`.

**Docs** — `improve-doc`, `draft-docs`, `ensure-docs`, `review-ai-writing`, `humanize-beagle`.

**Analysis & planning** — `review-plan`, `write-adr`, `brainstorm-beagle`, `write-plan`, `quick-plan`, `llm-judge`, `strategy-interview`, `prfaq-beagle`, `web-research`.

**Testing** — `gen-test-plan`, `run-test-plan`.

**Skill tooling** — `skill-builder`, `review-skill`.
