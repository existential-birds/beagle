# Beagle - Claude Code Plugin

Technology knowledge bases and development workflows for React, Python, Go, AI frameworks, and more.

## What it does

Extends Claude Code with specialized skills and commands for:

- **Frontend development**: React Flow, React Router v7, Tailwind v4, shadcn/ui, Zustand
- **Backend development**: Python, FastAPI, SQLAlchemy, Postgres, Pydantic AI
- **Go development**: BubbleTea TUI, Wish SSH, Lipgloss, Prometheus
- **AI frameworks**: LangGraph, Vercel AI SDK
- **Testing**: Vitest, pytest, Go testing
- **Code review**: Technology-specific review checklists and patterns
- **Git workflows**: Commit, push, PR creation, release notes

## Installation

1. Open your Claude Code settings file at `~/.claude/settings.json` (create it if it doesn't exist)

2. Add the marketplace URL:

```json
{
  "marketplaces": [
    "https://github.com/anderskev/beagle"
  ]
}
```

3. Restart Claude Code and install the plugin:

```
/plugin install beagle
```

See the [Claude Code settings documentation](https://docs.claude.com/en/docs/claude-code/settings) for more details on configuration.

## Skills

Skills are model-invoked. Claude uses them automatically when relevant.

### Frontend

| Skill | Triggers |
|-------|----------|
| `react-flow` | Graph visualization, workflow nodes, custom edges |
| `react-router-v7` | Routing, loaders, actions, navigation |
| `tailwind-v4` | Styling, theming, dark mode |
| `shadcn-ui` | Component library, CVA variants |
| `zustand-state` | State management, middleware |
| `dagre-react-flow` | Auto-layout for graphs |

### Backend (Python)

| Skill | Triggers |
|-------|----------|
| `python-code-review` | Type hints, async patterns, error handling |
| `fastapi-code-review` | Endpoints, dependencies, validation |
| `sqlalchemy-code-review` | ORM patterns, relationships, queries |
| `postgres-code-review` | Postgres-specific patterns, JSONB, GIN |
| `pytest-code-review` | Test patterns, fixtures, mocking |

### Backend (Go)

| Skill | Triggers |
|-------|----------|
| `go-code-review` | Error handling, concurrency, interfaces |
| `bubbletea-code-review` | TUI patterns, Model/Update/View, Lipgloss |
| `wish-ssh-code-review` | SSH server, middleware, sessions |
| `prometheus-go-code-review` | Metrics, labels, instrumentation |
| `go-testing-code-review` | Table-driven tests, mocking, parallel tests |

### AI Frameworks

| Skill | Triggers |
|-------|----------|
| `pydantic-ai-*` | Agent creation, tools, dependency injection, testing |
| `langgraph-*` | Graph architecture, implementation patterns |
| `vercel-ai-sdk` | Streaming, use-chat, tools |

### Utilities

| Skill | Triggers |
|-------|----------|
| `vitest-testing` | Test configuration, mocking patterns |
| `docling` | Document parsing, chunking |
| `sqlite-vec` | Vector search, embeddings |
| `github-projects` | Project management via GraphQL |
| `ai-elements` | AI visualization components |
| `receive-feedback` | Processing code review feedback |
| `agent-architecture-analysis` | Analyzing agent system architecture |
| `12-factor-apps` | 12-Factor App compliance patterns |

## Commands

Commands are user-invoked with `/beagle:<command>`.

### Code review

```
/beagle:review-backend
```
Reviews Python/FastAPI backend code. Detects technologies and loads relevant skills automatically.

```
/beagle:review-frontend
```
Reviews React/TypeScript frontend code with similar detection and loading.

```
/beagle:review-go
```
Reviews Go backend code. Detects BubbleTea, Wish, Prometheus and loads relevant skills.

```
/beagle:review-tui
```
Reviews BubbleTea TUI code with focus on Elm architecture patterns.

```
/beagle:review-plan <path/to/plan.md>
```
Reviews implementation plans before execution using 5 parallel agents analyzing parallelization, TDD adherence, type/API verification, library practices, and security.

Options for all review commands:
- `--parallel`: Spawn specialized subagents per technology area

### Git workflows

```
/beagle:commit-push
```
Commits staged changes and pushes to remote.

```
/beagle:create-pr
```
Creates a pull request with standardized description template.

```
/beagle:gen-release-notes <tag>
```
Generates release notes for changes since a given tag.

### Skill development

```
/beagle:skill-builder
```
Creates Claude Code skills following official best practices.

### Code analysis

```
/beagle:12-factor-apps-analysis
```
Analyzes codebase for 12-Factor App compliance.

```
/beagle:receive-feedback path/to/feedback.md
```
Processes code review feedback with verification-first discipline.

### PR feedback

```
/beagle:fetch-pr-feedback [--bot <username>] [--pr <number>]
```
Fetches bot review comments from a PR and evaluates them. Defaults to CodeRabbit.

```
/beagle:respond-pr-feedback [--bot <username>] [--pr <number>] [--as <username>]
```
Posts replies to bot review comments and prompts to resolve threads.

## Using with Cursor IDE

The commands are also available for Cursor IDE. These are expanded versions with all skill content embedded, designed for Cursor's agent mode.

### Setup

Copy the `.cursor/commands/` folder to your project root:

```bash
# From your project directory
curl -L https://github.com/anderskev/beagle/archive/refs/heads/main.tar.gz | tar -xz --strip-components=1 beagle-main/.cursor
```

Or clone and copy:

```bash
git clone --depth 1 https://github.com/anderskev/beagle.git /tmp/beagle
cp -r /tmp/beagle/.cursor .
rm -rf /tmp/beagle
```

### Usage

In Cursor, type `/` in the Agent chat input to invoke commands:

| Command | Description |
|---------|-------------|
| `/review-backend` | Python/FastAPI code review |
| `/review-frontend` | React/TypeScript code review |
| `/review-go` | Go code review |
| `/review-tui` | BubbleTea TUI code review |
| `/review-plan` | Review implementation plans |
| `/commit-push` | Conventional commit and push |
| `/create-pr` | Create PR with template |
| `/gen-release-notes` | Generate changelog |
| `/skill-builder` | Create new skills |
| `/12-factor-apps-analysis` | 12-Factor compliance check |
| `/receive-feedback` | Process code review feedback |
| `/fetch-pr-feedback` | Fetch bot review comments |
| `/respond-pr-feedback` | Reply to bot comments |

### Updating

To get the latest commands:

```bash
# Re-run the setup command to overwrite with latest
curl -L https://github.com/anderskev/beagle/archive/refs/heads/main.tar.gz | tar -xz --strip-components=1 beagle-main/.cursor
```

## Repository structure

```text
beagle/
├── .claude-plugin/
│   └── plugin.json       # Plugin manifest
├── .cursor/
│   └── commands/         # Cursor IDE commands
├── commands/             # Claude Code slash commands
├── skills/               # Technology knowledge bases
│   ├── react-flow/
│   ├── python-code-review/
│   ├── fastapi-code-review/
│   ├── go-code-review/
│   ├── bubbletea-code-review/
│   └── ...
└── docs/                 # Documentation
```

## Adding skills

Each skill follows this structure:

```text
skill-name/
├── SKILL.md              # Required: main skill file
└── references/           # Optional: supporting docs
    ├── topic-a.md
    └── topic-b.md
```

See `/beagle:skill-builder` for guided skill creation.

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

[MIT](LICENSE)
