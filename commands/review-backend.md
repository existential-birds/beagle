---
description: Comprehensive Python/FastAPI backend code review with optional parallel agents
---

# Backend Code Review

## Arguments

- `--parallel`: Spawn specialized subagents per technology area
- Path: Target directory (default: current working directory)

## Step 1: Identify Changed Files

```bash
git diff --name-only $(git merge-base HEAD main)..HEAD | grep -E '\.py$'
```

## Step 2: Detect Technologies

```bash
# Detect Pydantic-AI
grep -r "pydantic_ai\|@agent\.tool\|RunContext" --include="*.py" -l | head -3

# Detect SQLAlchemy
grep -r "from sqlalchemy\|Session\|relationship" --include="*.py" -l | head -3

# Detect Postgres-specific
grep -r "psycopg\|asyncpg\|JSONB\|GIN" --include="*.py" -l | head -3

# Check for test files
git diff --name-only $(git merge-base HEAD main)..HEAD | grep -E 'test.*\.py$'
```

## Step 3: Load Skills

**Always load:**
- `beagle:python-code-review`
- `beagle:fastapi-code-review`

**Conditionally load based on detection:**

| Condition | Skill |
|-----------|-------|
| Test files changed | `beagle:pytest-code-review` |
| Pydantic-AI detected | `beagle:pydantic-ai-common-pitfalls` |
| SQLAlchemy detected | `beagle:sqlalchemy-code-review` |
| Postgres detected | `beagle:postgres-code-review` |

## Step 4: Review

**Sequential (default):**
1. Load applicable skills
2. Review Python quality issues first
3. Review FastAPI patterns
4. Review detected technology areas
5. Consolidate findings

**Parallel (--parallel flag):**
1. Detect all technologies upfront
2. Spawn one subagent per technology area with `Task` tool
3. Each agent loads its skill and reviews its domain
4. Wait for all agents
5. Consolidate findings

## Output Format

```markdown
## Review Summary

[1-2 sentence overview of findings]

## Issues

### Critical (Blocking)

1. [FILE:LINE] ISSUE_TITLE
   - Issue: Description of what's wrong
   - Why: Why this matters (bug, type safety, security)
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
ruff check .
mypy .
pytest
```

All checks must pass before approval.

## Rules

- Load skills BEFORE reviewing (not after)
- Number every issue sequentially (1, 2, 3...)
- Include FILE:LINE for each issue
- Separate Issue/Why/Fix clearly
- Categorize by actual severity
- Run verification after fixes
