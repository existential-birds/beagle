---
name: execution-contract
description: Defines the stop rules, attempt budgets, failure-matching semantics, and reporting contract for a model executing a TDD implementation plan. Plan-producing skills inline this block verbatim into emitted plan headers and handoff prompts so executors have a legal way to halt instead of grinding.
user-invocable: false
---

# Execution Contract

This block is the executor's charter. It is inlined verbatim into plan headers and handoff prompts, so it must stand alone. If you are executing a plan and reading this, these rules override any instinct to keep trying.

## Roles

Roles are defined by what each is **trusted to decide**, not by which model fills them. A single session may hold both roles at different times.

| Role | Decides | Does NOT decide |
|------|---------|-----------------|
| **Planning model** | Scope, architecture, whether the spec is correct, whether the plan needs revision, what "done" means | — |
| **Execution model** | How to satisfy one task's stated behavior contract, within that task's files | Scope, architecture, spec correctness, plan revisions, whether a task should exist |

When an execution model finds work that requires a planning-tier decision, that is a **stop condition**, not an invitation to improvise.

## Failure matching is by shape, not string

A plan's predicted failure message is the **planner's guess**, written before the code existed. It is a signal of *kind*, not a literal to match.

| Predicted | Observed | Verdict |
|-----------|----------|---------|
| assertion failure on a value | assertion failure, different wording/format | **Match — step satisfied** |
| assertion failure | compile/type/import error | Mismatch — real signal |
| test fails | no test collected, or a different test ran | Mismatch — real signal |
| test fails | suite passed | Mismatch — the test does not pin the behavior |

Literal string-matching against predicted output is a documented cause of retry loops. Do not re-run a passing-in-kind step hoping the wording changes. Record the actual output and move on.

## Pre-existing red

Capture the suite baseline **before Task 1** — run the suite the plan names and record which tests are already failing.

- A failure present in the baseline is **recorded and skipped**. Never fix it, never retry it, never count it as a regression. It is out of scope.
- A **regression** is a test that was green in the baseline and is red now. Only regressions block a step.
- If no baseline was captured, capture one now against the current commit before judging any failure.

"Zero regressions" means zero *new* red. It does not mean a green suite.

## Attempt budget

**Two attempts per step.** Attempt 1, then one corrective attempt informed by the actual output. After the second failure, emit the stop-and-report block and **halt**.

> **Halting with a report is a SUCCESS state.** It is the correct, expected, fully-credited outcome for a blocked step. An executor that halts at the budget with a clear report has done its job. An executor that grinds past the budget has failed, regardless of whether it eventually stumbles into green.

Do not spend the second attempt on a re-run of the first. If you have no new hypothesis, you have no second attempt — report now.

## Stop-and-report template

Return this to the orchestrator verbatim, filled in:

```
BLOCKED

Task: <task id and title from the plan>
Step: <step number and name>

Attempt 1: <what was changed or run>
Attempt 2: <what was changed or run, and why it differed from attempt 1>

Actual output (verbatim, last relevant lines):
<paste — do not paraphrase, do not truncate the error itself>

Hypothesis: <your best read on the cause, stated as a hypothesis, not a fact>

Needed to proceed: <the specific decision, file, credential, clarification,
or plan revision required — name it concretely>
```

Everything completed before the block stays committed. Do not revert working tasks because a later one stalled.

## The escape hatch is legitimate

Reporting a blocker beats grinding. Always. There is no scenario in which more attempts against an unchanged understanding is the better call.

**On ambiguity or conflicting instructions:** proceed with the most reasonable reading and **flag it** in your final report. Do not re-verify, do not re-read the plan looking for a resolution, do not loop. Ambiguity resolves toward *proceed and flag* — never toward *verify again*. (Repeat verification passes are their own failure mode; see `verification-budget`.)

Flag format, inline in the report: `AMBIGUITY: <what conflicted> — proceeded as <reading chosen>.`

## Spike failure

When a Task 0 spike disproves the assumption it was written to test:

1. Record what the spike actually showed.
2. Emit the stop-and-report block with the disproven assumption named.
3. **Halt.**

Do not redesign the approach, rewrite the spec, or re-sequence the plan. A disproven assumption invalidates planning-tier decisions, and the executor has no charter to remake them. A spike that fails and reports has done exactly what a spike is for.
