# beagle-docs

Documentation quality, generation, and improvement using [Diataxis](https://diataxis.fr/) principles for [Claude Code](https://claude.ai/code). Part of the [beagle](https://github.com/existential-birds/beagle) plugin marketplace.

## Installation

```bash
# Add the marketplace (if not already added)
claude plugin marketplace add https://github.com/existential-birds/beagle

# Install the plugin
claude plugin install beagle-docs@existential-birds
```

## Commands

| Command | Usage | Description |
|---------|-------|-------------|
| **draft-docs** | `/beagle-docs:draft-docs` | Generate first-draft technical documentation from code analysis. Outputs Reference or How-To drafts to `docs/drafts/` for review before publishing. |
| **improve-doc** | `/beagle-docs:improve-doc` | Analyze an existing markdown document, classify sections by Diataxis type, identify issues, and interactively refine each section. |
| **ensure-docs** | `/beagle-docs:ensure-docs` | Verify documentation coverage across a codebase, report gaps, and interactively generate missing documentation. |
| **review-ai-writing** | `/beagle-docs:review-ai-writing` | Detect AI-generated writing patterns in docs, docstrings, commits, PR descriptions, and code comments using parallel subagents. |
| **humanize** | `/beagle-docs:humanize` | Apply fixes from a prior review-ai-writing run to humanize AI-generated developer text with safe/risky classification. |

## Skills

| Skill | Description |
|-------|-------------|
| **docs-style** | Core technical documentation writing principles for voice, tone, structure, and LLM-friendly patterns |
| **tutorial-docs** | Tutorial patterns for learning-oriented guides that teach through guided doing |
| **howto-docs** | How-To guide patterns for task-oriented guides for users with specific goals |
| **explanation-docs** | Explanation documentation patterns for understanding-oriented content: conceptual guides that explain why things work the way they do |
| **reference-docs** | Reference documentation patterns for API and symbol documentation, parameter tables, and technical specifications |
| **review-ai-writing** | Detect AI-generated writing patterns in developer text: inflated language, filler phrases, tautological docs, chat leaks, and robotic tone |
| **humanize** | Rewrite AI-generated developer text to sound human: fix strategies by category with safe/risky classification and developer voice guidelines |

### Reference Material

**tutorial-docs**: complete example tutorial (Weather API Integration) demonstrating all tutorial writing principles

**review-ai-writing**: 6 reference files covering content, vocabulary, formatting, communication, filler, and code docs patterns

## See Also

- [beagle-core](../beagle-core) - Shared workflows, verification protocol, and git commands
- [beagle marketplace](https://github.com/existential-birds/beagle) - Full plugin marketplace with 10 focused plugins
