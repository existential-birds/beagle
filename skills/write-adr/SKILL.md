---
name: write-adr
description: "Use when generating Architecture Decision Records (ADRs) from a session, extracting architectural decisions from design discussions, formatting decisions with the MADR template, or verifying ADR completeness against E.C.A.D.R. criteria. Triggers on \"write ADRs\", \"write an ADR\", \"format as MADR\", \"document our decisions\", \"create decision records\", \"record the choices we made\", \"extract decisions from this chat\", or \"check ADR quality\". Supports both full session extraction-confirm-write workflows and direct single-ADR creation."
---

# Write ADR

Generate and verify Architecture Decision Records (ADRs) using the MADR 4.0 template and E.C.A.D.R. Definition of Done criteria — either by extracting decisions from the current session or by formatting an already-supplied decision directly.

## Workflow Overview

1. **Context** - Gather repository context and existing ADRs
2. **Extract** - Analyze conversation for decisions (skip Steps 2–3 when the user already supplied the exact decision(s) to write)
3. **Confirm** - Present extracted decisions to user for selection
4. **Write** - Pre-allocate sequence numbers and generate MADR files (in parallel via subagents if supported, otherwise sequentially)
5. **Report** - Summarize created files and status
6. **Verify** - Validate generated ADRs against Definition of Done (`references/definition-of-done.md`)

### Gates (objective pass conditions)

Advance only when the **pass condition** holds. These are checkable without "I verified internally."

| After | Pass condition |
|-------|----------------|
| Step 2 (extract) | Extraction output is **valid JSON** with a top-level `decisions` **array** (empty is OK). Every item has `id` (integer), non-empty `title`, `problem`, `decision`, `confidence` (`high`/`medium`/`low`), `alternatives` (array, `[]` if none), and optional `rationale`/`source_context`. Explicit `[ADR]` tags are all captured (`confidence: "high"`), duplicates merged, and any `low`-confidence item explains why in `source_context`. |
| Step 4 (pre-allocate) | `python3 scripts/next_adr_number.py --count N` (run relative to this skill directory, or `python3 .agents/skills/write-adr/scripts/next_adr_number.py --count N` from repo root) prints **exactly `N` lines** (one number per line). You have a **written mapping** from each confirmed decision to one of those numbers **before** launching any ADR writer unit. |
| Step 4 (context per ADR) | Before drafting each ADR, you record a written list of **≥0** paths under `docs/adrs/` consulted for related/superseded ADRs (or record that `docs/adrs/` is missing/empty) **and** **≥1** repo path for related code (or `N/A` with a one-line reason). |
| Step 5 (report) | Every file path in the summary table is copied from a completed write (optionally verified with `test -f <path>`). |
| Step 6 (verify) | For each ADR path (`docs/adrs/NNNN-slugified-title.md`), line 1 is `---`, YAML frontmatter parses with `status` and `date`, and every E, C, A, D, R item in `references/definition-of-done.md` either passes or has a scoped `[INVESTIGATE: ...]` marker. |

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

This context helps ADR writers reference related commits, avoid duplicate ADRs for already-documented decisions, and verify sequence numbering.

**Direct-ADR entry:** If the user already supplied a specific decision (or asked to format/verify an existing ADR against MADR and E.C.A.D.R.), skip Steps 2–3 and proceed directly to Step 4 using the supplied decision(s).

## Step 2: Extract Decisions

Analyze the current conversation for architectural decisions. **If the agent supports subagents**, dispatch this as a single extraction subagent; **otherwise** run the same extraction inline — identical output.

### Detection Signals & Extraction Rules

| Signal Type | Examples | Confidence Rule |
|-------------|----------|-----------------|
| Explicit markers | `[ADR]`, "decided:", "the decision is" | `[ADR]` tags receive `confidence: "high"` automatically (guaranteed inclusion) |
| Choice patterns | "let's go with X", "we'll use Y", "choosing Z" | `high` if clear choice + rationale; `medium` if implied from action taken |
| Trade-off discussions | "X vs Y", "pros/cons", "considering alternatives" | Combine alternatives and drivers across related mentions |
| Problem-solution pairs | "the problem is... so we'll..." | `low` if inferred contextually without explicit agreement; state what is missing or contradictory in `source_context` |

- **De-duplicate:** Consolidate multiple mentions of the same decision (merge alternatives, combine rationale, keep highest confidence; drop inferred duplicates of an explicit `[ADR]` entry).
- **Brief / Output Schema:**

```json
{
  "decisions": [
    {
      "id": 1,
      "title": "Use PostgreSQL for user data",
      "problem": "Need ACID transactions for financial records",
      "decision": "PostgreSQL for user data storage",
      "alternatives": ["MongoDB", "SQLite"],
      "rationale": "ACID compliance, team familiarity, mature ecosystem",
      "confidence": "high",
      "source_context": "Discussion about database selection in planning phase"
    }
  ]
}
```

If extraction returns an empty `decisions` array, skip to Step 5 with message: `"No architectural decisions detected in this session."`

**Gate:** Meet the Step 2 row in **Gates (objective pass conditions)** before Step 3.

## Step 3: Confirm with User

**Display all extracted decisions with full details**, then ask the user to select:

```text
## Detected Decisions

### 1. Use PostgreSQL for user data
**Confidence:** high

**Problem:** Need ACID transactions for financial records

**Decision:** PostgreSQL for user data storage

**Alternatives discussed:**
- MongoDB
- SQLite

**Rationale:** ACID compliance, team familiarity, mature ecosystem

**Source:** Discussion about database selection in planning phase

---

## Selection

Which decisions should I write ADRs for?
- Enter numbers (e.g., "1,2" or "1-2"), "all", or "none" to skip
```

**Important:** Always display the full decision details (`problem`, `decision`, `alternatives`, `rationale`, `source_context`) BEFORE asking for selection. Do not truncate to just title and context.

Parse user response:
- `"all"` — Process all decisions
- `"none"` or empty — Skip with message `"No ADRs will be created."`
- `"1,2"` or `"1-2"` — Process specified decisions

## Step 4: Write ADRs (Parallel)

**Pre-allocate ADR numbers before launching subagents** to prevent numbering conflicts:

```bash
# Run relative to the write-adr skill directory:
python3 scripts/next_adr_number.py --count N

# Or from the repository root when installed via skills:
python3 .agents/skills/write-adr/scripts/next_adr_number.py --count N
# (Use ~/.agents/skills/write-adr/scripts/next_adr_number.py --count N for global installs)
```

Note: `next_adr_number.py` auto-discovers `docs/adrs`, `docs/adr`, `adr`, `adrs`, `doc/adr`, or `doc/adrs` from the current working directory up to the `.git` root (or pass `--dir <path>`).

**Assign each pre-allocated number to its corresponding decision** before launching writer units.

**Gate:** Meet the Step 4 (pre-allocate) row in **Gates (objective pass conditions)** before launching the first ADR writer unit.

For each confirmed decision, run an ADR writer unit with its **pre-assigned number**. **If the agent supports subagents**, dispatch one writer per decision in parallel; **otherwise** write each ADR sequentially — identical output. Give each writer unit this brief:

```text
Write an ADR for this decision using references/madr-template.md and references/definition-of-done.md in the write-adr skill:
```json
{decision JSON}
```

**IMPORTANT: Use this pre-assigned ADR number: {assigned_number}**

Instructions:
1. Explore codebase for related code and check docs/adrs/ for related or superseded ADRs (meet Step 4 context gate)
2. Read references/madr-template.md and format the ADR in MADR 4.0 structure (imperative title, status: "draft", date: YYYY-MM-DD, Context and Problem Statement, Decision Drivers, Considered Options, Decision Outcome, Consequences)
3. Check against E.C.A.D.R. criteria in references/definition-of-done.md; insert `[INVESTIGATE: ...]` markers for any missing information
4. Use the pre-assigned number {assigned_number} — DO NOT call next_adr_number.py inside this writer unit
5. Write to docs/adrs/{assigned_number}-slugified-title.md (lowercase, hyphens, no special characters) and confirm line 1 is `---` with valid YAML frontmatter
6. Return the created file path and any `[INVESTIGATE]` gaps
```

**Critical:** Pass the pre-allocated number to each writer unit. Writers must NOT invoke `next_adr_number.py` themselves — this prevents duplicate sequence numbers when running in parallel.

Wait for all writer units to complete before proceeding.

## Step 5: Report Results

**Gate:** Meet the Step 5 row in **Gates (objective pass conditions)** when building the summary (paths from completed writes; optionally verify with `test -f`).

Collect outputs from all writer units and present summary:

```markdown
## ADR Generation Complete

| File | Decision | Status |
|------|----------|--------|
| docs/adrs/0003-use-postgresql-for-user-data.md | Use PostgreSQL for user data | Draft |

### Next Steps
- Review generated ADRs for accuracy
- Resolve any `[INVESTIGATE: ...]` markers before advancing status from `draft` to `proposed`
- Update status from `"proposed"` to `"accepted"` when finalized

### Gaps Requiring Investigation
- [List any decisions where missing context required `[INVESTIGATE]` markers]
```

If no decisions were processed:
```text
No ADRs were created. Run this workflow again after making architectural decisions.
```

## Step 6: Verify Generated ADRs

For each created ADR, validate against `references/definition-of-done.md`:

```markdown
## Verification Checklist

| ADR | E | C | A | D | R | Status |
|-----|---|---|---|---|---|--------|
| 0003-use-postgresql-for-user-data.md | ✓ | ✓ | ✓ | ⚠ | ✗ | Incomplete |

Legend: E=Explicit problem statement, C=Comprehensive options analysis, A=Actionable decision, D=Documented consequences, R=Reviewable by stakeholders
```

**Gate:** Meet the Step 6 row in **Gates (objective pass conditions)** for every created ADR.

**Verification steps:**
1. Open each generated ADR file
2. Confirm filename follows `NNNN-slugified-title.md` pattern
3. **Verify YAML frontmatter exists at file start:**
   - File MUST begin with `---` on line 1
   - Contains `status: "draft"` (or another valid MADR status)
   - Contains `date: YYYY-MM-DD` (actual date)
   - Ends with `---` before title
4. Review for `[INVESTIGATE: ...]` markers — keep status as `"draft"` until resolved
5. Verify at least 2 options are documented (or `[INVESTIGATE]` marker added)
6. Confirm Consequences includes both Good and Bad tradeoffs

## Output Location

ADRs are written to `docs/adrs/` (`NNNN-slugified-title.md`). If no ADR directory exists, create `docs/adrs/` (optionally seeding with an initial `0000-use-madr.md` record).

## Reference Files

- [references/madr-template.md](references/madr-template.md) — Official MADR 4.0 template structure, frontmatter rules, and minimal template
- [references/definition-of-done.md](references/definition-of-done.md) — E.C.A.D.R. quality criteria, `[INVESTIGATE]` guidance, and status progression
- `scripts/next_adr_number.py` — Sequence number allocator supporting `--list`, `--dir`, and `--count N`
