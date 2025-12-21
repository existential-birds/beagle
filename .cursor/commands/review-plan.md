# Review Plan

Review implementation plans created by `superpowers:writing-plans` before execution.

## Arguments

- Path: Plan file to review (e.g., `docs/plans/2025-01-15-auth-feature.md`)

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

Based on detected tech stack, load relevant skills:

| Detected | Skill |
|----------|-------|
| Python | `python-code-review` |
| FastAPI | `fastapi-code-review` |
| SQLAlchemy | `sqlalchemy-code-review` |
| PostgreSQL | `postgres-code-review` |
| pytest | `pytest-code-review` |
| React | `react-code-review` |
| TypeScript | `typescript-code-review` |
| Go | `go-code-review` |

### Python Code Review Guidelines

Reviews Python code for type safety, async patterns, error handling, and common mistakes. Use when reviewing .py files, checking type hints, async/await usage, or exception handling.

**Review Checklist:**
- Type hints on all function parameters and return types
- No `Any` unless necessary (with comment explaining why)
- Proper `T | None` syntax (Python 3.10+)
- No blocking calls (`time.sleep`, `requests`) in async functions
- Proper `await` on all coroutines
- No bare `except:` clauses
- Specific exception types with context
- `raise ... from` to preserve stack traces
- No mutable default arguments
- Using `logger` not `print()` for output
- f-strings preferred over `.format()` or `%`

**Review Questions:**
1. Are all function signatures fully typed?
2. Are async functions truly non-blocking?
3. Do exceptions include meaningful context?
4. Are there any mutable default arguments?

### FastAPI Code Review Guidelines

Reviews FastAPI code for routing patterns, dependency injection, validation, and async handlers. Use when reviewing FastAPI apps, checking APIRouter setup, Depends() usage, or response models.

**Review Checklist:**
- APIRouter with proper prefix and tags
- All routes specify `response_model` for type safety
- Correct HTTP methods (GET, POST, PUT, DELETE, PATCH)
- Proper status codes (200, 201, 204, 404, etc.)
- Dependencies use `Depends()` not manual calls
- Yield dependencies have proper cleanup
- Request/Response models use Pydantic
- HTTPException with status code and detail
- All route handlers are `async def`
- No blocking I/O (`requests`, `time.sleep`, `open()`)
- Background tasks for non-blocking operations
- No bare `except` in route handlers

**Review Questions:**
1. Do all routes have explicit response models and status codes?
2. Are dependencies injected via Depends() with proper cleanup?
3. Do all Pydantic models validate inputs correctly?
4. Are all route handlers async and non-blocking?

### SQLAlchemy Code Review Guidelines

Reviews SQLAlchemy code for session management, relationships, N+1 queries, and migration patterns. Use when reviewing SQLAlchemy 2.0 code, checking session lifecycle, relationship() usage, or Alembic migrations.

**Review Checklist:**
- Sessions use context managers (`with`, `async with`)
- No session sharing across requests or threads
- Sessions closed/cleaned up properly
- `relationship()` uses appropriate `lazy` strategy
- Explicit `joinedload`/`selectinload` to avoid N+1
- No lazy loading in loops (N+1 queries)
- Using SQLAlchemy 2.0 `select()` syntax, not legacy `query()`
- Bulk operations use bulk_insert/bulk_update, not ORM loops
- Async sessions use proper async context managers
- Migrations are reversible with `downgrade()`
- Data migrations use `op.execute()` not ORM models
- Migration dependencies properly ordered

**Review Questions:**
1. Are all sessions properly managed with context managers?
2. Are relationships configured to avoid N+1 queries?
3. Are queries using SQLAlchemy 2.0 `select()` syntax?
4. Are all migrations reversible and properly tested?

### PostgreSQL Code Review Guidelines

Reviews PostgreSQL code for indexing strategies, JSONB operations, connection pooling, and transaction safety. Use when reviewing SQL queries, database schemas, JSONB usage, or connection management.

**Review Checklist:**
- WHERE/JOIN columns have appropriate indexes
- Composite indexes match query patterns (column order matters)
- JSONB columns use GIN indexes when queried
- Using proper JSONB operators (`->`, `->>`, `@>`, `?`)
- Connection pool configured with appropriate limits
- Connections properly released (context managers, try/finally)
- Appropriate transaction isolation level for use case
- No long-running transactions holding locks
- Advisory locks used for application-level coordination
- Queries use parameterized statements (no SQL injection)

**Review Questions:**
1. Will this query use an index or perform a sequential scan?
2. Are JSONB operations using appropriate operators and indexes?
3. Are database connections properly managed and released?
4. Is the transaction isolation level appropriate for this operation?
5. Could this cause deadlocks or long-running locks?

### Pytest Code Review Guidelines

Reviews pytest test code for async patterns, fixtures, parametrize, and mocking. Use when reviewing test_*.py files, checking async test functions, fixture usage, or mock patterns.

**Review Checklist:**
- Test functions are `async def test_*` for async code under test
- AsyncMock used for async dependencies, not Mock
- All async mocks and coroutines are awaited
- Fixtures in conftest.py for shared setup
- Fixture scope appropriate (function, class, module, session)
- Yield fixtures have proper cleanup in finally block
- @pytest.mark.parametrize for similar test cases
- No duplicated test logic across multiple test functions
- Mocks track calls properly (assert_called_once_with)
- patch() targets correct location (where used, not defined)
- No mocking of internals that should be tested
- Test isolation (no shared mutable state between tests)

**Review Questions:**
1. Are all async functions tested with async def test_*?
2. Are fixtures properly scoped with appropriate cleanup?
3. Can similar test cases be parametrized to reduce duplication?
4. Are mocks tracking calls and used at the right locations?

## Step 3: Launch 5 Parallel Agents

Use the `Task` tool to spawn 5 agents simultaneously. Each receives:
- Full plan content
- Detected tech stack
- Relevant skill content from Step 2

### Agent 1: Parallelization Analysis

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

### Agent 2: TDD & Over-Engineering Check

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

### Agent 3: Type & API Verification

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

### Agent 4: Library Best Practices

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

### Agent 5: Security & Edge Cases

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

After all agents complete, create consolidated report:

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

- Load skills BEFORE launching agents
- All 5 agents run in parallel via Task tool
- Reference Task:Step for each issue
- Provide copyable suggested edits for Critical/Major issues
- Save review before prompting user
- Never auto-execute plan; require user choice
- Number issues sequentially (1, 2, 3...)
