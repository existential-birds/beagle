# beagle

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/existential-birds/beagle)

> **Upgrading from beagle v1?** The monolithic `beagle` plugin was split into individual plugins in v2.0.0. If you still have `beagle@existential-birds` enabled in `~/.claude/settings.json`, it now loads as a no-op stub. You can remove it with:
> ```
> claude plugin uninstall beagle@existential-birds
> ```
> Then install the individual plugins you need (see [Installation](#installation) below).

![Apollo 10 astronaut Thomas P. Stafford pats the nose of a stuffed Snoopy](assets/Stafford_and_Snoopy.jpg)

*Image: NASA, Public Domain. [Source](https://www.nasa.gov/multimedia/imagegallery/image_feature_572.html)*

A Claude Code plugin marketplace for code review and verification workflows. Catch issues before you push with pre-commit reviews for Python, Go, Elixir, React, iOS/Swift, and AI frameworks.

Powers the agents in [Amelia](https://github.com/existential-birds/amelia). For automated review-fix-test loops, see [Daydream](https://github.com/existential-birds/daydream).

## Installation

**Prerequisites:**
- [Claude Code](https://claude.ai/code) CLI installed
- [agent-browser](https://github.com/vercel-labs/agent-browser) for `run-test-plan` command (optional)

```bash
# Add the marketplace
claude plugin marketplace add https://github.com/existential-birds/beagle

# Install the plugins you need
claude plugin install beagle-core@existential-birds
claude plugin install beagle-python@existential-birds
claude plugin install beagle-react@existential-birds
```

Verify installation by running `/<plugin-name>:` in Claude Code (e.g., `/beagle-core:`)—you should see the command list.

To update: `claude plugin marketplace update existential-birds && claude plugin update <plugin-name>`

**Troubleshooting:**
- "Marketplace file not found": Remove stale entries from `~/.claude/plugins/known_marketplaces.json` and restart Claude Code.
- Plugin not updating: Run `claude plugin marketplace update existential-birds` to refresh the marketplace.

### Other Agents

Use the [skills CLI](https://skills.sh/docs/cli) to install beagle skills for other AI agents:

```bash
npx skills add existential-birds/beagle
```

This downloads the skills and configures them for your agent. Commands are Claude Code specific and not available through the skills CLI.

## Plugins

| Plugin | Skills | Commands | Category |
|--------|--------|----------|----------|
| **beagle-core** | 8 | 11 | Shared workflows, verification, git |
| **beagle-python** | 6 | 1 | Python, FastAPI, SQLAlchemy, pytest |
| **beagle-go** | 6 | 2 | Go, BubbleTea, Wish SSH, Prometheus |
| **beagle-elixir** | 10 | 1 | Elixir, Phoenix, LiveView, ExUnit, ExDoc |
| **beagle-ios** | 12 | 1 | Swift, SwiftUI, SwiftData, iOS frameworks |
| **beagle-react** | 15 | 1 | React, React Flow, shadcn/ui, Tailwind |
| **beagle-ai** | 13 | 0 | Pydantic AI, LangGraph, DeepAgents |
| **beagle-docs** | 5 | 3 | Documentation quality (Diataxis) |
| **beagle-analysis** | 5 | 3 | 12-Factor, ADRs, LLM-as-judge |
| **beagle-testing** | 0 | 2 | Test plan generation and execution |
| **Total** | **80** | **25** | |

## Commands

Run with `/<plugin-name>:<command>`. See [Slash commands](https://docs.claude.com/en/docs/claude-code/slash-commands).

### beagle-core

| Command | Description |
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

### Code Review

| Command | Plugin | Description |
|---------|--------|-------------|
| `review-python` | beagle-python | Python/FastAPI code review |
| `review-frontend` | beagle-react | React/TypeScript code review |
| `review-go` | beagle-go | Go code review |
| `review-tui` | beagle-go | BubbleTea TUI code review |
| `review-ios` | beagle-ios | iOS/SwiftUI code review |
| `review-elixir` | beagle-elixir | Elixir/Phoenix code review |

### Documentation & Analysis

| Command | Plugin | Description |
|---------|--------|-------------|
| `draft-docs <prompt>` | beagle-docs | Generate documentation drafts |
| `improve-doc <path>` | beagle-docs | Improve docs using Diataxis |
| `ensure-docs` | beagle-docs | Documentation coverage check |
| `12-factor-apps-analysis` | beagle-analysis | 12-Factor compliance check |
| `llm-judge` | beagle-analysis | Compare implementations |
| `write-adr` | beagle-analysis | Generate ADRs from decisions |

### Testing

| Command | Plugin | Description |
|---------|--------|-------------|
| `gen-test-plan` | beagle-testing | Generate YAML test plan |
| `run-test-plan` | beagle-testing | Execute test plan |
