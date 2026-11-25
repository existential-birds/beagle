---
name: improve-doc
description: "Audit and refactor markdown documentation using Diataxis principles — classify sections, split mixed types, preserve skipped sections verbatim, and survey repo-level doc-set balance. Use when improving existing docs, separating mixed tutorials, how-tos, reference, or explanations, or checking documentation type coverage."
---

# Improve Doc

Audit markdown documentation against [Diataxis](https://diataxis.fr/) boundaries: classify sections, split mixed types, interactively refine issues while preserving skipped sections verbatim, or run a repo-level doc-set balance check.

## Usage

- **Single document audit (default):** `improve-doc <path/to/doc.md>`
- **Repo-level balance check:** `improve-doc --balance [docs_root]` — surveys a project's prose documentation (`docs/`, `README.md`, wiki) for Diataxis type balance without creating empty skeletons.

## Gates

Advance only when each **pass condition** is met via concrete artifacts or explicit user input — never skip ahead.

**Before Phase 2 (refinement):**
1. **Read** — Load full contents of the target file. **Pass:** Enumerated `#` / `##` / `###` sections cover every heading in the file with exact titles.
2. **Compass** — Read [references/diataxis-compass.md](references/diataxis-compass.md) before classifying. **Pass:** Analysis applies the two compass axes (*action vs. cognition*, *acquisition vs. application*) and the per-type boundary rules below.
3. **Handoff** — Present the Analysis summary and require explicit **`start`** or **`abort`**. **Pass:** If `abort`, exit with zero writes; if `start`, proceed to Phase 2.

**Before overwriting the target file (Phase 2, Step 3):**
1. **Choices** — Every section with open issues has a terminal outcome: **`yes`**, **`skip`**, or a completed **`modify`** loop ending in **`yes`** or **`skip`**. **Pass:** Zero sections left pending.
2. **Skips** — Every **`skip`** section matches the original text verbatim. **Pass:** Line-for-line block equality (including whitespace) against the initial read.
3. **Write** — **Pass:** Single save to the target path after all choices resolve, followed by the completion summary (noting a backup/git recovery hint if major restructuring occurred).

**Ambiguous Diataxis type:** When classification confidence is `< 70%`, ask the clarifying fork before editing that section unless the user explicitly confirms your stated default.

## Per-Type Boundary & Style Rules

Read [references/diataxis-compass.md](references/diataxis-compass.md) for the 2x2 map and disambiguation tests, then enforce these boundaries:

| Type | Core Rules & Boundary | Disallowed Drift (Flag as Issues) |
|------|-------------------------|-----------------------------------|
| **Tutorial** | Learning-oriented (`"In this tutorial, we'll..."`). One clear path, minimal prerequisites, action-first steps, observable `"You should see..."` outcomes after each step. | Explaining *why* in depth, offering branching alternatives (`"or yarn/pnpm"`), skipping beginner steps. |
| **How-To** | Task-oriented (`"How to <goal>"`). States prerequisites, uses conditional imperatives (`"If X, do Y"`), one atomic action per step, concrete verification & troubleshooting. | Architectural tangents, multi-action bundled steps, missing verification of success. |
| **Reference** | Lookup-oriented (`"Describe, and only describe"`). Structure mirrors product/API, consistent scannable tables (types, required/optional, defaults), complete runnable examples with realistic values. | Narrative prose, tutorials/steps, explanations of *why*, missing parameter types/returns/errors. |
| **Explanation** | Understanding-oriented (`"Why..."`, trade-offs, design rationale). Discursive prose read away from the keyboard; analogies, constraints, alternatives considered; informed opinion permitted. | Procedural step-by-step instructions, parameter/API lookup tables, neutral refusal to state trade-offs. |

**Cross-cutting quality principles (all types):**
- Use second person (`"you"`) and active voice (tutorials may frame the shared journey with `"we"`).
- Keep one term per concept (no synonym cycling) and state prerequisites explicitly so pages are self-contained.
- Provide complete, runnable code examples (imports + realistic placeholders, not `foo`/`bar`).
- Flag walls of text, skipped heading levels (`h1 -> h3`), and vague headings.

---

## Mode 1: Single Document Audit & Refinement

### Phase 1: Analysis

1. **Read & parse document:** Load the file and capture every `#`, `##`, `###` heading, level, line span, and verbatim body.
2. **Load compass:** Read [references/diataxis-compass.md](references/diataxis-compass.md).
3. **Classify each section:** Assign **Tutorial**, **How-To**, **Reference**, **Explanation**, or **Mixed** (when a section blends two types, e.g., tutorial framing + reference table). Use title clues (`"How to..."`, `"Why..."`), structural patterns (tables vs. numbered steps), and language (*"let's learn"* vs. *"to accomplish"*).
4. **Identify issues with line references:** Check each section against the Per-Type Boundary & Style Rules table above.
5. **Present Analysis Summary:**

```markdown
## Document Analysis

**File:** `<path>`
**Sections found:** <count>

### Type Breakdown
| Type | Sections | Health |
|------|----------|--------|
| Tutorial | <n> | <status> |
| How-To | <n> | <status> |
| Reference | <n> | <status> |
| Explanation | <n> | <status> |
| Mixed | <n> | Needs split |

### Top Issues
1. **Section "<title>"** (<type>, lines <a-b>): <concise issue list>

Type **start** to begin refinement, or **abort** to exit without changes.
```

Wait for **`start`** or **`abort`** before entering Phase 2.

### Phase 2: Interactive Refinement

1. **Iterate sections with issues in document order:** For each section:
   - Display section index (`Section i of N: "<title>" (<type>)`), quoted current content, and numbered issues with line references.
   - **If classification confidence `< 70%`:** Ask a quick clarifying question listing the candidate types (or **Split** first if mixed) and wait for choice.
   - **If `Mixed`:** Always offer **Split** (create separate pure sections in logical reading order) as option **1**, followed by keeping only one pure type (e.g., **2. `<Type A>` only**, **3. `<Type B>` only**).
   - **Present Proposed Improvement:** Show the rewritten/split section (diff-style or blockquote) and bulleted summary of changes, then prompt:
     `**Your choice:** [yes / skip / modify]`
   - **Handle choice:**
     - `yes`: Record accepted text and advance to next section.
     - `skip`: Record original section verbatim (zero changes) and advance.
     - `modify`: Incorporate the user's feedback into a revised proposal and re-prompt `[yes / skip / modify]` until resolved to `yes` or `skip`.
2. **Verify before write:** Confirm every flagged section resolved to `yes` or `skip` and every `skip` section matches the initial read line-for-line.
3. **Write & Report:** Save the updated document in a single write, then summarize changes (table of `Section | Action (Improved / Split / Skipped) | Type`), new sections created, recommended follow-up docs for extracted off-type content, and a note reminding the user of git recovery if major restructuring occurred.

---

## Mode 2: Diataxis Type Balance Check (`--balance`)

Use when surveying a repository's documentation set (`docs/`, `README.md`, wiki, or doc site) rather than refactoring a single file.

1. Survey existing prose docs and classify each using [references/diataxis-compass.md](references/diataxis-compass.md) (*action or cognition? acquisition or application?*).
2. Report the balance table:

| Type | Present? | Notes |
|------|----------|-------|
| **Tutorial** (learning) | yes / no / thin | e.g. "No getting-started / first-project guide" |
| **How-To** (tasks) | yes / no / thin | e.g. "Task guides under `docs/how-to/`" |
| **Reference** (lookup) | yes / no / thin | e.g. "API reference exists, no CLI reference" |
| **Explanation** (understanding) | yes / no / thin | e.g. "No architecture / design-rationale docs" |

3. Flag gaps in priority order:
   1. **Missing type** — doc set serves none of that user need (a missing **Tutorial** is the most common high-impact gap).
   2. **Thin type** — present but omits major features or surfaces.
   3. **Mixed documents** — single pages blending two types; recommend running **Mode 1** of this skill on those files to split them.
4. **Avoid empty skeletons:** Do **not** propose creating empty placeholder trees for missing types. Following the Diataxis *"work by improvement"* principle, recommend the **single highest-value document** to add or refactor next.

## Rules

- Follow **Gates** strictly before entering Phase 2 and before writing to disk
- Read [references/diataxis-compass.md](references/diataxis-compass.md) before classifying sections or surveying doc balance
- Preserve sections marked **`skip`** line-for-line verbatim
- Always offer **Split** as the first option for **`Mixed`** sections
- Iterate on **`modify`** feedback until the user selects **`yes`** or **`skip`**
- Never propose empty skeleton doc trees during `--balance` checks
