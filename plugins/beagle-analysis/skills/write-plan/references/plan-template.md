# Plan Document Template

The single source of truth for the emitted plan's shape. `write-plan` saves to `.beagle/concepts/<slug>/plan.md`; `quick-plan` saves to `.beagle/plans/<slug>/plan.md`.

The plan is written **for an execution-tier reader** — one that follows the plan closely and does not re-derive planning decisions. That means: helper signatures are given, non-trivial implementation steps carry a skeleton, and sweep targets are enumerated. A more capable executor is not harmed by the extra specificity; it reads past it.

## The Executor Contract block is mandatory

Every emitted plan opens with an `## Executor Contract` section containing the **full text of `beagle-core:execution-contract`, inlined verbatim**. Not a link, not a summary — the plan travels to sessions that do not have the skill installed, and the contract is what gives the executor a legal way to stop.

Read `beagle-core:execution-contract` and paste its body (from "## Roles" onward) under the `## Executor Contract` heading. If `beagle-core` is unavailable, say so to the user before writing — a plan without the contract has no attempt budget, no pre-existing-red policy, and no stop-and-report script, which is the failure mode this section exists to prevent.

## Template

````markdown
# [Feature Name] Implementation Plan

> **Source spec:** `.beagle/concepts/<slug>/spec.md`
> **For downstream agents:** Execute task-by-task. Each task uses `- [ ]` checkboxes for tracking. Do not skip the test-first steps — they catch wiring bugs that pure-logic tests miss. Read the Executor Contract below before Task 1.

**Goal:** [One sentence describing what this builds, mirroring the spec's Core Value.]

**Architecture:** [2-3 sentences describing the approach — how the pieces fit together, what the data/control flow looks like at a high level.]

**Tech Stack:** [Key technologies, libraries, frameworks.]

**Baseline suite:** `[exact command that runs the suite this plan will be judged against]` — run this once, before Task 1, and record which tests are already failing. See the Executor Contract.

---

## Executor Contract

[Full text of `beagle-core:execution-contract`, inlined verbatim — roles, failure-matching-by-shape, pre-existing-red policy, attempt budget, stop-and-report template, escape-hatch legitimacy, spike-failure script. Do not summarize it. Do not replace it with a link.]

---

## Assumptions

[Confirmed assumptions that aren't explicitly pinned by the spec but shape the plan. Surface anything a future reader could plausibly disagree with. Include findings from re-reading the files the spec names — code comments and doc headers sometimes contradict the spec's characterization.]

- [Assumption — what was assumed, why, and what would change if the assumption is wrong]

[If none: "No load-bearing assumptions beyond what the spec specifies."]

## Patterns (optional)

[If multiple tasks apply the same transformation across many sites, name the pattern once here and reference it from each task. The Patterns section absorbs the transformation shape and a reference example; tasks still own their own files, test, and commit.]

### Pattern: [name]

**Applies when:** [the condition under which a task uses this pattern]
**Reference example:** [pointer to one place where the pattern is shown end-to-end]
**Transformation:** [2-4 bullets describing the before/after shape]

[Omit this whole section if no patterns repeat.]

## File Structure

[Files this plan creates or modifies, with their responsibilities. This locks in decomposition before tasks begin.]

### Files to Create

- `path/to/new_file.ext` — [responsibility, 1 line]

### Files to Modify

- `path/to/existing_file.ext` — [what changes and why]

### Files to Delete (if any)

- `path/to/dead_file.ext` — [why it's dead]

---

## Task 1: [Component or Behavior Name]

**Files:**
- Create: `exact/path/to/file.ext`
- Modify: `exact/path/to/existing.ext:123-145`
- Test: `tests/exact/path/to/test.ext`

- [ ] **Step 1: Write the failing test**

[Show the assertions and the call site under test. Target ~15 lines or less. Do not write the seed/setup loop — instead name each helper the test calls with its FULL SIGNATURE, so the executor writes or reuses the right thing without guessing.]

**Helpers this test uses:**
- `seed_entries(&store, session_id: Uuid, count: i64) -> Vec<EntryId>` — [existing at `path:line` | to be written in this step]

```
// Assertions + call site only. ~15 lines or less.
// Assertions pin observable consequence — a value, a row, a written file,
// the output the next call would see — never dispatch.
```

- [ ] **Step 2: Run test to verify it fails**

Run: `<exact project test command for this single test>`
Expected: FAIL — `<the failure you expect>`.

This prediction is a guess about *kind*, not a literal to match. A failure of the predicted kind with different wording satisfies this step. See the Executor Contract, "Failure matching is by shape, not string."

- [ ] **Step 3: Implement against the test**

**Files touched:** `path/to/impl.ext`

**Behavior contract** (3-5 bullets max; past 5, replace the rest with a tighter reference):
- [The new/changed behavior bullet 1 — what's different from the reference]
- [The new/changed behavior bullet 2]
- [The error or edge-case behavior the Step 1 test pins, if not covered above]

**Reference:** `path/to/analog.ext:line-line` — [one-sentence delta]. Pointer only; do NOT paste the cited code inline. The executor opens the file.

**Skeleton** (required unless this step is a one-liner, a config edit, or a pure rename — signatures and numbered control flow only, no bodies):

```
fn new_or_changed_fn(args: Types) -> Result<Out, Error> {
    // 1. [first thing it does]
    // 2. [second thing]
    // 3. [what it returns and when it errors]
}
```

- [ ] **Step 4: Run the new test AND the relevant suite, diff against baseline**

Run: `<same test command as Step 2>` → Expected: PASS.
Then run: `<broader suite this task lives in — module, package, or contract suite. Exact command; never "run the suite">`.

**Judge the result against the baseline recorded before Task 1, not against green.** A test that was already failing in the baseline is recorded and skipped — not fixed, not retried, not counted here. Only a **regression** (green in baseline, red now) blocks this step. If a regression appears, that is a real signal: fix it within the attempt budget or emit the stop-and-report block.

A new test that passes while a sibling silently regresses is a task failure, not a deferred concern.

- [ ] **Step 5: Sweep modified files for leftovers**

**Enumerate the sweep targets by name.** Not "sweep the file," not line numbers (they rot before execution). List each one so the executor has a finite, checkable set:

- `<symbol>` — [the orphaned import / dead field / unused helper]
- `<comment or doc-header text>` — [describes the old shape]
- `<match arm / branch>` — [now unreachable]

The executor greps for each named item and reports per item: removed, or not present. When the list is complete, the sweep is done — do not widen it into an open-ended hunt.

New-file-only and config-only tasks skip this step.

- [ ] **Step 6: Commit**

```bash
git add <specific paths, not git add .>
git commit -m "<type>(<scope>): <imperative one-line summary>"
```

---

## Task 2: [Next Component or Behavior Name]

[Same structure — Files / Step 1 failing test + helper signatures / Step 2 verify failure / Step 3 contract + reference + skeleton / Step 4 baseline-diffed suite run / Step 5 enumerated sweep / Step 6 commit]

---

[... more tasks ...]

---

## Review Outcome

[Short prose recording what the one-pass plan review found and what you fixed. Not a re-run of a checklist, and not a promise — a record.]

- **Reviewed against:** [spec at `<path>` | Intent block above]
- **Blocking issues fixed:** [list, or "none found"]
- **Advisory notes not acted on:** [list, or "none"]
- **Known gaps:** [anything left open, and why — say so rather than lying to future readers]

````

## Guidelines

**Header:**
- The goal sentence mirrors the spec's Core Value; it does not invent a new one
- Architecture is *approach*, not implementation detail (those live in tasks)
- Tech stack matches the spec's Constraints; flag mismatches before drafting
- The baseline suite command must be real and copy-pasteable — it is the reference point every Step 4 is judged against

**Executor Contract:**
- Inlined verbatim, always, in every plan. It is the executor's only legal way to halt.

**Assumptions:**
- Only assumptions that are *load-bearing* — change them and the plan changes
- Not trivial defaults ("we'll use the existing test runner")
- If a file the spec names has a comment contradicting the spec's characterization, that contradiction is an assumption-audit item

**Patterns:**
- Only when a transformation repeats across 3+ tasks
- Never absorb the test code or the commit message — those stay per-task
- Patterns applied across many sites get a final `Audit` task (see `planning-disciplines.md`)

**File Structure:**
- Flat lists, one line each; the 1-line responsibility is for the *file*, not the change inside it

**Tasks:**
- One cohesive unit per task. If you can't describe it in 5 words, split it.
- Steps are exhaustive — read top to bottom, no skipping
- **Recoverability rule** — "can the executor recover this by reading the referenced file?" If yes, delete it. Sweep targets and helper signatures are the deliberate exceptions: they are not recoverable from any one file.
- Commands are *exact*; expected outputs describe the failure's *kind*, not a literal string to match

**Review Outcome:**
- A record of the review pass, not a checklist re-run. If a dimension went unchecked, say so.

## Examples of Good vs Bad Task Steps

| Bad step | Good step |
|----------|-----------|
| "Add validation" | "Test: assert `parse(\"\")` returns an empty-input error of the project's error type. Behavior contract: empty input → error variant named for the empty case, with a message naming the offending field." |
| "Run tests" | "Run: `<project test command for this one test>`. Expected: PASS — 1 test." |
| "Implement the controller" | (Split into 3-5 tasks, each with a failing test + behavior contract + skeleton for one cohesive piece) |
| Code block with `// TODO` or `unimplemented!()` as final state | Behavior contract with specific bullets plus a signature-and-comments skeleton; no placeholder code |
| "Similar to Task 2" with no further information | A `Patterns` reference, plus the task's own files, test code, and commit |
| Test asserting `the handler was called` | Test asserting `the row appears in storage` / `the file is written` / `the next request returns the new state` |
| Test calls `seed_entries(...)` with no signature given | `seed_entries(&store, session_id: Uuid, count: i64) -> Vec<EntryId>` — existing at `tests/support/db.rs:44` |
| Test invents `fn make_test_user()` without checking the codebase | Test uses existing `factories::user()`; or the plan names the factories considered and why none fit |
| 12 boundary tests for one parser ("empty, single char, BOM, …") | One test per spec-required behavior; one per named bug class. Speculative inputs go to a fuzz harness if one exists. |
| Step 4: "Expected: PASS with zero regressions" against an already-red suite | Step 4: run the named suite, diff against the pre-Task-1 baseline; only newly-red tests block |
| Step 5: "remove stale references — the executor greps" | Step 5: enumerated list — `PgPool` import, `session_store_override` field, the `// returns the PG pool` doc-comment, the `Backend::Legacy` match arm |
| Step 5 lists "line 71-72, lines 117-122, line 194" | Step 5 lists symbols and comment text by name; line numbers rot before execution |
| Test body: 60 lines of imports + a 5-iteration seeding loop + 6 assertions | Test body: ~12 lines — one helper call to seed, the call site, 2-3 assertions on observable consequence |
| Reference: a 4-line `match` block pasted from the file under refactor | Reference: `launch.rs:397-400` — one-sentence delta. The executor opens the file. |
| Behavior contract enumerates every column, type, index, and rationale | "Tables/columns/indexes match `existing_schema.sql` with `<one-sentence delta>`." |
| Skeleton containing real expression-level bodies | Skeleton containing the signature plus numbered `//` steps |

## Anti-Patterns To Reject

- A plan with no inlined Executor Contract, or no baseline suite command
- Tasks that produce code without a failing-test step first
- Test steps that assert dispatch rather than consequence
- **Test bodies past ~15 lines** — setup ceremony crept in
- **Implementation steps containing a finished implementation** — the planner is guessing at signatures and library shapes the executor can actually see; a signature-and-comments skeleton is the ceiling
- **Behavior contracts past 5 bullets** — re-deriving the impl in markdown; tighten with a sharper reference
- **References that paste cited code inline** — duplicates what the executor reads anyway, and rots
- Behavior contracts using vague verbs ("validate", "handle", "process") instead of naming observable behavior
- **Test helpers invented in the plan when an existing one fits** — grep before authoring
- **Helpers called without a signature** — the executor guesses, and guesses wrong
- **Speculative edge-case piling** — 5+ boundary tests "just in case"
- **Step 4 demanding absolute green** — pre-existing red is out of scope; diff against the baseline
- **Modify-file tasks with no sweep**, or a sweep that is not an enumerated list
- **Any step asking the executor to confirm exhaustive absence** ("grep and confirm zero remaining") — no terminating check; enumerate instead
- Patterns introduced for a single use site
- Commit messages that say "WIP" or describe multiple unrelated changes
