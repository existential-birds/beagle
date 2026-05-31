---
name: review-plan
description: Review implementation plans for parallelization, TDD, types, libraries, and security before execution
disable-model-invocation: true
---

# Review Plan

Review implementation plans (such as those produced by a plan-writing skill) before execution.

## Arguments

- Path: Plan file to review (e.g., `docs/plans/2025-01-15-auth-feature.md`)

## Anti-confabulation (gate 0 — runs before every other gate)

Before issuing **any** verdict — flag a gap, raise an issue, or assign a verdict — you MUST echo the exact artifact you are judging, quoted from a source you read in **this** turn:

- For a plan finding: the **plan step or section text** under review, quoted from the plan file read freshly now (not recalled from earlier in the session) — cite the heading or step number it came from.
- For a claim about the codebase the plan touches (a type, API, or file the plan references): the **file:line** plus cited code, read freshly now.

> The artifact is the only source of truth. **Never** infer what the plan says from the branch name, the working directory, surrounding files, or recollection. If your mental model differs from the freshly read source, **the source wins.** A verdict issued without a same-turn echo of its target is invalid — emit the echo first, or do not emit the verdict.

This gate exists because an LLM under contextual priming will confidently flag content that is not in the plan. It runs **before** the hard gates below.

## Hard gates (sequence)

Do not skip ahead; each step **passes** only when the condition is objectively satisfied (artifact path, tool success, or labeled capture—not “I read it mentally”).

1. **Plan file reachable** — **Pass:** reading `Path` succeeds; if not, stop and report the missing path. **Pass:** You can quote or point to where `**Goal:**`, `**Architecture:**`, and `**Tech Stack:**` appear, *or* you record “header field X absent” as a finding before Step 2.
2. **Skills loaded before reviews** — **Pass:** For each row you will rely on in Step 2’s table, the corresponding skill is loaded (or you record explicit `N/A` with reason, e.g. stack not present). Do **not** start the Step 3 reviews until this gate passes.
3. **Five reviews captured** — **Pass:** You have five labeled artifacts (one per review lens): pasted outputs, subagent transcripts, or saved snippet files. **Pass:** Each of the five INVESTIGATE/CHECK/VERIFY prompts has a corresponding response block before Step 4.
4. **Review file on disk before user prompt** — **Pass:** The file at `[plan-dir]/[plan-basename]-review.md` exists; **Pass:** reading that path succeeds. Only then run the “Next Steps” / options prompt in Step 5.

## Step 1: Read and Parse Plan

Read the plan file and extract:

1. **Header fields:**
   - `**Goal:**` - Feature description
   - `**Architecture:**` - Approach summary
   - `**Tech Stack:**` - Technologies used

2. **Verify via file patterns:**
   - `.py` files → Python
   - `.ts`, `.tsx` files → TypeScript
   - `.go` files → Go
   - `pytest` commands → pytest
   - `vitest`, `jest` commands → JavaScript/TypeScript testing
   - `go test` commands → Go testing

## Step 2: Load Skills

Load each applicable skill (e.g. the **python-code-review** skill).

Based on detected tech stack, load relevant skills:

| Detected | Skill |
|----------|-------|
| Python | [python-code-review](../../../beagle-python/skills/python-code-review/SKILL.md) |
| FastAPI | [fastapi-code-review](../../../beagle-python/skills/fastapi-code-review/SKILL.md) |
| SQLAlchemy | [sqlalchemy-code-review](../../../beagle-python/skills/sqlalchemy-code-review/SKILL.md) |
| PostgreSQL | [postgres-code-review](../../../beagle-python/skills/postgres-code-review/SKILL.md) |
| pytest | [pytest-code-review](../../../beagle-python/skills/pytest-code-review/SKILL.md) |
| React Router | [react-router-code-review](../../../beagle-react/skills/react-router-code-review/SKILL.md) |
| React Flow | [react-flow-code-review](../../../beagle-react/skills/react-flow-code-review/SKILL.md) |
| shadcn/ui | [shadcn-code-review](../../../beagle-react/skills/shadcn-code-review/SKILL.md) |
| vitest | [vitest-testing](../../../beagle-react/skills/vitest-testing/SKILL.md) |
| Go | [go-code-review](../../../beagle-go/skills/go-code-review/SKILL.md) |
| BubbleTea | [bubbletea-code-review](../../../beagle-go/skills/bubbletea-code-review/SKILL.md) |

## Step 3: Run the Five Review Lenses

Run all five review lenses below. **If the agent supports subagents**, dispatch the five in parallel as separate subagents; **otherwise** work through them sequentially yourself, producing the same five labeled outputs. Each review receives:
- Full plan content
- Detected tech stack
- Relevant skill content from Step 2

### Lens 1: Parallelization Analysis

```
Analyze whether this implementation plan can be executed by parallel subagents.

INVESTIGATE:
1. Which tasks can run in parallel (no dependencies between them)?
2. Which tasks must be sequential (Task B depends on Task A output)?
3. Are there any circular dependencies or blocking issues?
4. What is the critical path?

Return:
- Recommended batch structure for parallel execution
- Maximum concurrent agents
- Any blocking issues that prevent parallelization
```

### Lens 2: TDD & Over-Engineering Check

```
Verify TDD discipline in this implementation plan.

CHECK each task for:
1. Tests written BEFORE implementation (RED phase)
2. Step to run test and verify it fails
3. Minimal implementation to make test pass (GREEN phase)
4. Tests focus on behavior, not implementation details

LOOK FOR over-engineering:
- Excessive mocking (testing implementation vs behavior)
- Too many abstraction layers
- Defensive code for impossible scenarios
- Premature optimization

Return: TDD adherence assessment and over-engineering concerns.
```

### Lens 3: Type & API Verification

```
Verify types and APIs in the plan match the actual codebase.

SEARCH the codebase for:
1. All types referenced in the plan's code blocks
2. Existing type definitions
3. API endpoint contracts (request/response shapes)
4. Import paths

VERIFY:
1. All properties referenced exist in the types
2. Enum values match between plan and codebase
3. Import paths are correct
4. No type mismatches

Return: List of mismatches with file:line references.
```

### Lens 4: Library Best Practices

```
Verify library usage in this plan follows best practices.

For each library referenced:
1. Are function signatures correct for current versions?
2. Are there deprecated APIs being used?
3. Does usage follow library documentation?
4. Are installation commands correct?

Check against loaded skills for technology-specific guidance.

Return: Incorrect API usage with recommendations.
```

### Lens 5: Security & Edge Cases

```
Check for security gaps and missing error handling.

VERIFY:
1. Input validation at system boundaries
2. Error handling in API/DB operations
3. Auth/authz checks where needed
4. Edge cases are handled

Return: Security gaps and missing error handling.
```

## Step 4: Synthesize Report

**Gate:** Hard gate 3 must pass (five labeled review outputs present). Once all five lenses complete (parallel subagents or sequential passes), create the consolidated report:

```markdown
## Plan Review: [Feature Name from plan]

**Plan:** `[path to plan file]`
**Tech Stack:** [Detected technologies]

### Summary Table

| Criterion | Status | Notes |
|-----------|--------|-------|
| Parallelization | ✅ GOOD / ⚠️ ISSUES | [Brief note] |
| TDD Adherence | ✅ GOOD / ⚠️ ISSUES | [Brief note] |
| Type/API Match | ✅ GOOD / ⚠️ ISSUES | [Brief note] |
| Library Practices | ✅ GOOD / ⚠️ ISSUES | [Brief note] |
| Security/Edge Cases | ✅ GOOD / ⚠️ ISSUES | [Brief note] |

### Issues Found

#### Critical (Must Fix Before Execution)

1. [Task N, Step M] ISSUE_CODE
   - Issue: What's wrong
   - Why: Impact if not fixed
   - Fix: Specific change
   - Suggested edit:
   ```
   [replacement content]
   ```

#### Major (Should Fix)

2. [Task N] ISSUE_CODE
   - Issue: ...
   - Why: ...
   - Fix: ...

#### Minor (Nice to Have)

3. [Task N] ISSUE_CODE
   - Issue: ...
   - Fix: ...

### Verdict

**Ready to execute?** Yes | With fixes (1-N) | No

**Reasoning:** [1-2 sentence assessment]
```

## Step 5: Save Review and Prompt

**Gate:** After writing the review file, satisfy Hard gate 4 (reading the review path succeeds) before prompting the user.

**Save review** to same directory as plan:
- Plan: `docs/plans/2025-01-15-feature.md`
- Review: `docs/plans/2025-01-15-feature-review.md`

**Review file header:**

```markdown
# Plan Review: [Feature Name]

> **To apply fixes:** Open new session, run:
> `Read this file, then apply the suggested fixes to [plan path]`

**Reviewed:** [Current date/time]
**Verdict:** [Yes | With fixes (1-N) | No]

---
```

**Prompt user:**

```markdown
---

## Next Steps

**Review saved to:** `[review file path]`

**Options:**

1. **Apply fixes now** - Edit the plan file to address issues
2. **Save & fix later** - Open new session to apply fixes
3. **Proceed anyway** - Execute plan despite issues (not recommended for Critical)

Which option?
```

## Rules

- Satisfy Hard gates 1–2 before Step 3; Hard gate 3 before Step 4; Hard gate 4 before the Step 5 options prompt
- Load skills BEFORE running the review lenses (Hard gate 2)
- Run all 5 review lenses — in parallel via subagents when the agent supports them, otherwise sequentially
- Reference Task:Step for each issue
- Provide copyable suggested edits for Critical/Major issues
- Save review before prompting user (Hard gate 4)
- Never auto-execute plan; require user choice
- Number issues sequentially (1, 2, 3...)
