# beagle

![Apollo 10 astronaut Thomas P. Stafford pats the nose of a stuffed Snoopy](assets/Stafford_and_Snoopy.jpg)

*Image: NASA, Public Domain. [Source](https://www.nasa.gov/multimedia/imagegallery/image_feature_572.html)*

A Claude Code plugin for code review and verification workflows. Catch issues before you push with pre-commit reviews for Python, Go, Elixir, React, iOS/Swift, and AI frameworks.

Powers the agents in [Amelia](https://github.com/existential-birds/amelia). For automated review-fix-test loops, see [Daydream](https://github.com/existential-birds/daydream).

## Installation

**Prerequisites:**
- [Claude Code](https://claude.ai/code) CLI installed
- [agent-browser](https://github.com/vercel-labs/agent-browser) for `run-test-plan` command (optional)

```bash
claude plugin marketplace add https://github.com/existential-birds/beagle
claude plugin install beagle
```

Verify installation by running `/beagle:` in Claude Code—you should see the command list.

To update: `claude plugin update beagle`

**Troubleshooting:**
- "Marketplace file not found": Remove stale entries from `~/.claude/plugins/known_marketplaces.json` and restart Claude Code.
- Plugin not updating: Run `claude plugin marketplace update beagle` to refresh the marketplace, then `claude plugin update beagle`.

### Other Agents

Use the [skills CLI](https://skills.sh/docs/cli) to install beagle skills for other AI agents:

```bash
npx skills add existential-birds/beagle
```

This downloads the skills and configures them for your agent. Commands (`/beagle:*`) are Claude Code specific and not available through the skills CLI.

## Skills

Auto-loaded by Claude when relevant. See [Agent Skills](https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview).

| Category | Skills |
|----------|--------|
| **Frontend** | react-flow-\*, react-router-\*, tailwind-v4, shadcn-\*, zustand-state, dagre-react-flow, vitest-testing, ai-elements |
| **Backend (Python)** | python-code-review, fastapi-code-review, sqlalchemy-code-review, postgres-code-review, pytest-code-review, docling, sqlite-vec |
| **Backend (Go)** | go-code-review, go-testing-code-review, bubbletea-code-review, wish-ssh-code-review, prometheus-go-code-review |
| **Backend (Elixir)** | elixir-code-review, elixir-performance-review, elixir-security-review, phoenix-code-review, liveview-code-review, exunit-code-review |
| **iOS/Swift** | swift-code-review, swiftui-code-review, swiftdata-code-review, combine-code-review, urlsession-code-review, healthkit-code-review, cloudkit-code-review, watchos-code-review, widgetkit-code-review, app-intents-code-review, swift-testing-code-review |
| **AI Frameworks** | pydantic-ai-\* (6), langgraph-\* (3), vercel-ai-sdk, deepagents-\* (3) |
| **Documentation** | docs-style, tutorial-docs, howto-docs, reference-docs, explanation-docs |
| **Workflow** | receive-feedback, review-feedback-schema, review-skill-improver, llm-artifacts-detection |
| **Architecture** | 12-factor-apps, agent-architecture-analysis, adr-\*, github-projects |

## Commands

Run with `/beagle:<command>`. See [Slash commands](https://docs.claude.com/en/docs/claude-code/slash-commands).

| Command | Description |
|---------|-------------|
| `review-python` | Python/FastAPI code review |
| `review-frontend` | React/TypeScript code review |
| `review-go` | Go code review |
| `review-tui` | BubbleTea TUI code review |
| `review-ios` | iOS/SwiftUI code review |
| `review-elixir` | Elixir/Phoenix code review |
| `review-plan <path>` | Review implementation plans |
| `review-llm-artifacts` | Detect LLM coding artifacts |
| `fix-llm-artifacts` | Fix detected artifacts |
| `gen-test-plan` | Generate YAML test plan from branch changes |
| `run-test-plan` | Execute test plan, stop on first failure |
| `commit-push` | Commit and push changes |
| `create-pr` | Create PR with template |
| `gen-release-notes <tag>` | Generate release notes |
| `write-adr` | Generate ADRs from decisions |
| `draft-docs <prompt>` | Generate documentation drafts |
| `improve-doc <path>` | Improve docs using Diátaxis |
| `12-factor-apps-analysis` | 12-Factor compliance check |
| `receive-feedback <path>` | Process review feedback |
| `fetch-pr-feedback` | Fetch bot comments from PR |
| `respond-pr-feedback` | Reply to bot comments |
| `ensure-docs` | Documentation coverage check |
| `skill-builder` | Create new skills |
| `prompt-improver` | Optimize prompts |

