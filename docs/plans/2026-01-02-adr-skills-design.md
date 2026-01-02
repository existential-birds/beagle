# ADR Skills and Command Design

Design for `/write-adr` command and supporting skills to generate Architectural Decision Records from session decisions.

## Overview

The `/write-adr` command enables users to capture architectural decisions made during a Claude Code session as formal ADRs following the MADR (Markdown ADR) template.

## Architecture

```
beagle/
├── commands/
│   └── write-adr.md                    # Orchestrator command
│
└── skills/
    ├── adr-decision-extraction/
    │   └── SKILL.md                    # Decision extraction patterns
    │
    └── adr-writing/
        ├── SKILL.md                    # Writing workflow
        ├── madr-template.md            # Official MADR template
        ├── definition-of-done.md       # E.C.A.D.R. checklist
        └── scripts/
            └── next_adr_number.py      # Sequence number utility
```

## Command Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                     /write-adr Command                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. EXTRACT                                                     │
│     └─► Launch Decision Extractor subagent                      │
│         • Has access to current conversation context            │
│         • Loads adr-decision-extraction skill                   │
│         • Returns: List of candidate decisions                  │
│                                                                 │
│  2. CONFIRM                                                     │
│     └─► Present candidates to user                              │
│         "Found 3 potential decisions:                           │
│          1. Use PostgreSQL for user data                        │
│          2. Adopt feature flags for rollout                     │
│          3. Choose monorepo structure                           │
│          Which should I document? (e.g., 1,3 or all)"           │
│                                                                 │
│  3. WRITE (parallel)                                            │
│     └─► For each confirmed decision:                            │
│         Launch ADR Writer subagent                              │
│         • Loads adr-writing skill                               │
│         • Explores codebase for context                         │
│         • Writes to docs/adrs/NNNN-slug.md                      │
│         • Status: draft (with gap instructions)                 │
│                                                                 │
│  4. REPORT                                                      │
│     └─► Summary of created ADRs with file paths                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. Decision Extractor Skill

**Purpose:** Identify architectural decisions from conversation context.

**Detection signals:**

| Signal Type | Examples |
|-------------|----------|
| Explicit markers | `[ADR]`, "decided:", "the decision is" |
| Choice patterns | "let's go with X", "we'll use Y", "choosing Z" |
| Trade-off discussions | "X vs Y", "pros/cons", "considering alternatives" |
| Problem-solution pairs | "the problem is... so we'll..." |

**Output format:**

```json
{
  "decisions": [
    {
      "title": "Use PostgreSQL for user data",
      "problem": "Need ACID transactions for financial records",
      "chosen_option": "PostgreSQL",
      "alternatives_discussed": ["MongoDB", "SQLite"],
      "drivers": ["ACID compliance", "team familiarity"],
      "confidence": "high"
    }
  ]
}
```

**Key behaviors:**
- Explicit `[ADR]` tags are always included (guaranteed)
- AI-detected decisions require confidence assessment
- Captures surrounding context for the writer

### 2. ADR Writing Skill

**Purpose:** Generate MADR-formatted ADRs with Definition of Done validation.

**Structure:**
```
adr-writing/
├── SKILL.md              # ~200 lines: workflow, quick start
├── madr-template.md      # Official template (verbatim from GitHub)
├── definition-of-done.md # E.C.A.D.R. criteria + gap instructions
└── scripts/
    └── next_adr_number.py
```

**Workflow:**
1. Run `python scripts/next_adr_number.py` to get sequence number
2. Explore codebase for additional context (related code, existing ADRs)
3. Load madr-template.md
4. Fill sections from decision data
5. Apply definition-of-done.md checklist
6. Mark unfilled sections with `[INVESTIGATE: ...]` prompts
7. Write to `docs/adrs/NNNN-slugified-title.md`
8. Set frontmatter status: `draft`

### 3. Definition of Done (E.C.A.D.R.)

Each ADR is validated against five criteria:

| Criterion | Description |
|-----------|-------------|
| **E**vidence | Design demonstrated to satisfy requirements |
| **C**riteria | At least 2 alternatives compared |
| **A**greement | Peer/team review documented |
| **D**ocumentation | All MADR sections completed |
| **R**ealization | Implementation scheduled |

**Gap handling:** When a criterion cannot be satisfied from available context, the ADR includes investigation prompts:

```markdown
## Decision Drivers

* Performance requirements for API response times
* [INVESTIGATE: Review PR #42 discussion for additional drivers]
* [INVESTIGATE: Check with team lead on compliance requirements]
```

These prompts guide a future LLM session to complete the ADR.

### 4. File Naming Convention

- **Pattern:** `NNNN-slugified-title.md`
- **Example:** `0003-use-postgresql-for-user-data.md`
- **Slug rules:** lowercase, hyphens, max 50 characters
- **Location:** `docs/adrs/` (created automatically if missing)

### 5. Utility Script

`next_adr_number.py` scans existing ADRs and returns the next sequence number:

```bash
$ python scripts/next_adr_number.py --path docs/adrs
0005
```

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| Two-stage subagent pipeline | Separates conversation context (extractor) from codebase context (writer) |
| Interactive confirmation | User controls which decisions become ADRs |
| Parallel ADR writers | Multiple decisions processed concurrently |
| Draft status with gap instructions | Pragmatic—captures what's known, guides completion |
| Sequential numbering (0001-) | Standard ADR convention, easy ordering |
| Progressive disclosure in skills | MADR template and DoD loaded only when needed |

## References

- [ADR GitHub Organization](https://adr.github.io/)
- [MADR Template](https://github.com/adr/madr)
- [ADR Definition of Done](https://www.ozimmer.ch/practices/2020/05/22/ADDefinitionOfDone.html)
- [MADR Template Primer](https://www.ozimmer.ch/practices/2022/11/22/MADRTemplatePrimer.html)
- [How to Create ADRs](https://www.ozimmer.ch/practices/2023/04/03/ADRCreation.html)

## Implementation Checklist

- [ ] Create `skills/adr-decision-extraction/SKILL.md`
- [ ] Create `skills/adr-writing/SKILL.md`
- [ ] Create `skills/adr-writing/madr-template.md`
- [ ] Create `skills/adr-writing/definition-of-done.md`
- [ ] Create `skills/adr-writing/scripts/next_adr_number.py`
- [ ] Create `commands/write-adr.md`
- [ ] Test with sample session containing decisions
- [ ] Update CLAUDE.md with new command/skills
