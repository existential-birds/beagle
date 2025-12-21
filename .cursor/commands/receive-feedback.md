# Receive Feedback Command

Process external code review feedback using verification-first discipline.

## Usage

```
/receive-feedback path/to/feedback.md
```

## Workflow

1. **Read** the feedback file at `$ARGUMENTS`
2. **Parse** individual feedback items (numbered, bulleted, or freeform)
3. **Process** each item through verify → evaluate → execute workflow
4. **Produce** structured response summary
5. **Prompt** whether to log to `.feedback-log.csv`

## Expected Feedback File Format

The feedback file should contain numbered or bulleted items:

```markdown
1. Remove unused import on line 15
2. Add error handling to the API call
3. Consider using a generator for large datasets
4. Fix typo in variable name: `usr` → `user`
```

Or freeform prose - extract actionable items from the text.

## Example

```
/receive-feedback reviews/pr-123-feedback.md
```

Reads the file, processes each item with technical verification,
and outputs a structured response table.

---

# Processing Framework

## Core Principle

**Verify before implementing. Ask before assuming.**

No performative agreement. Technical correctness over social comfort.

## Quick Reference

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│   VERIFY    │ ──▶ │   EVALUATE   │ ──▶ │   EXECUTE   │
│ (tool-based)│     │ (decision    │     │ (implement/ │
│             │     │  matrix)     │     │  reject/    │
└─────────────┘     └──────────────┘     │  defer)     │
                                         └─────────────┘
```

## When To Use

- Receiving code review from another LLM session
- Processing PR review comments
- Evaluating CI/linter feedback
- Handling suggestions from pair programming

---

# 1. Verification Workflow

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
4. **Document**: Note verification result before proceeding

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
3. Result: **Feedback incorrect** - function is used
4. Action: Push back with evidence

---

# 2. Evaluation Rules

## Decision Matrix

| Condition | Action | Response |
|-----------|--------|----------|
| **Correct & In Scope** | Implement immediately | "Fixed in [file:line]" |
| **Correct but Out of Scope** | Defer | "Valid point. Out of scope; added to backlog." |
| **Technically Incorrect** | Reject with evidence | "Verified: [evidence]. Maintaining current implementation." |
| **Ambiguous / Unclear** | STOP and ask | "Clarification needed: [specific question]" |
| **Violates YAGNI** | Reject | "Not currently used by any consumer. Skipping (YAGNI)." |
| **Conflicts with codebase patterns** | Flag for discussion | "Conflicts with established pattern in [location]. Discuss?" |

## Evaluation Order

Process feedback items in this order:

1. **Clarify** - Resolve all ambiguous items first
2. **Critical** - Security issues, breaking bugs
3. **Simple** - Typos, imports, formatting
4. **Complex** - Refactoring, logic changes, architecture

## When To Push Back

Push back when:
- Suggestion breaks existing functionality
- Reviewer lacks full context
- Violates YAGNI (unused feature)
- Technically incorrect for this stack
- Conflicts with established codebase patterns
- Legacy/compatibility reasons exist

## Anti-Patterns

| Forbidden | Why | Instead |
|-----------|-----|---------|
| "You're absolutely right!" | Performative, adds no value | State the fix or push back |
| "Great catch!" | Social noise | Just fix it |
| Implementing without verifying | May introduce bugs | Verify first |
| Batch implementing | Hard to isolate regressions | One at a time, test each |

---

# 3. Response Format

## Structured Output Template

After processing all feedback items, produce this summary:

```markdown
## Feedback Response

### Implemented
| # | Item | Location | Notes |
|---|------|----------|-------|
| 1 | Fixed null check | `src/auth.py:42` | Added validation |
| 3 | Renamed variable | `src/utils.py:15` | `data` → `user_data` |

### Rejected
| # | Item | Reason | Evidence |
|---|------|--------|----------|
| 2 | Remove validate_user | Function is used | Called in `middleware.py:45` |
| 5 | Add generator | Premature optimization | Processes <1KB once at startup |

### Deferred
| # | Item | Reason |
|---|------|--------|
| 4 | Add caching layer | Out of scope for this PR |

### Needs Clarification
| # | Item | Question |
|---|------|----------|
| 6 | "Fix the auth flow" | Which specific aspect? Token refresh? Session handling? |
```

## Response Guidelines

- **Be terse** - No filler words, no apologies
- **Be specific** - Include file:line references
- **Be evidenced** - Rejections must cite verification results
- **Be actionable** - Clarification questions should be specific

## Single-Item Responses

For quick acknowledgments during implementation:

| Outcome | Response Format |
|---------|-----------------|
| Implemented | "Fixed in `file:line`" |
| Rejected | "Verified: [evidence]. Keeping current implementation." |
| Deferred | "Valid. Out of scope for this task." |
| Unclear | "Need clarification: [specific question]" |

---

# 4. Feedback Tracking

## Purpose

Maintain a log of processed feedback for:
- Reference during follow-up discussions
- Pattern recognition (recurring feedback types)
- Accountability (what was decided and why)

## Tracking Prompt

After processing feedback, always ask:

> "Log this feedback session to `.feedback-log.csv`? (y/n)"

Do not assume. Do not auto-track. Always prompt.

## Log Format

Append to `.feedback-log.csv` in project root:

```csv
date,source,item_number,item_summary,disposition,location,evidence
2025-01-15,PR #123 @reviewer,1,Fix null check,implemented,auth.py:42,
2025-01-15,PR #123 @reviewer,2,Remove unused fn,rejected,validate_user,Used in middleware.py:45
2025-01-15,PR #123 @reviewer,3,Add caching,deferred,,Out of scope
```

## CSV Columns

| Column | Description |
|--------|-------------|
| date | ISO date (YYYY-MM-DD) |
| source | Origin of feedback (PR #, reviewer, session) |
| item_number | Feedback item number from source |
| item_summary | Brief description of the item |
| disposition | implemented / rejected / deferred / clarified |
| location | File:line where change was made (if applicable) |
| evidence | Reason for rejection/deferral (if applicable) |

## Log Location

Default: `.feedback-log.csv` in project root (gitignored)

---

# 5. Skill Integration

## Using Code-Review Skills for Verification

When feedback relates to a specific technology, load the relevant skill
to verify against established codebase patterns.

## Skill Lookup Table

| Feedback Domain | Skill | Key Patterns to Check |
|-----------------|-------|----------------------|
| Python code quality | python-code-review | Type hints, error handling, naming |
| FastAPI endpoints | fastapi-code-review | Dependency injection, response models |
| SQLAlchemy models | sqlalchemy-code-review | Relationships, session handling |
| Pytest tests | pytest-code-review | Fixtures, parametrization, mocking |
| PostgreSQL queries | postgres-code-review | Indexes, joins, transactions |
| React components | shadcn-code-review | Component composition, accessibility |
| React Router | react-router-code-review | Loaders, actions, error boundaries |
| Tailwind styling | tailwind-v4 | Utility classes, responsive design |
| State management | zustand-state | Store structure, selectors |
| Vitest tests | vitest-testing | Test structure, mocking |

## Integration Workflow

1. **Identify domain** - What technology does the feedback concern?
2. **Load skill** - Use Skill tool to load relevant skill
3. **Cross-reference** - Does feedback align with skill guidance?
4. **Resolve conflicts** - If feedback contradicts skill, flag for discussion

## Conflict Resolution

If reviewer feedback conflicts with skill guidance:

```
Skill says: [pattern from skill]
Reviewer says: [contradicting suggestion]

Flag: "Feedback conflicts with established pattern. Discuss before implementing."
```

Codebase patterns (captured in skills) take precedence over external opinions.
