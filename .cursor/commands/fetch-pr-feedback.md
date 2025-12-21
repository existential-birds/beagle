# Fetch PR Feedback

Fetch review comments from a bot reviewer on the current PR, format them, and evaluate using the receive-feedback skill.

## Usage

```
/beagle:fetch-pr-feedback [--bot <username>] [--pr <number>]
```

**Flags:**
- `--bot <username>` - Bot/reviewer to fetch comments from (default: `coderabbitai[bot]`)
- `--pr <number>` - PR number to target (default: current branch's PR)

## Instructions

### 1. Parse Arguments

Extract flags from `$ARGUMENTS`:
- `--bot <username>` or default to `coderabbitai[bot]`
- `--pr <number>` or detect from current branch

### 2. Get PR Context

```bash
# If --pr was specified, use that number directly
# Otherwise, get PR for current branch:
gh pr view --json number,headRefName,url

# Get repo owner/name:
gh repo view --json nameWithOwner --jq '.nameWithOwner'
```

If no PR exists for current branch, fail with: "No PR found for current branch. Use --pr to specify a PR number."

### 3. Fetch Comments

Fetch both types of comments (use `--paginate` to get all):

**Issue comments** (summary/walkthrough posts):
```bash
gh api --paginate "repos/{owner}/{repo}/issues/{number}/comments" \
  --jq '.[] | select(.user.login == "{bot}") | .body'
```

**Review comments** (line-specific):
```bash
gh api --paginate "repos/{owner}/{repo}/pulls/{number}/comments" \
  --jq '.[] | select(.user.login == "{bot}") | "---\nFile: \(.path):\(.line // .original_line)\n\(.body)\n"'
```

### 4. Format Feedback Document

Strip noise from the content:
- Remove `<details>` blocks containing "Learnings" or AI command hints
- Remove excessive whitespace

Structure the output:

```markdown
# PR Feedback from {bot}

## Summary/Overview
[All issue comments here - there may be multiple]

## Line-Specific Comments
[All review comments here, each prefixed with "File: path:line"]
```

If no comments found, output: "No comments from {bot} found on this PR."

### 5. Evaluate with receive-feedback

Process the formatted feedback document using the receive-feedback workflow:

## Receive Feedback Workflow

Process code review feedback with verification-first discipline. No performative agreement. Technical correctness over social comfort.

### Core Principle

**Verify before implementing. Ask before assuming.**

### Workflow Overview

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│   VERIFY    │ ──▶ │   EVALUATE   │ ──▶ │   EXECUTE   │
│ (tool-based)│     │ (decision    │     │ (implement/ │
│             │     │  matrix)     │     │  reject/    │
└─────────────┘     └──────────────┘     │  defer)     │
                                         └─────────────┘
```

For each feedback item:
1. **Verify** - Use tools to check if feedback is technically valid
2. **Evaluate** - Apply decision matrix to determine action
3. **Execute** - Implement, reject with evidence, or defer

### Verification Workflow

Do not trust feedback. Verify it against the current codebase state.

**Verification by Feedback Type:**

| Feedback Type | Verification Method |
|---------------|---------------------|
| "Unused code" | `Grep` for usage across codebase |
| "Bug/Error" | Reproduce with test or script |
| "Missing import" | Check file, run linter |
| "Style/Convention" | Check existing patterns in codebase |
| "Performance issue" | Profile or benchmark if possible |
| "Security concern" | Trace data flow, check sanitization |

**Verification Steps:**

For EACH feedback item:

1. **Locate**: Find the referenced code (`Read` tool)
2. **Context**: Understand why it exists (`Grep` for usage, git blame)
3. **Validate**: Test the claim (run tests, reproduce issue)
4. **Document**: Note verification result before proceeding

**Using Code-Review Skills for Verification:**

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

These skills contain the authoritative patterns for this codebase. If feedback conflicts with skill guidance, flag for discussion.

**Example:**

Feedback: "Remove unused `validate_user` function"

Verification:
1. `Grep` for "validate_user" across codebase
2. Found: Called in `auth/middleware.py:45`
3. Result: **Feedback incorrect** - function is used
4. Action: Push back with evidence

### Evaluation Rules

**Decision Matrix:**

| Condition | Action | Response |
|-----------|--------|----------|
| **Correct & In Scope** | Implement immediately | "Fixed in [file:line]" |
| **Correct but Out of Scope** | Defer | "Valid point. Out of scope; added to backlog." |
| **Technically Incorrect** | Reject with evidence | "Verified: [evidence]. Maintaining current implementation." |
| **Ambiguous / Unclear** | STOP and ask | "Clarification needed: [specific question]" |
| **Violates YAGNI** | Reject | "Not currently used by any consumer. Skipping (YAGNI)." |
| **Conflicts with codebase patterns** | Flag for discussion | "Conflicts with established pattern in [location]. Discuss?" |

**Evaluation Order:**

Process feedback items in this order:

1. **Clarify** - Resolve all ambiguous items first
2. **Critical** - Security issues, breaking bugs
3. **Simple** - Typos, imports, formatting
4. **Complex** - Refactoring, logic changes, architecture

**When To Push Back:**

Push back when:
- Suggestion breaks existing functionality
- Reviewer lacks full context
- Violates YAGNI (unused feature)
- Technically incorrect for this stack
- Conflicts with established codebase patterns
- Legacy/compatibility reasons exist

**Anti-Patterns:**

| Forbidden | Why | Instead |
|-----------|-----|---------|
| "You're absolutely right!" | Performative, adds no value | State the fix or push back |
| "Great catch!" | Social noise | Just fix it |
| Implementing without verifying | May introduce bugs | Verify first |
| Batch implementing | Hard to isolate regressions | One at a time, test each |

### Response Format

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

**Response Guidelines:**

- **Be terse** - No filler words, no apologies
- **Be specific** - Include file:line references
- **Be evidenced** - Rejections must cite verification results
- **Be actionable** - Clarification questions should be specific

**Single-Item Responses:**

For quick acknowledgments during implementation:

| Outcome | Response Format |
|---------|-----------------|
| Implemented | "Fixed in `file:line`" |
| Rejected | "Verified: [evidence]. Keeping current implementation." |
| Deferred | "Valid. Out of scope for this task." |
| Unclear | "Need clarification: [specific question]" |

### Feedback Tracking

**Purpose:**

Maintain a log of processed feedback for:
- Reference during follow-up discussions
- Pattern recognition (recurring feedback types)
- Accountability (what was decided and why)

**Tracking Prompt:**

After processing feedback, always ask:

> "Log this feedback session to `.feedback-log.csv`? (y/n)"

Do not assume. Do not auto-track. Always prompt.

**Log Format:**

Append to `.feedback-log.csv` in project root:

```csv
date,source,item_number,item_summary,disposition,location,evidence
2025-01-15,PR #123 @reviewer,1,Fix null check,implemented,auth.py:42,
2025-01-15,PR #123 @reviewer,2,Remove unused fn,rejected,validate_user,Used in middleware.py:45
2025-01-15,PR #123 @reviewer,3,Add caching,deferred,,Out of scope
```

**CSV Columns:**

| Column | Description |
|--------|-------------|
| date | ISO date (YYYY-MM-DD) |
| source | Origin of feedback (PR #, reviewer, session) |
| item_number | Feedback item number from source |
| item_summary | Brief description of the item |
| disposition | implemented / rejected / deferred / clarified |
| location | File:line where change was made (if applicable) |
| evidence | Reason for rejection/deferral (if applicable) |

**Log Location:**

Default: `.feedback-log.csv` in project root (gitignored)

## Example

```bash
# Fetch CodeRabbit comments on current branch's PR (default)
/beagle:fetch-pr-feedback

# Fetch from a different bot
/beagle:fetch-pr-feedback --bot renovate[bot]

# Fetch from a specific PR
/beagle:fetch-pr-feedback --pr 123

# Combined
/beagle:fetch-pr-feedback --bot coderabbitai[bot] --pr 456
```
