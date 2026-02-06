# beagle-core

Shared code review workflows, verification protocol, git commands, and feedback handling for [Claude Code](https://claude.ai/code). Part of the [beagle](https://github.com/existential-birds/beagle) plugin marketplace. Recommended as a base for all beagle plugins.

## Installation

```bash
# Add the marketplace (if not already added)
claude plugin marketplace add https://github.com/existential-birds/beagle

# Install the plugin
claude plugin install beagle-core@existential-birds
```

## Commands

| Command | Usage | Description |
|---------|-------|-------------|
| **commit-push** | `/beagle-core:commit-push` | Commit and push all local changes using Conventional Commits format |
| **create-pr** | `/beagle-core:create-pr` | Create a pull request with a standardized description template |
| **review-plan** | `/beagle-core:review-plan` | Review implementation plans for parallelization, TDD, types, libraries, and security |
| **review-llm-artifacts** | `/beagle-core:review-llm-artifacts` | Detect common LLM coding agent artifacts by spawning 4 parallel subagents |
| **fix-llm-artifacts** | `/beagle-core:fix-llm-artifacts` | Apply fixes from a prior review-llm-artifacts run with safe/risky classification |
| **receive-feedback** | `/beagle-core:receive-feedback` | Process code review feedback from a file with verification-first discipline |
| **fetch-pr-feedback** | `/beagle-core:fetch-pr-feedback` | Fetch bot review comments from a PR and evaluate with receive-feedback skill |
| **respond-pr-feedback** | `/beagle-core:respond-pr-feedback` | Post replies to bot review comments after evaluation and fixes |
| **gen-release-notes** | `/beagle-core:gen-release-notes` | Generate release notes for changes since a given tag |
| **skill-builder** | `/beagle-core:skill-builder` | Create Claude Code skills with comprehensive best practices and patterns |
| **prompt-improver** | `/beagle-core:prompt-improver` | Optimize prompts for code-related tasks following Claude best practices |

## Skills

| Skill | Description |
|-------|-------------|
| **review-verification-protocol** | Mandatory verification steps for all code reviews to reduce false positives |
| **receive-feedback** | Process external code review feedback with technical rigor and verification-first discipline |
| **review-feedback-schema** | Schema for tracking code review outcomes to enable feedback-driven skill improvement |
| **review-skill-improver** | Analyzes feedback logs to identify patterns and suggest improvements to review skills |
| **llm-artifacts-detection** | Detects common LLM coding agent artifacts: test quality issues, dead code, over-abstraction, and verbose style |
| **github-projects** | GitHub Projects (v2) management via gh CLI for items, fields, and workflows |
| **docling** | Document parser for PDF, DOCX, PPTX, HTML, images, and 15+ formats with RAG chunking support |
| **sqlite-vec** | sqlite-vec extension for vector similarity search, KNN queries, and semantic search in SQLite |

### Reference Material

Each skill with a `references/` directory includes detailed reference documents:

**llm-artifacts-detection**: dead code criteria, test quality criteria, abstraction criteria, style criteria

**receive-feedback**: skill integration patterns

**github-projects**: project items management, custom fields

**docling**: output formats, parsing options, chunking strategies, batch processing

**sqlite-vec**: table setup, query patterns, vector operations, configuration

## See Also

- [beagle marketplace](https://github.com/existential-birds/beagle) - Full plugin marketplace with 10 focused plugins
