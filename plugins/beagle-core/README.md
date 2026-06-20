# beagle-core

Language-agnostic developer workflows shared across every beagle plugin: commit and push, open pull requests, generate release notes, review implementation plans and repo structure, detect and fix LLM coding artifacts, process PR and reviewer feedback, and build new skills. Part of the [beagle](https://github.com/existential-birds/beagle) Agent Skills marketplace — see the [full skill catalog](../../SKILLS.md).

## Installation

For any coding agent that supports [Agent Skills](https://agentskills.io):

```bash
npx skills add existential-birds/beagle
```

For Claude Code:

```bash
claude plugin marketplace add https://github.com/existential-birds/beagle
claude plugin install beagle-core@existential-birds
```

## Skills

| Skill | Description |
|-------|-------------|
| `commit-push` | Commit and push all local changes using Conventional Commits format |
| `create-pr` | Create a pull request with a standardized description template |
| `gen-release-notes` | Generate release notes for changes since a given tag |
| `review-plan` | Review implementation plans for parallelization, TDD, types, libraries, and security before execution |
| `review-structure` | Repo-wide structural-maintainability review — code-judo restructurings, 1k-line file guard, anti-spaghetti branching, canonical-layer enforcement, anti-magic abstractions, explicit type and boundary contracts |
| `review-skill` | Review PRs that add or modify Agent Skills for structural validity, design quality, and marketplace consistency |
| `skill-builder` | Create Agent Skills with best-practice structure, references, validation, and testing |
| `subagent-prompt` | Hand off the current session's work to a fresh session as a portable orchestrator-plus-subagents prompt with per-task verification |
| `prompt-improver` | Optimize prompts for code-related tasks following prompt-engineering best practices |
| `receive-feedback` | Process external code review feedback with verification-first discipline, verifying claims before implementing and tracking disposition |
| `fetch-pr-feedback` | Fetch unresolved review comments from a PR and evaluate them with the `receive-feedback` skill |
| `respond-pr-feedback` | Post replies to PR review comments after evaluation and fixes |
| `review-llm-artifacts` | Scan for LLM coding-agent artifacts across tests, dead code, abstraction, and style — changed files by default, `--all` for full-project |
| `verify-llm-artifacts` | Adjudicate `review-llm-artifacts` findings as confirmed, false positive, or inconclusive before deletes |
| `fix-llm-artifacts` | Apply fixes from a prior `review-llm-artifacts` run with safe/risky classification, respecting verification output |
| `llm-artifacts-detection` | Reference: detection criteria for test quality, dead code, over-abstraction, and verbose LLM style |
| `review-verification-protocol` | Reference: mandatory verification steps loaded before reporting any code review findings |
| `review-feedback-schema` | Reference: schema for tracking code review outcomes to enable feedback-driven skill improvement |
| `review-skill-improver` | Reference: analyzes feedback logs to surface patterns and suggest improvements to review skills |

## See Also

- [Skill catalog](../../SKILLS.md) — every skill in the marketplace
- [beagle marketplace](https://github.com/existential-birds/beagle) — the full Agent Skills marketplace
