# beagle-analysis

Pre-code thinking and decision tools: brainstorm a fuzzy idea into a spec, write ADRs, run strategy interviews, turn specs into TDD implementation plans, research the web with citations, audit agent architectures against 12-Factor Agents, and compare implementations with LLM-as-judge. Part of the [beagle](https://github.com/existential-birds/beagle) Agent Skills marketplace — see the [full skill catalog](../../SKILLS.md).

## Installation

For any coding agent that supports [Agent Skills](https://agentskills.io):

```bash
npx skills add existential-birds/beagle
```

For Claude Code:

```bash
claude plugin marketplace add https://github.com/existential-birds/beagle
claude plugin install beagle-analysis@existential-birds
```

## Skills

| Skill | Description |
|-------|-------------|
| `prfaq-beagle` | Working Backwards PRFAQ gauntlet that pressure-tests a concept to a binary pass/fail, handing survivors to brainstorm-beagle |
| `brainstorm-beagle` | Shapes a fuzzy idea into a WHAT/WHY project spec through structured dialogue |
| `resolve-beagle` | Closes open questions and latent gaps in a brainstorm spec, rewriting it implementation-ready |
| `write-plan` | Turns a finalized spec into a bite-sized, TDD-driven implementation plan with exact paths and commands |
| `quick-plan` | Produces the same TDD-driven plan from the conversation when no spec exists, fanning out exploration subagents |
| `write-adr` | Orchestrates the full extract-confirm-write ADR workflow from the current session |
| `adr-writing` | Writes and quality-checks an ADR using the MADR template and E.C.A.D.R. Definition of Done |
| `adr-decision-extraction` | Mines a conversation or transcript for architectural decisions, trade-offs, and technology choices |
| `strategy-interview` | Builds a strategy via guided conversation using the kernel framework and complementary lenses |
| `strategy-review` | Pressure-tests an existing strategy document across seven dimensions for gaps and hidden failure paths |
| `web-research` | Gathers cited, multi-angle web evidence via parallel subagents into an on-disk synthesis report |
| `artifact-analysis` | Scans local docs and project knowledge into a cited, structured extraction on disk |
| `agent-architecture-analysis` | Audits an agent codebase against the 12-Factor Agents methodology with file-level evidence |
| `llm-judge` | Compares two or more implementations against a spec using weighted rubrics and structured scoring |

## See Also

- [Skill catalog](../../SKILLS.md) — every skill in the marketplace
- [beagle-core](../beagle-core/README.md) — shared workflows, verification, and git skills
- [beagle marketplace](https://github.com/existential-birds/beagle) — the full Agent Skills marketplace
