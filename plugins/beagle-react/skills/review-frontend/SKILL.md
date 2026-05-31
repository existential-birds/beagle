---
description: Comprehensive React/TypeScript frontend code review with per-area review skills, run in parallel where the agent supports subagents and sequentially otherwise.
name: review-frontend
disable-model-invocation: true
---

# Frontend Code Review

## Arguments

- `--parallel`: Hint to fan out per technology area when the agent supports subagents (see Step 5). When unsupported, the review runs sequentially with identical output.
- Path: Target directory (default: current working directory)

## Step 1: Identify Changed Files

```bash
git diff --name-only $(git merge-base HEAD main)..HEAD | grep -E '\.(tsx?|jsx?|mjs|cjs|css)$|^(remix|vite)\.config\.'
```

## Step 2: Detect Technologies

```bash
# Detect Remix v2 (any official adapter). When matched, the Remix-specific
# surface is delegated to the review-remix-v2 skill in Step 4.
grep -E '"@remix-run/(react|node|cloudflare|deno|serve)"' package.json | head -3

# Detect React Flow
grep -r "@xyflow/react\|ReactFlow\|useNodesState" --include="*.tsx" -l | head -3

# Detect Zustand
grep -r "from 'zustand'\|create\(\(" --include="*.ts" --include="*.tsx" -l | head -3

# Detect Tailwind v4
grep -r "@theme\|@layer theme" --include="*.css" -l | head -3

# Check for test files
git diff --name-only $(git merge-base HEAD main)..HEAD | grep -E '\.test\.tsx?$'
```

## Step 3: Load Verification Protocol

Load the [review-verification-protocol](../review-verification-protocol/SKILL.md) skill before any substantive judgment on code.

**Pass before Step 5:** The skill is loaded (or its checklist is open in context). Do not classify severity or write findings until this gate clears.

## Step 4: Load Skills

Read each applicable skill below (open its `SKILL.md`) so its guidance is in context before you review that area.

**Remix v2 branch (Step 2 detected `@remix-run/*` in package.json):**

- Load [review-remix-v2](../review-remix-v2/SKILL.md) — umbrella orchestrator that loads all six Remix v2 area review skills (routing, data-flow, forms, error-boundaries, perf/SSR, meta+sessions) with its own detection telemetry. Run it for the Remix-specific surface and consolidate its findings into this review's output.
- Do NOT also load [react-router-code-review](../react-router-code-review/SKILL.md) — Remix v2 sits on React Router v6 but routes through Remix's route module conventions, which [remix-v2-routing-review](../remix-v2-routing-review/SKILL.md) (loaded via the umbrella) covers in that context.
- Still load [shadcn-code-review](../shadcn-code-review/SKILL.md) and the conditional skills below — they're orthogonal to the Remix layer and apply to component/styling/state code regardless of router.

**Non-Remix branch (default):**

- [react-router-code-review](../react-router-code-review/SKILL.md)
- [shadcn-code-review](../shadcn-code-review/SKILL.md)

**Conditionally load based on detection (both branches):**

| Condition | Skill |
|-----------|-------|
| @xyflow/react detected | [react-flow-code-review](../react-flow-code-review/SKILL.md) |
| Zustand detected | [zustand-state](../zustand-state/SKILL.md) |
| Tailwind v4 detected | [tailwind-v4](../tailwind-v4/SKILL.md) |
| Test files changed | [vitest-testing](../vitest-testing/SKILL.md) |

## Step 5: Review

**If the agent supports subagents** (and `--parallel` is requested or appropriate), dispatch one subagent per technology area in parallel; **otherwise** run the same areas sequentially in a single context. Both paths produce identical output.

Parallel path:
1. Detect all technologies upfront
2. Dispatch one subagent per technology area, each loading its skill and reviewing its domain
3. Wait for all subagents to return
4. Consolidate findings

Sequential path:
1. Load applicable skills
2. Review React Router patterns first
3. Review shadcn/ui patterns
4. Review detected technology areas
5. Consolidate findings

## Step 6: Verify Findings

Before reporting any issue:
1. Re-read the actual code (not just diff context)
2. For "unused" claims - did you search all references?
3. For "missing" claims - did you check framework/parent handling?
4. For syntax issues - did you verify against current version docs?
5. Remove any findings that are style preferences, not actual issues

**Pass before promoting to Critical/Major:** For that item, (2)–(4) are satisfied with a concrete artifact when applicable — e.g. opened file at `FILE:LINE`, grep/search output for references, or cited parent/framework code — not only diff context.

## Step 7: Review Convergence

### Single-Pass Completeness

You MUST report ALL issues across ALL categories (style, logic, types, tests, security, performance) in a single review pass. Do not hold back issues for later rounds.

Before submitting findings, ask yourself:
- "If all my recommended fixes are applied, will I find NEW issues in the fixed code?"
- "Am I requesting new code (tests, types, modules) that will itself need review?"

If yes to either: include those anticipated downstream issues NOW, in this review, so the author can address everything at once.

### Scope Rules

- Review ONLY the code in the diff and directly related existing code
- Do NOT request new features, test infrastructure, or architectural changes that didn't exist before the diff
- If test coverage is missing, flag it as ONE Minor issue ("Missing test coverage for X, Y, Z") — do NOT specify implementation details like mock libraries, behaviour extraction, or dependency injection patterns that would introduce substantial new code
- Typespecs, documentation, and naming issues are Minor unless they affect public API contracts
- Do NOT request adding new dependencies (e.g. Mox, testing libraries, linter plugins)

### Fix Complexity Budget

Fixes to existing code should be flagged at their real severity regardless of size.

However, requests for **net-new code that didn't exist before the diff** must be classified as Informational:
- Adding a new dependency (e.g. Mox, a linter plugin)
- Creating entirely new modules, files, or test suites
- Extracting new behaviours, protocols, or abstractions

These are improvement suggestions for the author to consider in future work, not review blockers.

### Iteration Policy

If this is a re-review after fixes were applied:
- ONLY verify that previously flagged issues were addressed correctly
- Do NOT introduce new findings unrelated to the previous review's issues
- Accept Minor/Nice-to-Have issues that weren't fixed — do not re-flag them
- The goal of re-review is VERIFICATION, not discovery

## Output Format

```markdown
## Review Summary

[1-2 sentence overview of findings]

## Issues

### Critical (Blocking)

1. [FILE:LINE] ISSUE_TITLE
   - Issue: Description of what's wrong
   - Why: Why this matters (bug, a11y, perf, security)
   - Fix: Specific recommended fix

### Major (Should Fix)

2. [FILE:LINE] ISSUE_TITLE
   - Issue: ...
   - Why: ...
   - Fix: ...

### Minor (Nice to Have)

N. [FILE:LINE] ISSUE_TITLE
   - Issue: ...
   - Why: ...
   - Fix: ...

### Informational (For Awareness)

N. [FILE:LINE] SUGGESTION_TITLE
   - Suggestion: ...
   - Rationale: ...

## Good Patterns

- [FILE:LINE] Pattern description (preserve this)

## Verdict

Ready: Yes | No | With fixes 1-N (Critical/Major only; Minor items are acceptable)
Rationale: [1-2 sentences]
```

## Post-Fix Verification

After fixes are applied, run:

```bash
npm run lint
npm run typecheck
npm run test
```

All checks must pass before approval.

## Gates

Advance in order; do not skip a **pass condition** by restating it informally.

1. **Scope recorded** — **Pass when:** You have the output of the Step 1 command (or an explicit substitute path list) naming what is in scope for this review.
2. **Protocol + branch skills loaded** — **Pass when:** [review-verification-protocol](../review-verification-protocol/SKILL.md) and [shadcn-code-review](../shadcn-code-review/SKILL.md) are loaded, **and** either (a) Step 2 found Remix v2 and [review-remix-v2](../review-remix-v2/SKILL.md) is loaded (without [react-router-code-review](../react-router-code-review/SKILL.md)), or (b) Step 2 found no Remix v2 and [react-router-code-review](../react-router-code-review/SKILL.md) is loaded — before first severity judgment.
3. **Conditional skills** — **Pass when:** For each Step 2 detection row (Remix v2, @xyflow/react, Zustand, Tailwind v4, test files), you either loaded the listed skill or recorded that detection was negative (which command returned no matches).
4. **Critical/Major evidence** — **Pass when:** Each such finding cites `FILE:LINE` that exists in the tree and meets the Step 6 pass rule for that finding type.
5. **Single output** — **Pass when:** The Issues section uses one continuous numbering sequence and this deliverable satisfies Step 7 single-pass completeness (no withheld issue types or rounds).

## Rules

- Load skills BEFORE reviewing (not after)
- Number every issue sequentially (1, 2, 3...)
- Include FILE:LINE for each issue
- Separate Issue/Why/Fix clearly
- Categorize by actual severity
- Don't assume Next.js patterns (no "use client")
- Run verification after fixes
- Report ALL issues in a single pass — do not hold back findings for later iterations
- Re-reviews verify previous fixes ONLY — no new discovery
- Requests for net-new code (new modules, dependencies, test suites) are Informational, not blocking
- The Verdict ignores Minor and Informational items — only Critical and Major block approval
