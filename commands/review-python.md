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

## Step 2: Verify Linter Status

**CRITICAL**: Run project linters BEFORE flagging any style or type issues.

```bash
# Check if ruff config exists and run it
if [ -f "pyproject.toml" ] || [ -f "ruff.toml" ]; then
    ruff check <changed_files>
fi

# Check if mypy config exists and run it
if [ -f "pyproject.toml" ] || [ -f "mypy.ini" ]; then
    mypy <changed_files>
fi
```

**Rules:**
- If a linter passes for a specific rule (e.g., line length), DO NOT flag that issue manually
- Linter configuration is authoritative for style rules
- Only flag issues that linters cannot detect (semantic issues, architectural problems)

**Why:** Analysis of 24 review outcomes showed 4 false positives (17%) where reviewers flagged line-length violations that `ruff check` confirmed don't exist. The linter's configuration reflects intentional project decisions.

## Step 3: Detect Technologies

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

## Step 4: Load Skills

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

## Step 5: Review

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

### Before Flagging Optimization or Pattern Issues

1. **Check CLAUDE.md** for documented intentional patterns
2. **Check code comments** around the flagged area for "intentional", "optimization", or "NOTE:"
3. **Trace the code path** before claiming missing coverage or inconsistent handling
4. **Consider framework idioms** - what looks wrong generically may be correct for the framework

**Why:** Analysis showed rejections where reviewers flagged "inconsistent error handling" that was intentional optimization, and "missing test coverage" for code paths that don't exist.

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
