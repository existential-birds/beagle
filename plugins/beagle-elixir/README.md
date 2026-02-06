# beagle-elixir

Elixir, Phoenix, and LiveView code review skills for [Claude Code](https://claude.ai/code). Part of the [beagle](https://github.com/existential-birds/beagle) plugin marketplace.

## Installation

```bash
# Add the marketplace (if not already added)
claude plugin marketplace add https://github.com/existential-birds/beagle

# Install the plugin
claude plugin install beagle-elixir@existential-birds
```

## Commands

| Command | Usage | Description |
|---------|-------|-------------|
| **review-elixir** | `/beagle-elixir:review-elixir` | Comprehensive Elixir/Phoenix code review with automatic framework detection |

Reviews changed `.ex`, `.exs`, and `.heex` files against `main`. Runs `mix format --check-formatted` and Credo (if configured) before flagging style issues. Use `--parallel` to spawn specialized subagents per technology area.

## Skills

| Skill | Description |
|-------|-------------|
| **elixir-code-review** | Idiomatic patterns, OTP basics, and documentation |
| **phoenix-code-review** | Controller patterns, context boundaries, routing, and plugs |
| **liveview-code-review** | Lifecycle patterns, assigns/streams, components, and security |
| **exunit-code-review** | Test patterns, boundary mocking with Mox, and test adapters |
| **elixir-security-review** | Code injection, atom exhaustion, secret handling, process exposure |
| **elixir-performance-review** | GenServer bottlenecks, ETS patterns, memory, and concurrency |
| **review-verification-protocol** | Mandatory verification steps to reduce false positives |

### Reference Material

Each review skill includes detailed reference documents:

**elixir-code-review**: code style, pattern matching, OTP basics, documentation

**phoenix-code-review**: contexts, controllers, routing, plugs

**liveview-code-review**: lifecycle, assigns/streams, components, security

**exunit-code-review**: ExUnit patterns, Mox boundaries, test adapters, integration tests

**elixir-security-review**: code injection, atom exhaustion, secrets, process exposure

**elixir-performance-review**: GenServer bottlenecks, ETS patterns, memory, concurrency

## See Also

- [beagle-core](../beagle-core) - Shared workflows, verification protocol, and git commands
- [beagle marketplace](https://github.com/existential-birds/beagle) - Full plugin marketplace with 10 focused plugins
