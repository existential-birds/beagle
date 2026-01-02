---
description: Generate ADRs from decisions made in the current session. Extracts decisions, confirms with user, writes MADR-formatted documents.
---

# Write ADR

Generate Architecture Decision Records (ADRs) from decisions made during the current session.

## Workflow Overview

1. **Context** - Gather repository context and existing ADRs
2. **Extract** - Analyze conversation for decisions using a subagent
3. **Confirm** - Present decisions to user for selection
4. **Write** - Generate ADRs in parallel using subagents
5. **Report** - Summarize created files and status
6. **Verify** - Validate generated ADRs against Definition of Done

## Step 1: Gather Context

```bash
# Get current branch and recent commits
git branch --show-current
git log --oneline -5

# Check for existing ADRs
ls docs/adrs/ 2>/dev/null || echo "No ADR directory found"

# Count existing ADRs for numbering
find docs/adrs -name "*.md" 2>/dev/null | wc -l
```

This context helps the ADR writer:
- Reference related commits in the ADR
- Avoid duplicate ADRs for already-documented decisions
- Determine correct sequence numbering

## Step 2: Extract Decisions

Launch a subagent to analyze the current conversation for architectural decisions:

```text
Task(
  description: "Analyze conversation and extract architectural decisions",
  model: "sonnet",
  prompt: |
    Load the skill: Skill(skill: "beagle:adr-decision-extraction")

    Analyze the conversation for decisions that warrant ADRs:
    - Technology choices, architecture patterns, design trade-offs
    - Rejected alternatives, significant implementation approaches

    Return JSON:
    {
      "decisions": [
        {
          "id": 1,
          "title": "Use PostgreSQL for primary datastore",
          "context": "Brief context about why this came up",
          "decision": "What was decided",
          "alternatives": ["What was considered but rejected"],
          "rationale": "Why this choice was made"
        }
      ]
    }
)
```

If the subagent returns an empty `decisions` array, skip to Step 5 with message: "No architectural decisions detected in this session."

## Step 3: Confirm with User

Present extracted decisions using `AskUserQuestion`:

```text
## Detected Decisions

1. **Use PostgreSQL for primary datastore**
   Context: Discussed during data modeling phase

2. **Implement event sourcing for audit trail**
   Context: Required for compliance requirements

Which decisions should I write ADRs for?
- Enter numbers (e.g., "1,3" or "1-3"), "all", or "none" to skip
```

Parse user response:
- `"all"` - Process all decisions
- `"none"` or empty - Skip with message "No ADRs will be created."
- `"1,3"` or `"1-3"` - Process specified decisions

## Step 4: Write ADRs (Parallel)

For each confirmed decision, launch an ADR Writer subagent in background:

```text
Task(
  description: "Write ADR for: {decision.title}",
  model: "sonnet",
  run_in_background: true,
  prompt: |
    Load the skill: Skill(skill: "beagle:adr-writing")

    Write an ADR for this decision:
    ```json
    {decision JSON}
    ```

    Instructions:
    1. Explore codebase for additional context
    2. Write MADR-formatted ADR to docs/adr/
    3. Use sequential numbering (check existing ADRs)
    4. Return created file path
)
```

All subagents run in parallel. Wait for all to complete before proceeding.

## Step 5: Report Results

Collect outputs from all subagents and present summary:

```markdown
## ADR Generation Complete

| File | Decision | Status |
|------|----------|--------|
| docs/adr/0003-use-postgresql.md | Use PostgreSQL for primary datastore | Draft |

### Next Steps
- Review generated ADRs for accuracy
- Update status from "proposed" to "accepted" when finalized

### Gaps Requiring Investigation
- [List any decisions where subagent noted missing context]
```

If no decisions were processed:
```text
No ADRs were created. Run this command again after making architectural decisions.
```

## Step 6: Verify Generated ADRs

For each created ADR, validate against Definition of Done:

```markdown
## Verification Checklist

| ADR | E | C | A | D | R | Status |
|-----|---|---|---|---|---|--------|
| 0003-use-postgresql.md | ✓ | ✓ | ✓ | ⚠ | ✗ | Incomplete |

Legend: E=Evidence, C=Criteria, A=Agreement, D=Documentation, R=Realization
```

**Verification steps:**
1. Open each generated ADR file
2. Confirm filename follows `NNNN-slugified-title.md` pattern
3. Check frontmatter has `status: draft` and `date`
4. Review for `[INVESTIGATE]` prompts - these need follow-up
5. Verify at least 2 alternatives are documented
6. Confirm consequences section has both Good and Bad items

**If gaps exist:**
- Keep status as `draft` until gaps are resolved
- Use `[INVESTIGATE]` prompts to guide follow-up session
- Schedule review with stakeholders before changing to `accepted`

## Output Location

ADRs are written to `docs/adr/`. If no ADR directory exists, create it with an initial `0000-use-madr.md` template record.

## MADR Format Reference

```markdown
# {NUMBER}. {TITLE}

Date: {YYYY-MM-DD}

## Status
Proposed

## Context
{What is the issue motivating this decision?}

## Decision
{What change are we proposing/doing?}

## Consequences
{What becomes easier or harder?}
```
