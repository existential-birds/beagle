# Plan Document Reviewer Prompt Template

Use this template when dispatching a plan-document reviewer subagent.

**Purpose:** Verify the plan is complete, matches the spec, and has proper task decomposition.

**Dispatch when:** The plan is long (>10 tasks), touches unfamiliar territory, or has high stakes. For short, familiar plans, skip the dispatched review — the self-review and the human review step are enough.

**Dispatch after:** The complete plan draft is written and self-review has been honestly passed. Do not dispatch the reviewer to do your self-review for you.

## Prompt Template

```
Task tool (general-purpose):
  description: "Review implementation plan"
  prompt: |
    You are a plan document reviewer. Verify this implementation plan is complete and ready for execution.

    **Plan to review:** [PLAN_FILE_PATH or inline draft]
    **Source spec:** [SPEC_FILE_PATH at .beagle/concepts/<slug>/spec.md]
    **Project conventions:** [path(s) to relevant CLAUDE.md]

    ## What to Check

    | Category | What to Look For |
    |----------|------------------|
    | Spec coverage | Every must-have requirement from the spec has a task that implements it. List any gaps. |
    | Test discipline | Every behavior-changing task has a failing-test step before the implementation step. Flag tasks that implement without a test. |
    | Assertion quality | Tests assert observable consequences (DB rows, files written, user-visible output), not dispatch ("the handler was called"). Flag dispatch-only assertions. |
    | Placeholders | TBD, TODO, "implement later", "similar to Task N", `unimplemented!()`, vague verbs without code. |
    | Type consistency | Function names, type names, and signatures match across tasks. `clearLayers()` in Task 3 vs `clearFullLayers()` in Task 7 is a bug. |
    | Project conventions | The plan respects CLAUDE.md rules — test tiers, comment policy, commit format, forbidden patterns. |
    | Out-of-scope creep | No task implements something the spec explicitly marks Out of Scope. |
    | Assumptions | Load-bearing assumptions are surfaced in the Assumptions section, not baked silently into tasks. |

    ## Calibration

    **Only flag issues that would cause real problems during execution.**

    An executor (engineer or agent) building the wrong thing, getting stuck on a placeholder, or shipping broken-but-green tests is a real problem. Minor wording, stylistic nits, and "could be more detailed" suggestions are not.

    Approve unless there are serious gaps:
    - Missing requirements from the spec
    - Contradictory or out-of-order steps
    - Placeholder content where real code/commands are required
    - Tests that assert dispatch instead of consequence
    - Tasks so vague they can't be acted on

    ## Output Format

    ## Plan Review

    **Status:** Approved | Issues Found

    **Issues (if any):**
    - [Task X, Step Y]: [specific issue] — [why it matters for execution]

    **Recommendations (advisory, do not block approval):**
    - [suggestions for improvement]
```

## What to Do With the Reviewer Output

- **Status: Approved** — proceed to user review. Mention to the user that the dispatched review passed.
- **Status: Issues Found** — fix each blocking issue inline, then either re-dispatch (if a second pass is justified) or proceed to user review with a note about what was fixed.

Do NOT treat the reviewer's recommendations as mandatory. They're advisory. Apply the ones that obviously improve the plan; skip the ones that are stylistic preference.
