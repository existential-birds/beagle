# Plan Review: One Pass

The single review of the plan draft. It replaces the per-item checklists that used to gate advancement inside `write-plan` and `quick-plan` — those criteria all live here now, as review content rather than as gates.

**Budget:** one pass. **Stop condition:** every row below has been looked at once and each blocking finding has been fixed inline. **Tie-break:** if something is unresolvable, record it under *Known gaps* in the plan's Review Outcome and proceed. Never re-run the pass hoping for a different answer (`beagle-core:verification-budget`).

**Dispatch as a subagent** when the plan is long (>10 tasks), covers unfamiliar territory, or is high-stakes — a fresh context catches what builder-brain misses. **Otherwise run the same pass inline yourself.** Identical criteria, identical output, one pass either way.

**Don't dispatch ritualistically.** For a short plan over familiar code, the inline pass plus the human review that follows is enough. Dispatching a subagent to do the pass *for* you when you have not read your own draft is not a review — it is a delegation of judgment.

**Run it after** the complete draft exists and before presenting to the user.

## Prompt Template

```text
Reviewer brief (dispatch as a subagent if supported, otherwise run inline):

    You are a plan document reviewer. Verify this implementation plan is complete
    and ready for execution. Make ONE pass. Do not re-review.

    **Plan to review:** [PLAN_FILE_PATH or inline draft]
    **Contract it must satisfy:** [SPEC_FILE_PATH at .beagle/concepts/<slug>/spec.md
      — or, for a quick-plan draft, the plan's own `## Intent` block]
    **Project conventions:** [path(s) to relevant AGENTS.md or CLAUDE.md]

    ## What to Check

    ### Format integrity

    | Category | What to Look For |
    |----------|------------------|
    | Executor Contract | The plan opens with an `## Executor Contract` section carrying the full inlined contract — roles, failure-matching-by-shape, pre-existing-red policy, attempt budget, stop-and-report template, spike-failure script. A link or a summary in its place is a blocking defect: the executor has no legal way to halt without it. |
    | Baseline suite | The header names a real, copy-pasteable baseline suite command. Without it, every Step 4 is unjudgeable. |
    | Placeholders | TBD, TODO, "implement later", "similar to Task N", `unimplemented!()`, vague verbs standing in for content. |
    | Type consistency | Function names, type names, and signatures match across tasks. `clearLayers()` in Task 3 vs `clearFullLayers()` in Task 7 is a bug. |

    ### Coverage and scope

    | Category | What to Look For |
    |----------|------------------|
    | Contract coverage | Every must-have in the spec (or Intent block) maps to a task. List any gap. |
    | Nothing invented | Every task traces back to a must-have, a project convention, or a recorded finding. Flag tasks with no anchor. |
    | Out-of-scope creep | No task implements something the contract marks Out of Scope. Cut it. |
    | Open questions | For a spec-free plan: every Intent-Brief open question is answered, resolved by exploration, or recorded as an Assumption. None dangling. |
    | Assumptions surfaced | Load-bearing assumptions appear in the Assumptions section, not baked silently into tasks. |
    | Consumer check | Every new public surface (trait method, exported fn, public field, endpoint, CLI flag) has a named **production** consumer — a caller on a non-test path — in this same plan. A contract or unit test is NOT a consumer. Flag any surface whose only caller is a test: cut it, or tag it deferred with a numbered follow-up. A primitive that exists only to satisfy a contract test is dead surface forcing a dead impl. |
    | Project conventions | The plan respects AGENTS.md/CLAUDE.md — test tiers, comment policy, commit format, forbidden patterns. |

    ### Test quality

    | Category | What to Look For |
    |----------|------------------|
    | Test discipline | Every behavior-changing task has a failing-test step before its implementation step. Flag tasks that implement without a test. |
    | Assertion target | Tests assert observable consequence — DB rows, files written, user-visible output, what the next call sees — not dispatch ("the handler was called", "the event was emitted"). |
    | Discriminating assertion | For each test, name a plausible broken or no-op impl that still passes it. If one exists, the assertion is on the wrong target — move it to the region the bug corrupts. For preserve/recover/transform invariants: the sentinel must be asserted in the region the bug *damages* (the dropped middle, never the surviving head or tail), through every structurally-distinct producer (streaming-with-eviction is not the same path as whole-string). Flag any test a no-op impl would pass. |
    | Assertion strength | For every test asserting on a **sequence, stream, or event list**: does it use ordered assertion — exact sequence via equality on the filtered list, or indexed `events[i]` — rather than `.contains()`? `.contains()` proves membership, not ordering or absence. Flag every `.contains()` assertion and require either a justification (ordering genuinely does not matter) or a stronger form (exact sequence, or at minimum a length assertion plus a position check). This catches tests that pass while events are duplicated, reordered, or omitted. |
    | Real-entrypoint coverage | Some behavior cannot be proven below the real entrypoint: launch/bootstrap, CLI arg parsing, env-var resolution, terminal/pty/signal handling, real stdin/stdout piping, shell scripts whose contract is shell semantics, and user-visible strings whose stability is part of the contract. Enumerate every such trigger this plan touches; for each, point at a test that drives the real entrypoint (compiled binary, launcher, or pty as appropriate) with production dependencies — or mark the task incomplete. A shell-script credential leak is invisible to every in-process test. If the project defines its own name for this test level, use the project's term. |
    | Helper signatures | Every helper a test calls is given with its full signature, and marked as existing (`path:line`) or to-be-written. An unsigned helper is a guess the executor will get wrong. |
    | Scaffolding reuse | Tests reuse existing helpers/fixtures/mocks. A newly-invented helper must name the existing one that was considered and why it did not fit. |

    ### Implementation contracts

    | Category | What to Look For |
    |----------|------------------|
    | Contract not code | Step 3 carries files + 3-5 behavior bullets + a `file:line` reference + (for non-trivial steps) a signature-and-numbered-comments skeleton. Flag finished implementations pasted into the plan, and flag references that paste cited code inline. |
    | Failure propagation | Every task introducing a fallible operation (serialize/parse/convert/open/connect) states how the error propagates. `.unwrap_or(<plausible fallback>)` or `.unwrap_or_default()` on a meaningful-default type, without contract rationale, is a bug class — fix the contract. |
    | Silent-failure patterns | For every task handling errors, does the contract state what happens on failure, not just the happy path? Flag: `let _ = <fallible>()` with no WHY, `.ok()` discarding an error, hardcoded limits with no config or test asserting the bound. Each must propagate, log, or carry a contract-justified default with a test. |
    | Trust-boundary contracts | For every task introducing a security-relevant boundary — workflow execution, script proposal/persistence, external input parsing, trust/approval gates — does the plan mandate three tests: (a) the gate **rejects** untrusted or invalid input, (b) **validation runs before persistence**, (c) **partial failures roll back**, leaving no mutated state on disk after an error? A boundary missing any of the three is an incomplete task. A `run_workflow` that skips the trust check, a `propose` that stores before validating, a `grant` that mutates memory before the write — these are the bugs this row catches. |

    ### Gates and loops

    | Category | What to Look For |
    |----------|------------------|
    | Spike candidates | Every claim of the form "tool X does Y" or "input arrives in shape Z" that neither this repo nor the contract has verified has a `Task 0` spike — and that Task 0 tells the executor to report and halt on a disproven assumption, not to redesign. |
    | Parallel-implementation gate | Does the plan add a second backend/platform/adapter behind an existing interface? If yes, is there a final task running the canonical contract suite against BOTH and asserting identical observable behavior? If not, add it. |
    | Step 4 baseline-diffed | Every Step 4 names both the single-test command and the broader-scope command, and judges against the pre-Task-1 baseline rather than demanding absolute green. Single-test-only hides cross-task regressions; absolute-green strands the executor on a suite that was already red. |
    | Sweep enumerated | Every modify-file task's Step 5 lists its sweep targets by name — symbols, comment text, branches. Flag "sweep the file," flag line numbers, flag any instruction to confirm exhaustive absence. |
    | Pattern application audit | If a Pattern applies across many sites, is the final Audit task present, with the converted sites enumerated at `file:line` and a fixed 3-site sample check? Flag any "grep-confirm zero remaining" phrasing — that is a prove-a-negative with no terminating check. |

    ## Calibration

    **Only flag issues that would cause real problems during execution.**

    An executor building the wrong thing, stalling on a placeholder, having no legal way to halt, or shipping broken-but-green tests is a real problem. Minor wording, stylistic nits, and "could be more detailed" are not.

    Approve unless there are serious gaps:
    - A missing or summarized Executor Contract
    - Missing requirements from the spec or Intent block
    - Contradictory or out-of-order steps
    - Placeholder content where real code or commands are required
    - Tests that assert dispatch instead of consequence, or that a no-op impl would pass
    - A new public surface with no production consumer
    - An unbounded loop: absolute-green gates, prove-a-negative sweeps, unenumerated audits
    - Tasks so vague they can't be acted on

    ## Output Format

    ## Plan Review

    **Status:** Approved | Issues Found

    **Issues (if any):**
    - [Task X, Step Y]: [specific issue] — [why it matters for execution]

    **Recommendations (advisory, do not block approval):**
    - [suggestions for improvement]
```

## What to Do With the Output

- **Approved** — proceed to user review. Mention that the review pass ran clean.
- **Issues Found** — fix each blocking issue inline, then proceed to user review with a note on what changed. **Fix and move on.** A second dispatch is justified only when the fixes restructured the plan (tasks added, split, or resequenced) — not to confirm the first round of fixes landed.

Recommendations are advisory, never mandatory. Apply the ones that obviously improve the plan; skip stylistic preference.

Record the outcome in the plan's `## Review Outcome` section: what was reviewed against, what was fixed, what was left open and why. An honest "I did not verify the real-entrypoint coverage claim" is worth more to a future reader than a clean-looking summary that is not true.
