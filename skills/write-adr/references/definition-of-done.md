# Definition of Done: E.C.A.D.R. Criteria

An ADR is complete when it meets all five E.C.A.D.R. criteria.

## E.C.A.D.R. Checklist

### E - Explicit Problem Statement

| Check | Criteria |
|-------|----------|
| [ ] | Context describes a real, specific problem |
| [ ] | Problem is scoped (not too broad, not too narrow) |
| [ ] | Constraints and requirements are stated |
| [ ] | Reader understands WHY a decision is needed |

**Anti-patterns:**
- "We need to choose a database" (too vague)
- Problem buried in decision outcome section
- Missing business or technical context

### C - Comprehensive Options Analysis

| Check | Criteria |
|-------|----------|
| [ ] | At least 2 options considered |
| [ ] | Options are genuinely viable (not strawmen) |
| [ ] | Each option has pros AND cons listed |
| [ ] | "Do nothing" considered if applicable |

**Anti-patterns:**
- Single option presented as foregone conclusion
- Options listed without analysis
- Missing obvious alternatives

### A - Actionable Decision

| Check | Criteria |
|-------|----------|
| [ ] | Chosen option is clearly stated |
| [ ] | Decision is specific enough to implement |
| [ ] | Rationale links to decision drivers |
| [ ] | No ambiguity about what was decided |

**Anti-patterns:**
- "We will use a modern approach" (vague)
- Decision contradicts stated constraints
- Missing implementation guidance

### D - Documented Consequences

| Check | Criteria |
|-------|----------|
| [ ] | Good consequences listed |
| [ ] | Bad consequences listed (honest tradeoffs) |
| [ ] | Operational impacts considered |
| [ ] | Future implications noted |

**Anti-patterns:**
- Only positive consequences (overselling)
- Generic consequences that apply to any option
- Missing security, performance, or cost impacts

### R - Reviewable by Stakeholders

| Check | Criteria |
|-------|----------|
| [ ] | Status is set appropriately |
| [ ] | Decision-makers are identified |
| [ ] | Language is accessible (not jargon-heavy) |
| [ ] | Sufficient context for outsiders to understand |

**Anti-patterns:**
- Missing metadata (date, status, authors)
- Assumes reader context not in document
- Dense technical prose without summaries

## Quality Rubric

| Score | Criteria Met | Status |
|-------|--------------|--------|
| 5/5 | All E.C.A.D.R. criteria | Ready for `proposed` |
| 4/5 | One minor gap | Add `[INVESTIGATE]` prompt |
| 3/5 | Two gaps | Needs revision before proposing |
| 2/5 | Major gaps | Incomplete draft |
| 1/5 | Minimal content | Placeholder only |

## Using [INVESTIGATE] Prompts

When a criterion cannot be met from available information, insert an investigation prompt:

```markdown
## Decision Drivers

* Performance under 100ms response time
* [INVESTIGATE: Confirm budget constraints with finance team]
* Compatibility with existing Python stack
```

These prompts:
1. Signal incomplete sections
2. Document what information is missing
3. Enable async follow-up
4. Prevent premature status advancement

## Status Progression

```
draft ──▶ proposed ──▶ accepted
  │          │
  │          ▼
  │       rejected
  │
  └──▶ [fix gaps, remove INVESTIGATE prompts]
```

Do not advance to `proposed` until all `[INVESTIGATE]` prompts are resolved.

## Review Checklist

Final pass before marking `proposed`:

- [ ] No `[INVESTIGATE]` prompts remain
- [ ] All E.C.A.D.R. criteria checked
- [ ] File named correctly (`NNNN-slugified-title.md`)
- [ ] Frontmatter complete (status, date, decision-makers)
- [ ] Links to related ADRs if superseding/related
