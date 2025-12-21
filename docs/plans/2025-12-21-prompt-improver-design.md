# Prompt Improver Command Design

## Overview

A code-focused prompt optimization command for the beagle plugin. Transforms vague or incomplete code-related prompts into specific, actionable prompts that prevent common pitfalls.

## Command Identity

- **Name:** `prompt-improver`
- **Location:** `commands/prompt-improver.md`
- **Description:** Optimize prompts for code-related tasks following Claude best practices. Use when refining prompts for implementation, debugging, refactoring, code review, or testing.

## Input/Output

**Input:** User provides a prompt via `$ARGUMENTS`

**Output format:**
1. Analysis (2-3 sentences on prompt type and weaknesses)
2. Improvements Applied (bullet list)
3. Optimized Prompt (in code block, ready to copy)
4. Tips for This Prompt Type (1-2 sentences)

## Analysis Framework

The command analyzes prompts across these code-specific dimensions:

| Dimension | What to check |
|-----------|---------------|
| Task Clarity | Is the task type clear? (implement, fix, refactor, review, test) Are boundaries defined? |
| Investigation Requirements | Does it specify reading/understanding before acting? |
| Verification Steps | Are there appropriate checks? (run tests, build, lint) |
| Context Anchoring | Does it reference specific files, functions, or patterns? |
| Action Specificity | Is the desired outcome explicit? Quality expectations stated? |
| Scope Control | Is it appropriately scoped? Clear stopping points? |

## Transformation Rules

### Task Clarity
- Convert vague requests → specific task type + scope
- Add "implement", "fix", "refactor", "review", or "test" when ambiguous
- Specify affected files/components when inferable

### Investigation-First
- Add "Read and understand [relevant files] before making changes"
- For bugs: "Reproduce and understand the root cause first"
- For features: "Check existing patterns in the codebase"

### Anti-Hallucination (code-specific)
- "Do not assume code structure you haven't read"
- "Verify imports/dependencies exist before using them"
- "Check for existing utilities before creating new ones"

### Verification Steps
- For implementation: "Run tests after changes"
- For refactoring: "Ensure behavior is unchanged"
- For fixes: "Verify the fix and check for regressions"

### Positive Framing
- Convert "don't break tests" → "ensure tests pass after changes"
- Convert "don't over-engineer" → "implement the minimal solution"

### Scope Control
- Add explicit boundaries when missing
- Break multi-part requests into phases if needed

## Examples

### Bug Fix
```
Original: "fix the login bug"

Optimized:
Fix the login bug. First, read the authentication-related files to understand
the current implementation. Reproduce the bug to confirm the issue. Identify
the root cause before making changes. Implement the fix and run existing tests
to verify no regressions.
```

### Feature Implementation
```
Original: "add dark mode"

Optimized:
Implement dark mode for the application. First, check how theming/styling is
currently handled in the codebase. Look for existing color variables or theme
patterns. Implement the toggle and theme switching with minimal changes to
existing components. Run tests and verify the UI renders correctly in both modes.
```

### Refactoring
```
Original: "clean up the user service"

Optimized:
Refactor the user service for improved maintainability. Read the current
implementation and understand its responsibilities. Identify specific issues
(duplication, unclear naming, tight coupling). Make incremental changes,
running tests after each step to ensure behavior is unchanged.
```

## Task-Type Tips

| Task Type | Tip |
|-----------|-----|
| Bug fixes | Include reproduction steps if known. Specify whether this is a quick fix or needs root cause analysis. |
| Feature implementation | Reference similar features in the codebase. Specify if tests are expected. |
| Refactoring | State the goal (readability, performance, testability). Emphasize incremental changes. |
| Code review | Specify focus areas (security, performance, style). Mention what to ignore. |
| Testing | Specify test type (unit, integration, e2e). Reference existing test patterns. |

## Key Differences from Amelia Version

1. Analysis dimensions are code-specific (not general writing)
2. Transformation rules include investigation-first and verification patterns
3. Examples are all code tasks (bug, feature, refactor)
4. Tips are organized by code task type
5. Anti-hallucination anchors are developer-workflow specific

## File Structure

```
commands/
└── prompt-improver.md   # Single file, ~150-180 lines
```

## Next Steps

1. Implement `commands/prompt-improver.md` following this design
2. Test with various code prompts
3. Add to Cursor commands if needed
