# beagle-elixir

Elixir, Phoenix, LiveView, ExUnit, and ExDoc code review. Part of the [beagle](https://github.com/existential-birds/beagle) Agent Skills marketplace — see the [full skill catalog](../../SKILLS.md).

## Installation

For any coding agent that supports [Agent Skills](https://agentskills.io):

```bash
npx skills add existential-birds/beagle
```

For Claude Code:

```bash
claude plugin marketplace add https://github.com/existential-birds/beagle
claude plugin install beagle-elixir@existential-birds
```

## Skills

| Skill | Description |
|-------|-------------|
| `review-elixir` | Comprehensive Elixir/Phoenix review with framework detection and optional parallel subagents |
| `elixir-code-review` | Idiomatic patterns, OTP basics, and module documentation |
| `phoenix-code-review` | Controller patterns, context boundaries, routing, and plugs |
| `liveview-code-review` | Lifecycle patterns, assigns/streams, components, and security |
| `exunit-code-review` | Test patterns, boundary mocking with Mox, and test adapters |
| `elixir-performance-review` | GenServer bottlenecks, ETS patterns, memory, and concurrency |
| `elixir-security-review` | Code injection, atom exhaustion, secret handling, and process exposure |
| `elixir-docs-review` | Documentation completeness, @spec coverage, and doctest correctness |
| `elixir-writing-docs` | Writing @moduledoc, @doc, @typedoc, doctests, cross-references, and metadata |
| `exdoc-config` | ExDoc setup: mix.exs config, extras, groups, cheatsheets, and livebooks |
| `review-verification-protocol` | Reference: mandatory verification steps to reduce false positives |

## See Also

- [beagle-core](../beagle-core) - Shared workflows, verification protocol, and git commands
- [beagle marketplace](https://github.com/existential-birds/beagle) - Full Agent Skills marketplace
