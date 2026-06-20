# beagle-go

Go, BubbleTea, Wish SSH, and Prometheus code review. Part of the [beagle](https://github.com/existential-birds/beagle) Agent Skills marketplace — see the [full skill catalog](../../SKILLS.md).

## Installation

For any coding agent that supports [Agent Skills](https://agentskills.io):

```bash
npx skills add existential-birds/beagle
```

For Claude Code:

```bash
claude plugin marketplace add https://github.com/existential-birds/beagle
claude plugin install beagle-go@existential-birds
```

## Skills

| Skill | Description |
|-------|-------------|
| `review-go` | Comprehensive Go backend code review; detects BubbleTea, Wish SSH, and Prometheus and loads matching review skills |
| `review-tui` | BubbleTea TUI code review with Elm architecture focus across bubbletea, lipgloss, bubbles, and Wish SSH |
| `go-code-review` | Idiomatic patterns, error handling, concurrency safety, generics, errors.Join, slog, and Go 1.22 loop semantics |
| `go-testing-code-review` | Table-driven tests, assertions, mocking, and coverage patterns |
| `bubbletea-code-review` | Elm architecture, model/update/view patterns, and Lipgloss styling |
| `wish-ssh-code-review` | Wish SSH server middleware, session handling, and security patterns |
| `prometheus-go-code-review` | Prometheus metric types, labels, and instrumentation patterns |
| `go-architect` | Go web architecture with net/http 1.22+ routing, project layout, graceful shutdown, and dependency injection |
| `go-web-expert` | Production-quality Go web persona enforcing zero global state, explicit errors, input validation, and testability |
| `go-concurrency-web` | Worker pools, rate limiting, race detection, and safe shared state for high-throughput web apps |
| `go-data-persistence` | Raw SQL with sqlx/pgx, Ent/GORM ORMs, connection pooling, golang-migrate, and transaction management |
| `go-middleware` | HTTP middleware with context propagation, slog logging, centralized error handling, and panic recovery |
| `review-verification-protocol` | Reference: mandatory verification steps loaded before reporting any review findings |

## See Also

- [Skill catalog](../../SKILLS.md) — every skill in the marketplace
- [beagle-core](../beagle-core/README.md) — shared workflows, verification, and git skills
- [beagle marketplace](https://github.com/existential-birds/beagle) — the full Agent Skills marketplace
