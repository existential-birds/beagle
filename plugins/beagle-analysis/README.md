# beagle-analysis

Architecture analysis, 12-Factor compliance, ADR generation, and LLM-as-judge comparison for [Claude Code](https://claude.ai/code). Part of the [beagle](https://github.com/existential-birds/beagle) plugin marketplace.

## Installation

```bash
# Add the marketplace (if not already added)
claude plugin marketplace add https://github.com/existential-birds/beagle

# Install the plugin
claude plugin install beagle-analysis@existential-birds
```

## Commands

| Command | Usage | Description |
|---------|-------|-------------|
| **12-factor-apps-analysis** | `/beagle-analysis:12-factor-apps-analysis` | Perform 12-Factor App compliance analysis on a codebase |
| **llm-judge** | `/beagle-analysis:llm-judge` | Compare code implementations across 2+ repos using LLM-as-judge methodology with weighted scoring |
| **write-adr** | `/beagle-analysis:write-adr` | Generate ADRs from decisions made in the current session |

## Skills

| Skill | Description |
|-------|-------------|
| **12-factor-apps** | 12-Factor App compliance analysis for evaluating application architecture and auditing SaaS applications |
| **adr-decision-extraction** | Extract architectural decisions from conversations, identifying problem-solution pairs and trade-off discussions |
| **adr-writing** | Write Architectural Decision Records following the MADR template with Definition of Done criteria |
| **agent-architecture-analysis** | 12-Factor Agents compliance analysis for evaluating agent architecture and LLM-powered systems |
| **llm-judge** | LLM-as-judge methodology for comparing code implementations using weighted rubrics across functionality, security, test quality, overengineering, and dead code |

### Reference Material

The **adr-writing** skill includes references for:

- `madr-template.md`: MADR (Markdown Any Decision Records) template structure
- `definition-of-done.md`: E.C.A.D.R. criteria checklist for ADR completeness

The **llm-judge** skill includes references for:

- `fact-schema.md`: JSON schema for structured facts gathered by repo agents
- `judge-agents.md`: Instructions for Phase 2 scoring agents
- `repo-agent.md`: Instructions for Phase 1 fact-gathering agents
- `scoring-rubrics.md`: Detailed 1-5 rubrics for each judging dimension

## See Also

- [beagle-core](../beagle-core) - Shared workflows, verification protocol, and git commands
- [beagle marketplace](https://github.com/existential-birds/beagle) - Full plugin marketplace with 10 focused plugins
