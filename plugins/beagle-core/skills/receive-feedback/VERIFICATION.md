# Verification Workflow

## Principle

Do not trust feedback. Verify it against the current codebase state.

## Verification by Feedback Type

| Feedback Type | Verification Method |
|---------------|---------------------|
| "Unused code" | `Grep` for usage across codebase |
| "Bug/Error" | Reproduce with test or script |
| "Missing import" | Check file, run linter |
| "Style/Convention" | Check existing patterns in codebase |
| "Performance issue" | Profile or benchmark if possible |
| "Security concern" | Trace data flow, check sanitization |

## Verification Steps

For EACH feedback item:

1. **Locate**: Find the referenced code (`Read` tool)
2. **Context**: Understand why it exists (`Grep` for usage, git blame)
3. **Validate**: Test the claim (run tests, reproduce issue)
4. **Classify**: VALID (claim holds) or INVALID (claim disproved by an artifact). If genuinely unparseable, NEEDS CLARIFICATION — but never use this to dodge a fixable item.
5. **Document**: Record the artifact (path:line, command output, grep hit) before proceeding.

A claim is INVALID only when verification produced a concrete artifact disproving it. "I don't think this matters" is not verification — it is deferral, which is forbidden.

## Using Code-Review Skills for Verification

When feedback relates to a specific domain, load the relevant skill:

| Domain | Skill to Reference |
|--------|-------------------|
| Python quality | python-code-review |
| FastAPI routes | fastapi-code-review |
| SQLAlchemy ORM | sqlalchemy-code-review |
| React components | shadcn-code-review |
| Routing | react-router-code-review |
| Database queries | postgres-code-review |
| Tests | pytest-code-review, vitest-testing |

These skills contain the authoritative patterns for this codebase.
If feedback conflicts with skill guidance, flag for discussion.

## Example

Feedback: "Remove unused `validate_user` function"

Verification:
1. `Grep` for "validate_user" across codebase
2. Found: Called in `auth/middleware.py:45`
3. Classification: **INVALID** — function is used
4. Action: Reject with evidence in the pre-dispatch summary

Contrast — feedback: "Null check missing on `session` at `auth.py:42`"

Verification:
1. Read `auth.py` around line 42
2. Confirmed: `session.user_id` is dereferenced with no prior `if session is None` guard
3. Classification: **VALID**
4. Action: Add to the `launch fixes for ...` prompt; on confirm, fix the guard — via a dedicated subagent if subagents are supported (do not edit `auth.py` from the orchestrator in that branch), otherwise apply the fix sequentially yourself.
