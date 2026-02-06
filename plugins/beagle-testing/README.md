# beagle-testing

Language-agnostic test plan generation and execution for [Claude Code](https://claude.ai/code). Part of the [beagle](https://github.com/existential-birds/beagle) plugin marketplace.

## Installation

```bash
# Add the marketplace (if not already added)
claude plugin marketplace add https://github.com/existential-birds/beagle

# Install the plugin
claude plugin install beagle-testing@existential-birds
```

## Commands

| Command | Usage | Description |
|---------|-------|-------------|
| **gen-test-plan** | `/beagle-testing:gen-test-plan` | Generate an executable YAML test plan from branch changes, focused on user-facing impact |
| **run-test-plan** | `/beagle-testing:run-test-plan` | Execute a YAML test plan, stopping on first failure with rich debug output |

`gen-test-plan` diffs the current branch against a base branch (default: `main`), traces changes to user-facing entry points, and outputs a structured YAML test plan. Pass `--base <branch>` to change the base.

`run-test-plan` runs setup commands, health checks, and each test sequentially. On failure, it produces a detailed debug prompt. Pass `--plan <path>` to specify a custom plan file. Browser tests require the `agent-browser:agent-browser` skill.

## See Also

- [beagle-core](../beagle-core) - Shared workflows, verification protocol, and git commands
- [beagle marketplace](https://github.com/existential-birds/beagle) - Full plugin marketplace with 10 focused plugins
