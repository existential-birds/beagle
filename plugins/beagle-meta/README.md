# beagle-meta

Skill authoring and review tools for [Claude Code](https://claude.ai/code). Part of the [beagle](https://github.com/existential-birds/beagle) plugin marketplace.

## Installation

```bash
# Add the marketplace (if not already added)
claude plugin marketplace add https://github.com/existential-birds/beagle

# Install the plugin
claude plugin install beagle-meta@existential-birds
```

## Commands

| Command | Usage | Description |
|---------|-------|-------------|
| **skill-builder** | `/beagle-meta:skill-builder` | Create Claude Code skills with best practices, structure, validation, and testing |
| **review-skill** | `/beagle-meta:review-skill` | Reviews PRs that add or modify Claude Code skills, checking structural validity, design quality, and marketplace consistency |

`skill-builder` guides you through designing, writing, and validating a new skill. It covers requirements gathering, SKILL.md structure, reference files, frontmatter validation, and trigger testing.

`review-skill` diffs the current branch against a base branch (default: `main`), identifies changed skill files, and runs structural, design, and marketplace checks. Pass `--base <branch>` to change the base. Output is written to a path provided as the first argument.

## See Also

- [beagle-core](../beagle-core) - Shared workflows, verification protocol, and git commands
- [beagle marketplace](https://github.com/existential-birds/beagle) - Full plugin marketplace with 12 focused plugins
