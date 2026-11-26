# Plan Document Template

Use this template when writing the plan document. Save to `.beagle/concepts/<slug>/plan.md`.

## Template

````markdown
# [Feature Name] Implementation Plan

> **Source spec:** `.beagle/concepts/<slug>/spec.md`
> **For downstream agents:** Execute task-by-task. Each task uses `- [ ]` checkboxes for tracking. Do not skip the test-first steps — they catch wiring bugs that pure-logic tests miss.

**Goal:** [One sentence describing what this builds, mirroring the spec's Core Value.]

**Architecture:** [2-3 sentences describing the approach — how the pieces fit together, what the data/control flow looks like at a high level.]

**Tech Stack:** [Key technologies, libraries, frameworks.]

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
- `path/to/another_file.ext` — [responsibility, 1 line]

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

[Show the assertions and the call site under test. Target ~15 lines or less. The seed/setup loops are recovered by the executor from existing types and helpers — name the helper (with signature if helpful) but do not implement it here. Assertions pin observable consequence — a value, a row, an output the next call would see — never dispatch.]

```
// Assertions + call site only. ~15 lines or less.
```

- [ ] **Step 2: Run test to verify it fails**

Run: `<exact project test command for this single test>`
Expected: FAIL — "<exact failure substring you expect to see>"

- [ ] **Step 3: Implement against the test**

**Files touched:** `path/to/impl.ext`

**Behavior contract** (3-5 bullets max; past 5, replace the rest with a tighter reference):
- [The new/changed behavior bullet 1 — what's different from the reference]
- [The new/changed behavior bullet 2]
- [The error or edge-case behavior the Step 1 test pins, if not covered above]

**Reference:** `path/to/analog.ext:line-line` — [one-sentence delta]. Pointer only; do NOT paste the cited code inline. The executor opens the file.

- [ ] **Step 4: Run the new test AND the relevant suite, verify both green**

Run: `<same test command as Step 2>` → Expected: PASS.
Then run: `<broader suite this task lives in — module, package, or contract suite>` → Expected: PASS with zero regressions. Specify the exact command; do not leave as "run the suite."

- [ ] **Step 5: Sweep modified files for leftovers**

Describe sweep targets in plain language: "remove stale references to `<old_name>`, the orphaned `<import>`, and doc-comments describing the old shape." The executor greps for them. Do NOT enumerate line numbers — they'll be wrong by execution time. New-file-only and config-only tasks skip this step.

- [ ] **Step 6: Commit**

```bash
git add <specific paths, not git add .>
git commit -m "<type>(<scope>): <imperative one-line summary>"
```

---

## Task 2: [Next Component or Behavior Name]

[Same structure — Files / Step 1: failing test / Step 2: verify failure / Step 3: behavior contract for impl / Step 4: verify pass / Step 5: sweep / Step 6: commit]

---

[... more tasks ...]

---

## Self-Review Outcome

[Short prose confirming the self-review pass was honest. Mention any spec gaps you closed, placeholders you killed, or assumptions you surfaced.]

- **Spec coverage:** [confirmed / list of gaps closed]
- **Placeholders:** [none / list of fixes]
- **Type consistency:** [verified across tasks]
- **Consumer check:** [every new public surface has a named production consumer in this plan / list of surfaces cut or tagged deferred]
- **Discriminating assertion:** [no test admits a false-pass impl; payload-preservation tests assert the sentinel in the damaged region through every structurally-distinct producer]
- **Project conventions:** [list the specific project rules followed — testing tier rules, comment policy, commit conventions]

````

## Guidelines

**Header:**
- The goal sentence should mirror the spec's Core Value, not invent a new one
- Architecture is *approach*, not implementation detail (those live in tasks)
- Tech stack should match the spec's Constraints; flag mismatches before drafting

**Assumptions:**
- Include only assumptions that are *load-bearing* — change them and the plan changes
- Don't list trivial defaults (e.g., "we'll use the existing test runner")
- Each assumption should be one a future reader could plausibly disagree with
- If a file the spec names has a comment or doc-header that contradicts the spec's characterization of it, that contradiction is an assumption-audit item

**Patterns:**
- Only introduce when a transformation repeats across 3+ tasks
- Never absorb the test code or the commit message — those stay per-task
- A pattern is a transformation shape + a reference example, not a stand-in for the task body

**File Structure:**
- Files to Create / Modify / Delete sections — keep them flat lists, one line each
- The 1-line responsibility is for the *file*, not the change inside it; don't pre-describe code here

**Tasks:**
- One cohesive unit per task. If you can't describe the task in 5 words, split it.
- Steps are exhaustive — the engineer/agent reads them top to bottom, no skipping
- **Recoverability rule** — after drafting each step, ask "can the executor recover this by reading the referenced file?" If yes, delete it. Verbosity is not specificity.
- **Test step bodies show assertions + call site, not setup ceremony** — ~15 lines or less; the seed loop is recovered from existing types and helpers
- **Tests reuse existing scaffolding** — grep for an existing helper/fixture/mock before inventing one in the plan; if no existing helper fits, name a specific one that was considered and why it didn't
- **YAGNI for tests — except payload-preservation invariants** — one test per spec requirement and per named bug class; no speculative input-space exhaustion. For preserve/recover/transform invariants, enumerate every structurally-distinct producer and assert the sentinel in the damaged region — those producers and the corrupted region *are* the spec, not speculative edge cases
- **Behavior contracts: 3-5 bullets, past 5 replace with reference** — the contract is the new/changed behavior, not a re-derivation of the impl
- **References point, they do not paste** — `file.ext:line-line` is the reference; do not inline the cited code
- **Modify-file tasks include a sweep step** — remove orphaned comments, unused imports, dead helpers in the modified files; describe targets in plain language, not line numbers
- Commands are *exact* — the executor copies and runs them as-is
- Expected outputs (FAIL/PASS messages) are *literal strings*, not paraphrases

**Self-Review Outcome:**
- A short honesty statement, not a re-run of the checklist
- If you didn't actually verify a dimension, say so — don't lie to future readers

## Examples of Good vs Bad Task Steps

| Bad step | Good step |
|----------|-----------|
| "Add validation" | "Test: assert `parse(\"\")` returns an empty-input error of the project's error type. Behavior contract: empty input → error variant named for the empty case, with a message naming the offending field." |
| "Run tests" | "Run: `<project test command for this one test>`. Expected: PASS — 1 test." |
| "Implement the controller" | (Split into 3-5 tasks, each with a failing test + behavior contract for one cohesive piece of controller behavior) |
| Code block with `// TODO` or `unimplemented!()` as final state | Behavior contract with specific bullets; no placeholder code |
| "Similar to Task 2" with no further information | A `Patterns` reference, plus the task's own files, test code, and commit |
| Test asserting `the handler was called` | Test asserting `the row appears in storage` / `the file is written` / `the next request returns the new state` |
| Test invents `fn make_test_user()` without checking the codebase | Test uses existing `factories::user()` / `fixtures::user()`; or, if absent, the plan names the existing factories that were considered and why none fit |
| 12 boundary tests for one parser ("empty, single char, leading whitespace, trailing whitespace, only whitespace, unicode emoji, BOM, …") | One test per spec-required behavior; one test per named bug class from the Assumption Audit. Speculative inputs go to a fuzz harness if one exists, otherwise omit. |
| Task refactor lands but file still has `// returns the old PG pool` comments referring to the deleted field | Sweep step in the same task removes the orphaned comment alongside the impl change |
| Test body: 60 lines of imports + 5-iteration seeding loop + 6 assertions across 4 follow-on queries | Test body: ~12 lines — one helper call to seed, the call site under test, 2-3 assertions on observable consequence. Setup is recovered from existing types and helpers. |
| Reference: a 4-line `match` block pasted from the file under refactor | Reference: `launch.rs:397-400` — one-sentence delta describing what the new shape is. The executor opens the file. |
| Behavior contract enumerates every column, type, index, and rationale for a new schema | Behavior contract: "Tables/columns/indexes match `existing_schema.sql` with `<one-sentence delta>`. Types per project's standard codec defaults." |
| Sweep step lists "line 71-72, lines 117-122, line 194" | Sweep step: "remove stale references to `pool`, `session_store_override`, and the orphaned `PgPool` import in the modified files." The executor greps. |

## Anti-Patterns To Reject During Self-Review

- Tasks that produce code without a failing-test step before the implementation step
- "Step 1: Implement X" with no preceding test
- Test steps that assert dispatch rather than consequence
- **Test bodies past ~15 lines** — setup ceremony has crept in; the executor recovers seed loops from existing types and helpers
- **Implementation steps that contain speculative code blocks** — the planner is guessing at signatures and library shapes the executor will actually see; replace with a behavior contract
- **Behavior contracts past 5 bullets** — re-deriving the impl in markdown; tighten with a sharper reference
- **References that paste cited code inline** — duplicates what the executor reads anyway, and rots
- Behavior contracts that use vague verbs ("validate", "handle", "process") instead of naming the observable behavior
- **Test helpers invented in the plan when an existing one in the codebase fits** — grep before authoring
- **Speculative edge-case piling** — 5+ boundary tests for one function "just in case"; pin the spec, not every conceivable input
- **Modify-file tasks with no sweep** — leaves stale comments, unused imports, and dead helpers in the file the task just touched
- **Sweep steps enumerating line numbers** — line numbers rot; the executor greps. Describe targets by name (`pool`, `PgPool import`, doc-comments referring to the old shape).
- Patterns introduced for a single use site (don't DRY for the sake of it)
- Commit messages that say "WIP" or describe multiple unrelated changes
