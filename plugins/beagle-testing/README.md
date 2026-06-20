# beagle-testing

Generate and execute language-agnostic end-to-end test plans: detect the stack, trace branch changes to user-facing flows, and run them step by step — including browser tests via [agent-browser](https://github.com/vercel-labs/agent-browser). Part of the [beagle](https://github.com/existential-birds/beagle) Agent Skills marketplace — see the [full skill catalog](../../SKILLS.md).

## Installation

For any coding agent that supports [Agent Skills](https://agentskills.io):

```bash
npx skills add existential-birds/beagle
```

For Claude Code:

```bash
claude plugin marketplace add https://github.com/existential-birds/beagle
claude plugin install beagle-testing@existential-birds
```

## Prerequisites

Browser tests require the optional [agent-browser](https://github.com/vercel-labs/agent-browser) CLI tool to be available on `PATH`

## Skills

| Skill | Description |
|-------|-------------|
| `gen-test-plan` | Detect the stack, trace branch changes to user-facing entry points, and generate an executable E2E YAML test plan |
| `run-test-plan` | Execute a YAML test plan sequentially, stopping on first failure with a rich debug prompt |

## See Also

- [Skill catalog](../../SKILLS.md) — every skill in the marketplace
- [beagle-core](../beagle-core/README.md) — shared workflows, verification, and git skills
- [beagle marketplace](https://github.com/existential-birds/beagle) — the full Agent Skills marketplace
