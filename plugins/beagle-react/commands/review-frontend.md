---
description: Comprehensive React/TypeScript frontend code review with optional parallel agents
---

# Frontend Code Review

## Arguments

- `--parallel`: Spawn specialized subagents per technology area
- Path: Target directory (default: current working directory)

## Step 1: Identify Changed Files

```bash
git diff --name-only $(git merge-base HEAD main)..HEAD | grep -E '\.(tsx?|css)$'
```

## Step 2: Detect Technologies

```bash
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

Load `beagle-react:review-verification-protocol` skill and keep its checklist in mind throughout the review.

## Step 4: Load Skills

Use the `Skill` tool to load each applicable skill (e.g., `Skill(skill: "beagle-react:react-router-code-review")`).

**Always load:**
- `beagle-react:react-router-code-review`
- `beagle-react:shadcn-code-review`

**Conditionally load based on detection:**

| Condition | Skill |
|-----------|-------|
| @xyflow/react detected | `beagle-react:react-flow-code-review` |
| Zustand detected | `beagle-react:zustand-state` |
| Tailwind v4 detected | `beagle-react:tailwind-v4` |
| Test files changed | `beagle-react:vitest-testing` |

## Step 5: Review

**Sequential (default):**
1. Load applicable skills
2. Review React Router patterns first
3. Review shadcn/ui patterns
4. Review detected technology areas
5. Consolidate findings

**Parallel (--parallel flag):**
1. Detect all technologies upfront
2. Spawn one subagent per technology area with `Task` tool
3. Each agent loads its skill and reviews its domain
4. Wait for all agents
5. Consolidate findings

## Step 6: Verify Findings

Before reporting any issue:
1. Re-read the actual code (not just diff context)
2. For "unused" claims - did you search all references?
3. For "missing" claims - did you check framework/parent handling?
4. For syntax issues - did you verify against current version docs?
5. Remove any findings that are style preferences, not actual issues

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

## Good Patterns

- [FILE:LINE] Pattern description (preserve this)

## Verdict

Ready: Yes | No | With fixes 1-N
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

## Rules

- Load skills BEFORE reviewing (not after)
- Number every issue sequentially (1, 2, 3...)
- Include FILE:LINE for each issue
- Separate Issue/Why/Fix clearly
- Categorize by actual severity
- Don't assume Next.js patterns (no "use client")
- Run verification after fixes
