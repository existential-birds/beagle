---
name: adr-writing
description: Write Architectural Decision Records following MADR template. Applies Definition of Done criteria, marks gaps for later completion. Use when generating ADR documents from extracted decisions.
---

# ADR Writing

## Overview

Generate Architectural Decision Records (ADRs) following the MADR template with systematic completeness checking.

## Quick Reference

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│  SEQUENCE   │ ──▶ │   EXPLORE    │ ──▶ │    FILL     │
│  (get next  │     │  (context,   │     │  (template  │
│   number)   │     │   ADRs)      │     │   sections) │
└─────────────┘     └──────────────┘     └─────────────┘
       │                                        │
       │                                        ▼
       │                                 ┌─────────────┐
       │                                 │   VERIFY    │
       │                                 │  (DoD       │
       └─────────────────────────────────│   checklist)│
                                         └─────────────┘
```

## When To Use

- Documenting architectural decisions from extracted requirements
- Converting meeting notes or discussions to formal ADRs
- Recording technical choices from PR discussions
- Creating decision records from design documents

## Workflow

### Step 1: Get Sequence Number

```bash
python scripts/next_adr_number.py
```

This outputs the next available ADR number (e.g., `0003`).

### Step 2: Explore Context

Before writing, gather additional context:

1. **Related code** - Find implementations affected by this decision
2. **Existing ADRs** - Check `docs/adrs/` for related or superseded decisions
3. **Discussion sources** - PRs, issues, or documents referenced in decision

### Step 3: Load Template

Load `references/madr-template.md` for the official MADR structure.

### Step 4: Fill Sections

Populate each section from your decision data:

| Section | Source |
|---------|--------|
| Title | Decision summary (imperative mood) |
| Status | Always `draft` initially |
| Context | Problem statement, constraints |
| Decision Drivers | Prioritized requirements |
| Considered Options | All viable alternatives |
| Decision Outcome | Chosen option with rationale |
| Consequences | Good, bad, neutral impacts |

### Step 5: Apply Definition of Done

Load `references/definition-of-done.md` and verify E.C.A.D.R. criteria:

- **E**xplicit problem statement
- **C**omprehensive options analysis
- **A**ctionable decision
- **D**ocumented consequences
- **R**eviewable by stakeholders

### Step 6: Mark Gaps

For sections that cannot be filled from available data, insert investigation prompts:

```markdown
* [INVESTIGATE: Review PR #42 discussion for additional drivers]
* [INVESTIGATE: Confirm with security team on compliance requirements]
* [INVESTIGATE: Benchmark performance of Option 2 vs Option 3]
```

These prompts signal incomplete sections for later follow-up.

### Step 7: Write File

Save to `docs/adrs/NNNN-slugified-title.md`:

```
docs/adrs/0003-use-postgresql-for-user-data.md
docs/adrs/0004-adopt-event-sourcing-pattern.md
docs/adrs/0005-migrate-to-kubernetes.md
```

### Step 8: Set Status

In frontmatter, always set initial status:

```yaml
status: draft
```

## File Naming Convention

Format: `NNNN-slugified-title.md`

| Component | Rule |
|-----------|------|
| `NNNN` | Zero-padded sequence number from script |
| `-` | Separator |
| `slugified-title` | Lowercase, hyphens, no special characters |
| `.md` | Markdown extension |

## Reference Files

- `references/madr-template.md` - Official MADR template structure
- `references/definition-of-done.md` - E.C.A.D.R. quality criteria

## Output Example

```markdown
---
status: draft
date: 2024-01-15
decision-makers: [alice, bob]
---

# Use PostgreSQL for User Data Storage

## Context and Problem Statement

We need a database for user account data...

## Decision Drivers

* Data integrity requirements
* Query flexibility needs
* [INVESTIGATE: Confirm scaling projections with infrastructure team]

## Considered Options

* PostgreSQL
* MongoDB
* CockroachDB

## Decision Outcome

Chosen option: PostgreSQL, because...

## Consequences

### Good

* ACID compliance ensures data integrity

### Bad

* Requires more upfront schema design

### Neutral

* Team has moderate PostgreSQL experience
```
