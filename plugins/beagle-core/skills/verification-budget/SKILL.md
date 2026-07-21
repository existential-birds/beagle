---
name: verification-budget
description: Defines the shared verification vocabulary for review and verify skills - reversibility-based risk tiers, bounded loop budgets with declared stop conditions, and the one-echo rule. Review and verification skills import these definitions by name instead of restating their own gates. Load when authoring or running any skill that adjudicates findings, confirms claims, or gates a destructive action.
user-invocable: false
---

# Verification Budget

Every verification loop needs a **cost ceiling**. Without one, ambiguity always resolves toward "verify again" — a loop with no bound and no observable exit. This skill defines the three primitives that bound it. Skills **import these by name** (`verification-budget: tier 1`, `verification-budget: one-echo`) rather than restating gates in their own text.

## 1. Risk tiers

Classify by the **reversibility of the action the verdict authorizes** — not by how confident you feel, not by severity label.

| Tier | The verdict authorizes… | Verification required |
|------|--------------------------|-----------------------|
| **REVERSIBLE** | Reporting a finding, writing a report file, adding a test, adding a new symbol, any edit `git checkout -- <path>` fully undoes | **None.** Cite the evidence you already have and move on. |
| **IRREVERSIBLE** | Deleting code or files, rewriting a file wholesale, `git rebase`/`push --force`/`reset --hard`, dropping data, mutating state outside the working tree | **Full evidence gate.** Full-context read of the target, reference search for remaining users, explicit confirmation before acting. |

**How to classify:** ask "if this verdict is wrong, what does it take to get back?" If the answer is a git checkout of the working tree, it is REVERSIBLE. If the answer involves reconstructing information that no longer exists anywhere, it is IRREVERSIBLE. Reporting a false positive is REVERSIBLE — a human reads it and disagrees. Acting on that same false positive by deleting the symbol is IRREVERSIBLE.

> **Verification cost tracks the cost of being wrong, not the cost of being thorough.**

This is what preserves rigor where it matters while removing ceremony where it does not. Ninety percent of review output is tier REVERSIBLE, and spending an evidence gate on it buys nothing.

## 2. Budget syntax

Every verification loop MUST declare three things **before** it runs:

1. **Max passes** — an integer. Not "until confident."
2. **Stop condition** — an observable another agent could check: a file exists, a count matches, a command exits 0. Not a feeling.
3. **Tie-break** — what happens when max passes is hit without the stop condition. This is **always "proceed and flag."** It is **never "verify again."**

**Well-formed:**

> Budget: max 2 passes. Stop when every id in the locked set has a recorded status. Tie-break: emit remaining ids as `inconclusive` with a note, and proceed.

**Malformed:**

> Advance only when every checklist item is honestly "yes."

That has no pass count, no observable stop, and no tie-break — "honestly yes" is unfalsifiable, so a cautious agent re-runs forever. **Gates phrased as "advance only when all items are yes" are the anti-pattern this section exists to kill.** Rewrite them as an enumerated check list plus a pass count.

If a loop cannot state a stop condition an outside observer could evaluate, it is not a verification loop — it is an unbounded search. Cut it or bound it.

## 3. The one-echo rule

Echo the artifact under judgment **once, at stage entry** — the parsed finding table, the diff hunk, the file:line and its code, read in this turn. Not once per verdict.

Downstream stages in the same pipeline **trust the upstream stage's recorded echo** and do not re-read the source to re-derive it.

**Rationale, stated honestly:** per-verdict echo gates were built to defend against a single long-lived context confabulating about code it never read. That threat was real when one context carried an entire review end to end. With fresh, narrowly-scoped subagent contexts — where the agent has read little else and the artifact dominates its window — the confabulation risk is much lower, and repeated echoing now costs more than it saves.

**One exception:** an IRREVERSIBLE action (tier 1) re-reads its target immediately before acting. Not for confabulation — for **staleness**. The tree may have moved since the upstream echo, and a delete against a stale line number destroys the wrong thing unrecoverably.

## 4. Prove-a-negative ban

Never require an agent to establish exhaustive absence: "grep-confirm zero remaining," "verify no other callers exist anywhere," "confirm the codebase is clean." Absence over an open-ended search space has no terminating check, so the agent keeps widening the search — a documented stuck-state.

Replace with one of:

- **An enumerated check list.** "Search these three call patterns: direct call, re-export, string literal. Report each result." Finite, and each item has an artifact.
- **A fixed-size sample.** "Check the first 10 matches. If all clean, report clean-with-sample-size."

Report what you checked and the bound you checked it under. "No remaining references across the 3 enumerated patterns" is a verifiable claim. "No remaining references" is not.

## Importing this skill

Reference tiers and rules by name; do not restate their content:

- "Deletion is `verification-budget` tier IRREVERSIBLE — apply the full evidence gate."
- "Per `verification-budget` one-echo, this stage trusts the upstream finding table."
- "Loop budget: max 2 passes; stop when …; tie-break proceed-and-flag."

Skills that also define an execution contract should keep sequencing and output-shape rules in `execution-contract` and keep only budget vocabulary here. Where a skill's own gates conflict with this file, this file wins — delete the local restatement rather than maintaining two copies.
