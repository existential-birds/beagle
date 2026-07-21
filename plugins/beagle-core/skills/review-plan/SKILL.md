---
name: review-plan
description: Standalone review of an implementation plan before anyone executes it - checks parallelization, TDD discipline, type/API accuracy, library usage, and security. User-invoked on demand against a plan file path; no plan-writing skill dispatches it automatically. Use when the user says "review this plan", "check my plan before I run it", or points at a plan document and asks whether it is safe to execute. Works on any plan carrying Goal/Architecture/Tech Stack headers, including output from a plan-writing skill at .beagle/concepts/<slug>/plan.md or .beagle/plans/<slug>/plan.md. Produces a review file next to the plan plus a verdict; never edits or executes the plan.
disable-model-invocation: true
user-invocable: true
---

# Review Plan

Review an implementation plan before execution, and write the review to disk next to the plan.

## How this skill is invoked

**Standalone and user-invoked.** No plan-writing skill calls this one. A plan-writing skill's own self-review covers whether the plan matches its spec; this skill is the separate, optional, after-the-fact check the user runs when a plan is high-stakes, long, or written by someone else.

Run it when the user asks for it, on a plan file path. It never edits the plan and never executes it — output is a review document plus a verdict.

## Arguments

- **Path** — plan file to review (e.g. `.beagle/plans/auth-rework/plan.md`, `docs/plans/2025-01-15-auth-feature.md`).

## Stage entry: echo once

Per `verification-budget` **one-echo**: at stage entry, read the plan file in **this turn** and echo its Goal / Architecture / Tech Stack headers plus the task headings. That single echo grounds every verdict this run produces. Do not re-echo per finding.

Individual findings cite their source — plan heading or step number for plan findings, `file:line` plus code for codebase claims — but citation is not a re-echo. If your mental model differs from the freshly read source, the source wins.

This review is `verification-budget` tier **REVERSIBLE**: it authorizes writing a report, nothing else. No evidence gate beyond the entry echo.

## Hard gates

Four gates, stated once. Later steps reference them by number; they are not restated.

| # | Gate | Pass when |
|---|------|-----------|
| **G1** | Plan reachable and parsed | Reading `Path` succeeds. `**Goal:**`, `**Architecture:**`, `**Tech Stack:**` are quoted, **or** each absent field is recorded as a finding. |
| **G2** | Skills loaded | Every skill a selected lens depends on is loaded, or recorded `N/A — <reason>`. |
| **G3** | Selected lenses captured | Each **selected** lens has a labeled output block. Each **skipped** lens has a one-line skip note naming the unmet trigger. Selected + skipped = 5. |
| **G4** | Review file on disk | `[plan-dir]/[plan-basename]-review.md` exists and reads back. |

Order: G1 and G2 before Step 3; G3 before Step 4; G4 before the Step 5 prompt.

## Step 1: Read and parse the plan (G1)

Extract:

1. **Header fields** — `**Goal:**`, `**Architecture:**`, `**Tech Stack:**`.
2. **Task inventory** — task count, task titles, declared dependencies or batches.
3. **Signals for lens selection** (Step 3) — record each as present/absent while reading; this is a single pass over the plan, not a search:
   - new dependency added, or a version pinned
   - third-party library calls in plan code blocks
   - references to existing codebase symbols, types, or import paths
   - new exported/public symbols, routes, or schemas other code will consume
   - trust boundaries: request/user input parsing, network calls, auth/authz, secrets, SQL, subprocess/shell, filesystem writes
4. **Tech stack confirmation via file patterns** — `.py` → Python; `.ts`/`.tsx` → TypeScript; `.go` → Go; `pytest` → pytest; `vitest`/`jest` → JS/TS testing; `go test` → Go testing.

**Budget:** one pass over the plan. Stop when the header fields and the six signals above each have a recorded present/absent value. Tie-break: record the undetermined signal as *present* (selecting a lens is cheaper than missing one) and proceed.

## Step 2: Load skills (G2)

Load only the skills a **selected** lens will use — see Step 3 first if that ordering is cheaper.

| Detected | Skill |
|----------|-------|
| Python | `beagle-python:python-code-review` |
| FastAPI | `beagle-python:fastapi-code-review` |
| SQLAlchemy | `beagle-python:sqlalchemy-code-review` |
| PostgreSQL | `beagle-python:postgres-code-review` |
| pytest | `beagle-python:pytest-code-review` |
| React Router | `beagle-react:react-router-code-review` |
| React Flow | `beagle-react:react-flow-code-review` |
| shadcn/ui | `beagle-react:shadcn-code-review` |
| vitest | `beagle-react:vitest-testing` |
| Go | `beagle-go:go-code-review` |
| BubbleTea | `beagle-go:bubbletea-code-review` |

## Step 3: Run the selected review lenses (G3)

**Lenses are conditional**, and each receives only the **narrowest slice that answers its question** — never the whole plan, never a whole skill file. A lens whose trigger is unmet is **skipped with its note**; that is a passing outcome, not a gap.

| Lens | Runs when | Gets | Skip note when unmet |
|------|-----------|------|----------------------|
| 1. Parallelization | ≥3 tasks, or plan declares batches / concurrency | Task titles, declared dependencies, batch structure. No step bodies. | `SKIPPED — <n> task(s), no parallelization surface` |
| 2. TDD & over-engineering | ≥1 implementation task | Step bodies of implementation tasks only. | `SKIPPED — docs/config-only plan, no implementation tasks` |
| 3. Type & API verification | Code blocks reference **existing** symbols, types, or import paths | Those code blocks and the identifiers/imports they name. | `SKIPPED — plan adds only new files, no references to existing symbols` |
| 4. Library best practices | Plan adds a dependency, pins a version, or calls a third-party library | Dependency lines and third-party call sites, plus the relevant section of one loaded skill. | `SKIPPED — first-party and standard-library code only` |
| 5. Security & edge cases | Plan touches a trust boundary (input parsing, network, auth, secrets, SQL, subprocess, filesystem writes) | Only the steps touching those boundaries, plus the relevant section of one loaded skill. | `SKIPPED — no trust boundary in scope` |

Dispatch selected lenses in parallel as subagents when the harness supports them; otherwise run them sequentially yourself, producing the same labeled outputs.

**Budget:** one dispatch per selected lens. Stop when every selected lens has a labeled output and every skipped lens has a skip note (G3). Tie-break: a lens that returns nothing usable is recorded `INCONCLUSIVE — <what was missing>` and the review proceeds. Do not re-dispatch a lens.

### Lens 1: Parallelization analysis

```
Analyze whether this plan's tasks can be executed by parallel subagents.

INVESTIGATE:
1. Which tasks can run in parallel (no dependencies between them)?
2. Which tasks must be sequential (Task B consumes Task A's output)?
3. Any circular dependencies or blocking issues?
4. What is the critical path?

Return: recommended batch structure, maximum concurrent agents, and any
blocker that prevents parallelization.
```

### Lens 2: TDD & over-engineering check

```
Verify TDD discipline in these tasks.

CHECK each task for:
1. Test written BEFORE implementation (RED phase)
2. A step that runs the test and observes it fail
3. Minimal implementation to make it pass (GREEN phase)
4. Assertions on observable behavior, not on internal bookkeeping

LOOK FOR over-engineering: excessive mocking, unnecessary abstraction
layers, defensive code for impossible states, premature optimization.

Return: TDD adherence assessment and over-engineering concerns.
```

### Lens 3: Type & API verification

```
Verify that types and APIs named in these code blocks match the actual
codebase.

VERIFY, for each identifier and import in the supplied blocks:
1. The symbol exists at the stated path
2. Referenced properties exist on the type
3. Enum/variant values match
4. Import paths resolve

Do not audit anything outside the supplied blocks.

Return: mismatches with file:line references. If none, say so explicitly.
```

### Lens 4: Library best practices

```
Verify third-party library usage in the supplied call sites.

For each library referenced:
1. Are the signatures correct for the pinned/current version?
2. Any deprecated APIs?
3. Does the usage follow the library's documented pattern?
4. Are install commands correct?

Return: incorrect usage with the corrected form.
```

### Lens 5: Security & edge cases

```
Check the supplied trust-boundary steps for security gaps and missing
error handling.

VERIFY:
1. Input validation at the boundary
2. Error handling on network/DB/filesystem operations
3. Auth/authz checks where the boundary requires them
4. Edge cases: empty, N=1 vs N=many, concurrent access, partial failure

Return: security gaps and missing error handling, each tied to a step.
```

## Step 4: Synthesize the report (G3 → report)

```markdown
## Plan Review: [Feature name from plan]

**Plan:** `[path to plan file]`
**Tech Stack:** [detected technologies]

### Summary Table

| Criterion | Status | Notes |
|-----------|--------|-------|
| Parallelization | ✅ GOOD / ⚠️ ISSUES / ⊘ SKIPPED | [brief note or skip reason] |
| TDD Adherence | ✅ GOOD / ⚠️ ISSUES / ⊘ SKIPPED | [brief note or skip reason] |
| Type/API Match | ✅ GOOD / ⚠️ ISSUES / ⊘ SKIPPED | [brief note or skip reason] |
| Library Practices | ✅ GOOD / ⚠️ ISSUES / ⊘ SKIPPED | [brief note or skip reason] |
| Security/Edge Cases | ✅ GOOD / ⚠️ ISSUES / ⊘ SKIPPED | [brief note or skip reason] |

### Issues Found

#### Critical (must fix before execution)

1. [Task N, Step M] ISSUE_CODE
   - Issue: what is wrong
   - Why: impact if unfixed
   - Fix: specific change
   - Suggested edit:
   ```
   [replacement content]
   ```

#### Major (should fix)

2. [Task N] ISSUE_CODE
   - Issue: …
   - Why: …
   - Fix: …

#### Minor (nice to have)

3. [Task N] ISSUE_CODE
   - Issue: …
   - Fix: …

### Verdict

**Ready to execute?** Yes | With fixes (1-N) | No

**Reasoning:** [1-2 sentences]
```

Skipped lenses appear in the summary table as `⊘ SKIPPED` with their skip note. They never produce issues and never block the verdict.

## Step 5: Save the review and prompt (G4)

Save next to the plan:

- Plan: `.beagle/plans/auth-rework/plan.md` → Review: `.beagle/plans/auth-rework/plan-review.md`
- Plan: `docs/plans/2025-01-15-feature.md` → Review: `docs/plans/2025-01-15-feature-review.md`

**Review file header:**

```markdown
# Plan Review: [Feature name]

> **To apply fixes:** open a new session and run:
> `Read this file, then apply the suggested fixes to [plan path]`

**Reviewed:** [current date/time]
**Verdict:** [Yes | With fixes (1-N) | No]
**Lenses run:** [n of 5 — list skipped lenses and reasons]

---
```

Then prompt:

```markdown
---

## Next Steps

**Review saved to:** `[review file path]`

**Options:**

1. **Apply fixes now** — edit the plan file to address issues
2. **Save & fix later** — open a new session to apply fixes
3. **Proceed anyway** — execute the plan despite issues (not recommended with Critical open)

Which option?
```

## Rules

- Reference issues by Task:Step; number them sequentially (1, 2, 3…).
- Provide copyable suggested edits for Critical and Major issues.
- Never edit the plan and never auto-execute it — the user chooses.
- A skipped lens is a recorded outcome, not a gap. Do not run a lens "just in case."
