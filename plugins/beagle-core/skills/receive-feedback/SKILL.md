---
name: receive-feedback
description: Process external code review feedback with technical rigor. Use when receiving feedback from another LLM, human reviewer, or CI tool. Verifies claims before implementing, tracks disposition.
disable-model-invocation: false
---

# Receive Feedback

## Overview

Process code review feedback with verification-first discipline.
No performative agreement. Technical correctness over social comfort.

The orchestrator **verifies** and **applies fixes** under a strict per-item contract.
**If the agent supports subagents**, each valid item is fixed by a dedicated subagent dispatched in parallel; **otherwise** the orchestrator applies the same fixes sequentially itself, one item at a time, under the identical Fix-Quality Contract — producing identical output.

## Quick Reference

```text
┌─────────────┐     ┌──────────────┐     ┌──────────────────────┐
│   VERIFY    │ ──▶ │   CONFIRM    │ ──▶ │   APPLY FIXES        │
│ (tool-based)│     │ ("launch     │     │ (one fix per valid   │
│             │     │  fixes for   │     │  item — parallel     │
│             │     │  1,2,3?")    │     │  subagents if        │
│             │     │              │     │  supported, else     │
│             │     │              │     │  sequential)         │
└─────────────┘     └──────────────┘     └──────────────────────┘
```

## Core Principle

**Verify, confirm once, then apply the fixes for the chosen set.**

If a bug is valid, it gets fixed. Full stop. No deferral, no excuses. When subagents are available, one subagent fixes each item in parallel; otherwise the orchestrator fixes each item sequentially under the same contract.

## When To Use

- Receiving code review from another LLM session
- Processing PR review comments
- Evaluating CI/linter feedback
- Handling suggestions from pair programming

## Workflow

1. **Verify every item** against the current codebase (tools, not memory).
2. **Classify** each item as **VALID** (must fix) or **INVALID** (reject with evidence).
   - Truly unparseable items get one clarification question. That is the only escape.
3. **Print** a short summary: invalid items with evidence, valid items numbered.
4. **Ask exactly one prompt**: `launch fixes for 1,2,3?` (list every valid item's number — the default proposal is always the full valid set).
5. **Resolve the user's reply**:
   - Confirmation (`y`, `yes`, `go`, `ok`, `do it`, `lgtm`, or just ↵) → dispatch the full proposed set.
   - A comma/space-separated list of numbers (e.g. `1,3` or `1 3 4`) → dispatch only those numbers. They must be a subset of the proposed valid set. Items the user omits are NOT marked deferred — they are simply not run this round.
   - `no` / `cancel` / `stop` → halt without dispatching.
   - Anything else → re-print the prompt once; do not invent a new disposition.
6. **Apply the fix for each chosen item** under the Fix-Quality Contract. **If the agent supports subagents**, dispatch one subagent per chosen item in parallel (the orchestrator does not edit files itself in this branch); **otherwise** apply each fix sequentially yourself, one item at a time, following the same contract. Either branch must produce identical results.
7. **Collect** the per-item results and emit the final response table.

## Forbidden Behaviors

These are non-negotiable. The orchestrator may **not**:

- Ask the user *which* items to fix. The only question allowed is `launch fixes for <numbers>?`, where `<numbers>` defaults to the full valid set. (The user may override by replying with their own subset of numbers — that is a user override, not an agent question.)
- Claim an issue is **pre-existing**. If a reviewer found it on this PR, it is in scope.
- Claim an issue is **out of scope** for the PR. If the bug exists on this branch, the PR owns it.
- **Defer** a valid item to "later", a "backlog", a "follow-up PR", or a "future ticket".
- Use any reasoning — risk, complexity, time, churn, "minor", "cosmetic", "edge case" — to avoid fixing a valid item.
- Bundle multiple fixes together. One valid item = one isolated fix (one subagent when supported, one focused sequential pass otherwise).
- **When subagents are available**, edit code directly in the orchestrator — delegate each fix to a subagent instead.

A valid bug raised by a code or security reviewer **must** be fixed. There is no other option.

## Hard Gates

Do not advance to the next gate until its **pass condition** is true. Details live in `VERIFICATION.md`, `EVALUATION.md`, and `RESPONSE.md`.

**Gate 1 — Verification evidence (per item)**

1. Locate the referenced code or behavior (read the file, search the codebase, run the relevant test, or another check from `VERIFICATION.md`).
2. Record the outcome: **VALID** (claim holds and is actionable) or **INVALID** (claim fails), with an artifact (file path and line range, command/test result, or short quoted tool output — not paraphrase alone).
3. If unparseable, mark **NEEDS CLARIFICATION** with the specific question. Do not invent a disposition.

**Pass when:** Every item has VALID / INVALID / NEEDS CLARIFICATION plus an artifact. **Fail (stop):** Proceeding without an artifact, or downgrading a VALID item to "skip" / "defer" / "pre-existing" / "out of scope".

**Gate 2 — Single batch confirmation**

1. Print the invalid items (with rejection evidence) and the valid items (numbered).
2. Ask the **single** prompt: `launch fixes for <comma-separated numbers>?` — `<numbers>` MUST be the full valid set. Do not pre-narrow it.
3. Accept the user's reply per the Workflow resolution rules: confirmation → full set; subset of numbers → that subset only; refusal → halt.

**Pass when:** The user confirms or supplies a subset of the proposed numbers, and the chosen set is locked in writing before Gate 3. **Fail (stop):** Proposing a narrowed default, asking "which would you like to fix?", or proposing to defer any valid item.

**Gate 3 — Apply fixes for the chosen set**

1. Each chosen item gets exactly one isolated fix carrying: the original feedback text, the verification artifact, the file/line target, and the Fix-Quality Contract.
2. **If the agent supports subagents**, dispatch one subagent per item in a single block so they run in parallel, and do not edit files in the orchestrator. **Otherwise**, apply each fix sequentially yourself, one item at a time, under the identical contract.

**Pass when:** Every item in the user-chosen set has been fixed under the contract (one subagent each when supported, or one focused sequential pass each otherwise). **Fail (stop):** Bundling fixes, or skipping any item the user actually chose.

**Gate 4 — Response artifact (batch)**

1. After subagents return, fill the structured template in `RESPONSE.md`.
2. The response has exactly two sections: **Implemented** and **Rejected**. There is no Deferred section.
3. Valid items the user explicitly excluded from this round get a single line under the table — `Not run this round: <numbers> (user-excluded)` — and nothing else. Do not label them deferred or out of scope.

**Pass when:** Every item appears in Implemented or Rejected with file:line citations, and any user-excluded valid items are listed verbatim under the table. **Fail (stop):** Shipping a summary that omits an item, lacks evidence on a rejection, or invents a "Deferred" bucket.

## Command Workflow

Invoke the **receive-feedback** skill with a feedback file path as its argument.

1. **Read** the feedback file at `$ARGUMENTS`
2. **Parse** individual feedback items, whether numbered, bulleted, or freeform
3. **Verify** each item per `VERIFICATION.md`
4. **Confirm** via single `launch fixes for <numbers>?` prompt
5. **Apply** the fix for each valid item — one subagent each if subagents are supported, otherwise one sequential pass each
6. **Produce** the response summary defined in `RESPONSE.md`

## Expected Feedback File Format

```markdown
1. Remove unused import on line 15
2. Add error handling to the API call
3. Consider using a generator for large datasets
4. Fix typo in variable name: `usr` → `user`
```

Freeform prose is also acceptable; extract actionable items from the text.

## Fix Dispatch Template

When fixing an item — whether dispatching a subagent or doing it sequentially yourself — the fix brief MUST include:

- The original feedback text (verbatim).
- The verification artifact: file path, line range, and what was confirmed.
- The exact change required, or "implement the reviewer's suggestion as written" if the reviewer specified one.
- The fix-quality contract below, applied to every fix (copied verbatim into each subagent prompt when subagents are used).

### Fix-Quality Contract (apply to every fix)

```text
You are fixing one code review finding. Hard requirements:

1. Make the fix. Do not defer. Do not declare anything out of scope.
   Do not call anything pre-existing. If you discover the fix needs to
   touch adjacent code to be correct, touch it.

2. The fix must be clean and architectural — idiomatic for the language
   and the file's surrounding patterns. Read enough of the
   surrounding module to match its conventions before editing.
   No inline hacks, no band-aids, no "minimum to make it green".

3. Do NOT over-engineer. No new abstractions, no speculative
   generality, no helper layers, no config knobs. Solve the actual
   reported problem. If three lines are right, write three lines.

4. Write NO comments unless a future reader would be genuinely
   confused without one (a non-obvious invariant, a workaround for a
   specific upstream bug, a hidden constraint). Never write comments
   that restate what the code does. Never write headers, banners,
   "fix:" markers, or "// added for review feedback" notes.
   Excessive comments are a defect — do not produce them.

5. Run the project's typecheck / lint for the file you touched if a
   command is obvious from the repo. Report what you ran.

6. Report back: the resulting diff, the file:line of the change, and
   one sentence on what you changed and why.
```

When dispatching subagents, use a general-purpose subagent unless a domain-specific one is clearly better.

## Example

Invoke the **receive-feedback** skill with a feedback file path:

```
receive-feedback reviews/pr-123-feedback.md
```

Reads the file, verifies each item, prints invalid/valid summary, asks `launch fixes for 1,3,4?`, and on confirmation fixes items 1, 3, and 4 — three subagents in parallel if supported, otherwise three sequential fixes under the same contract.

## Files

- `VERIFICATION.md` - Tool-based verification workflow
- `EVALUATION.md` - Classification rules (VALID / INVALID / NEEDS CLARIFICATION)
- `RESPONSE.md` - Structured output format
- `references/skill-integration.md` - Using with code-review skills
