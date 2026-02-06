# beagle-go

Go, BubbleTea TUI, Wish SSH, and Prometheus code review skills for [Claude Code](https://claude.ai/code). Part of the [beagle](https://github.com/existential-birds/beagle) plugin marketplace.

## Installation

```bash
# Add the marketplace (if not already added)
claude plugin marketplace add https://github.com/existential-birds/beagle

# Install the plugin
claude plugin install beagle-go@existential-birds
```

## Commands

| Command | Usage | Description |
|---------|-------|-------------|
| **review-go** | `/beagle-go:review-go` | Comprehensive Go backend code review with optional parallel agents |
| **review-tui** | `/beagle-go:review-tui` | BubbleTea TUI code review with Elm architecture focus |

Both commands review changed `.go` files against `main`, detect frameworks in use, and load appropriate skills. Use `--parallel` to spawn specialized subagents per technology area.

## Skills

| Skill | Description |
|-------|-------------|
| **go-code-review** | Idiomatic patterns, error handling, concurrency safety, and common mistakes |
| **go-testing-code-review** | Table-driven tests, assertions, mocking, and coverage patterns |
| **bubbletea-code-review** | Elm architecture, model/update/view patterns, and Lipgloss styling |
| **wish-ssh-code-review** | Wish SSH server middleware, session handling, and security patterns |
| **prometheus-go-code-review** | Prometheus metric types, labels, naming conventions, and instrumentation |
| **review-verification-protocol** | Mandatory verification steps to reduce false positives |

### Reference Material

Each review skill includes detailed reference documents:

**go-code-review**: error handling, concurrency, interfaces, common mistakes

**go-testing-code-review**: test structure, mocking

**bubbletea-code-review**: Elm architecture, model/update, view/styling, composition, Bubbles components

**wish-ssh-code-review**: server setup/middleware, session handling/security

## See Also

- [beagle-core](../beagle-core) - Shared workflows, verification protocol, and git commands
- [beagle marketplace](https://github.com/existential-birds/beagle) - Full plugin marketplace with 10 focused plugins
