# beagle

![Apollo 10 astronaut Thomas P. Stafford pats the nose of a stuffed Snoopy](assets/Stafford_and_Snoopy.jpg)

*Image: NASA, Public Domain. [Source](https://www.nasa.gov/multimedia/imagegallery/image_feature_572.html)*

Code review skills and verification workflows for Python, Go, React, and AI frameworks. Designed to complement [superpowers](https://github.com/obra/superpowers).

## Installation

```bash
claude plugin marketplace add https://github.com/existential-birds/beagle && claude plugin install beagle
```

To update: `claude plugin update beagle`

## Skills

Auto-loaded by Claude when relevant. See [Agent Skills](https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview).

| Category | Skills |
|----------|--------|
| **Frontend** | react-flow-\*, react-router-\*, tailwind-v4, shadcn-\*, zustand-state, dagre-react-flow, vitest-testing, ai-elements |
| **Backend (Python)** | python-code-review, fastapi-code-review, sqlalchemy-code-review, postgres-code-review, pytest-code-review, docling, sqlite-vec |
| **Backend (Go)** | go-code-review, go-testing-code-review, bubbletea-code-review, wish-ssh-code-review, prometheus-go-code-review |
| **AI Frameworks** | pydantic-ai-\* (6), langgraph-\* (3), vercel-ai-sdk, deepagents-\* (3) |
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
| `review-plan <path>` | Review implementation plans |
| `review-llm-artifacts` | Detect LLM coding artifacts |
| `fix-llm-artifacts` | Fix detected artifacts |
| `commit-push` | Commit and push changes |
| `create-pr` | Create PR with template |
| `gen-release-notes <tag>` | Generate release notes |
| `write-adr` | Generate ADRs from decisions |
| `12-factor-apps-analysis` | 12-Factor compliance check |
| `receive-feedback <path>` | Process review feedback |
| `fetch-pr-feedback` | Fetch bot comments from PR |
| `respond-pr-feedback` | Reply to bot comments |
| `ensure-docs` | Documentation coverage check |
| `skill-builder` | Create new skills |
| `prompt-improver` | Optimize prompts |

## Cursor IDE

Copy commands to your project:

```bash
curl -L https://github.com/existential-birds/beagle/archive/refs/heads/main.tar.gz | tar -xz --strip-components=1 beagle-main/.cursor
```

## Troubleshooting

**"Marketplace file not found"**: Remove stale entries from `~/.claude/plugins/known_marketplaces.json` and restart Claude Code.
