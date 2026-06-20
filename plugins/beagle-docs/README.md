# beagle-docs

Documentation quality and AI-writing detection, built on Diataxis. Part of the [beagle](https://github.com/existential-birds/beagle) Agent Skills marketplace — see the [full skill catalog](../../SKILLS.md).

## Installation

For any coding agent that supports [Agent Skills](https://agentskills.io):

```bash
npx skills add existential-birds/beagle
```

For Claude Code:

```bash
claude plugin marketplace add https://github.com/existential-birds/beagle
claude plugin install beagle-docs@existential-birds
```

## Skills

| Skill | Description |
|-------|-------------|
| `improve-doc` | Classify an existing markdown doc by Diataxis type and interactively refine each section |
| `draft-docs` | Generate first-draft Tutorial, How-To, Reference, or Explanation docs to `docs/drafts/` from code analysis |
| `ensure-docs` | Verify symbol and Diataxis-balance coverage across a codebase, report gaps, and generate missing docs |
| `review-ai-writing` | Detect AI-generated writing patterns in docs, docstrings, commits, PR descriptions, and code comments |
| `humanize-beagle` | Rewrite AI-generated developer text to sound human, with safe/risky fix classification |
| `docs-style` | Core writing principles for voice, tone, structure, and LLM-friendly patterns |
| `tutorial-docs` | Learning-oriented patterns for guides that teach through guided doing |
| `howto-docs` | Task-oriented patterns for guides that help users reach a specific goal |
| `reference-docs` | Information-oriented patterns for API docs, parameter tables, and technical specs |
| `explanation-docs` | Understanding-oriented patterns for conceptual guides that explain why things work |

### Reference Material

- `docs-style`: the Diataxis compass for choosing the right doc type before writing
- `tutorial-docs`: a complete example tutorial demonstrating all tutorial writing principles
- `review-ai-writing`: reference files covering content, vocabulary, formatting, communication, filler, and code-doc patterns

## See Also

- [beagle-core](../beagle-core) - Shared workflows, verification protocol, and git commands
- [beagle marketplace](https://github.com/existential-birds/beagle) - Full Agent Skills marketplace
