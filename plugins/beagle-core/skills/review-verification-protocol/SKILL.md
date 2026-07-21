---
name: review-verification-protocol
description: Mandatory verification steps for all code reviews to reduce false positives. Load this skill before reporting ANY code review findings.
user-invocable: false
---

# Review Verification Protocol

The language-neutral core followed before reporting any code review finding. Skipping these steps leads to false positives that waste developer time and erode trust in reviews.

Each language plugin ships a **thin delta** under the same skill name, carrying only its own false-positive patterns and valid-pattern tables. Load this core plus the delta for the stack under review; the delta never restates what is here.

## Imported vocabulary

This protocol imports [verification-budget](../verification-budget/SKILL.md). Those definitions are authoritative — this file does not restate them:

- **Risk tier.** Reporting a finding is `verification-budget` tier REVERSIBLE: cite the evidence you already have and move on. Only a verdict that authorizes an IRREVERSIBLE action (deleting code, rewriting a file, rewriting history) earns the full evidence gate.
- **One-echo.** Echo the artifact under review — the diff, the finding table, the file:line and its code — **once, at review entry**. Not once per verdict. A downstream stage in the same review pipeline trusts the upstream echo rather than re-reading to re-derive it. The single exception is the staleness re-read immediately before an IRREVERSIBLE action.
- **Prove-a-negative ban.** Never claim or demand exhaustive absence. Report the enumerated patterns you searched, or a fixed-size sample and its size.

Never infer what you are reviewing from the branch name, working directory, surrounding files, or recollection. Where your mental model differs from the source you read, the source wins.

## Hard gates (sequence)

Apply **once per finding** before it may appear in the review. If a gate fails, **omit** the finding, **downgrade** to Informational (per [Severity Calibration](#severity-calibration)), or **rephrase** as a question — do not ship soft accusations.

| Step | What you do | Pass condition (objective) |
|------|----------------|----------------------------|
| **1. Anchor** | Read the full enclosing symbol or module, not only the diff hunk. | You can state **file path** and **line range** (or symbol name + file) you are judging. |
| **2. Evidence** | For this finding's type, run the checks in [Verification by Issue Type](#verification-by-issue-type). | Each required check has an **artifact**: pasted tool output, **file:line** citation, or a **"N matches"** count naming the patterns searched — not a claim you "looked." |
| **3. Severity** | Assign severity using [Severity Calibration](#severity-calibration). | Label matches the table; requests for net-new code that did not exist in scope are **Informational** only. |
| **4. Format** | Draft the finding for the report. | Matches `[FILE:LINE] ISSUE_TITLE`; Informational items do not add to the actionable count. |

**Loop budget:** max **1** pass per finding. Stop when all four gate outputs are recorded for that finding. Tie-break: drop or downgrade the finding and proceed — never re-run the gates hoping for a cleaner answer.

Style-only or preference items must fail gate 2 or map to **Do NOT Flag At All** — they do not get a severity.

## Pre-Report Verification Checklist

These items are **what gate 2 must produce evidence for**. They are an enumerated check list, not an advance gate: record the outcome of each, then proceed.

- [ ] **I read the actual code** — not just the diff context, but the full function/class/module
- [ ] **I searched for usages** — before claiming "unused", ran the enumerated reference search below
- [ ] **I checked surrounding code** — the issue may be handled elsewhere (guards, earlier checks, callers)
- [ ] **I verified syntax against current docs** — framework and language syntax evolves
- [ ] **I distinguished "wrong" from "different style"** — both approaches may be valid
- [ ] **I considered intentional design** — comments, project conventions (AGENTS.md, CLAUDE.md), architectural context

## Verification by Issue Type

### "Unused Variable/Function"

Search these **four** reference patterns and report each result with its count:

1. Direct call or reference to the identifier
2. Re-export, barrel entry, or public module surface
3. String-literal or dynamic reference (reflection, decorators, selectors, registries, config)
4. Framework-invoked contract (callback, lifecycle hook, trait/protocol/interface member)

Report as "no matches across the 4 enumerated patterns" — never as "unused anywhere."

### "Missing Validation/Error Handling"

**Before flagging**, check:
1. Whether validation exists at a higher level (caller, middleware, route handler, supervisor)
2. Whether the framework or type system already enforces it
3. Whether the "missing" check is present in a different form

**Common false positives:** the framework already validates; a parent validates before delegating; a single higher-level handler catches for the whole path.

### "Type Assertion/Unsafe Cast"

**Before flagging**, check:
1. It is actually an assertion, not an annotation
2. The type is not already narrowed by a runtime check upstream
3. The framework does not guarantee the type at that boundary

### "Potential Memory Leak/Race Condition"

**Before flagging**, check:
1. Cleanup is genuinely absent, not merely in a different location
2. Cancellation or teardown is not handled after the async boundary
3. The lifetime overlap that would cause the bug is actually reachable

### "Performance Issue"

**Before flagging**, check:
1. The code runs often enough to matter (render/hot loop vs one-off handler)
2. The optimization would have measurable impact
3. The runtime, compiler, or framework does not already handle it

**Do NOT flag:** one-off allocations in event handlers, linear work on small collections without evidence of scale, or object creation outside a hot path.

## Severity Calibration

### Critical (Block Merge)

**ONLY use for:** security vulnerabilities (injection, auth bypass, data exposure); data corruption; crash-causing bugs in the happy path; breaking changes to public APIs.

### Major (Should Fix)

**Use for:** logic bugs affecting functionality; missing error handling that degrades UX; performance issues with measurable impact; accessibility violations.

### Minor (Consider Fixing)

**Use for:** code clarity; documentation gaps; inconsistent style (within reason); non-critical test coverage gaps.

### Informational (No Action Required)

**Use for:** improvements requiring new dependencies or modules; suggestions for net-new code that did not exist before; architectural ideas for future consideration; test infrastructure suggestions; optimizations without measurable impact in the current context.

**These are NOT review blockers.** Note them for the author's awareness, but they must not appear in the actionable issue count, and the Verdict ignores them entirely.

### Do NOT Flag At All

- Style preferences where both approaches are valid
- Optimizations with no measurable benefit
- Test code not meeting production standards (intentionally simpler)
- Library, vendored, or generated code
- Hypothetical issues that require unlikely conditions

## Valid Patterns (Do NOT Flag)

Language-specific tables live in each plugin's delta. Universally valid:

| Pattern | Why It's Valid |
|---------|----------------|
| `+?` lazy quantifier in regex | Prevents over-matching, correct for many patterns |
| Direct string concatenation | Simpler than interpolation for simple cases |
| Multiple returns in a function | Can improve readability |
| Comments explaining "why" | Better than no comments |

## Before Submitting Review

**Budget:** exactly **one** pass over the finding list. Stop when every finding has an answer for items 1–7. Tie-break: any finding you still cannot answer for ships as a **question**, or is dropped — do not re-run the pass.

1. Re-read each finding: did you verify this is actually an issue?
2. Can you point to the specific line that proves the issue exists?
3. Would a domain expert agree this is a problem, or is it a style preference?
4. Does fixing this provide real value, or is it busywork?
5. Every finding is formatted `[FILE:LINE] ISSUE_TITLE`.
6. Does this fix existing code, or request entirely new code that did not exist before? If the latter, downgrade to Informational.
7. If this is a re-review: ONLY verify previous fixes. Do not introduce new findings.

If uncertain about a finding, remove it or mark it as a question — do not open another verification pass.
