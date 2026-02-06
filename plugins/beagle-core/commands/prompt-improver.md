---
description: Optimize prompts for code-related tasks following Claude best practices. Use when refining prompts for implementation, debugging, refactoring, code review, or testing.
---

# Prompt Improver

Optimize code-related prompts for clarity, investigation-first thinking, and verification.

## Input

```
$ARGUMENTS
```

---

## Step 1: Analyze the Prompt

Evaluate the input prompt across these dimensions:

| Dimension | What to check |
|-----------|---------------|
| Task Clarity | Is the task type clear? (implement, fix, refactor, review, test) Are boundaries defined? |
| Investigation | Does it specify reading/understanding before acting? |
| Verification | Are there appropriate checks? (run tests, build, lint) |
| Context Anchoring | Does it reference specific files, functions, or patterns? |
| Action Specificity | Is the desired outcome explicit? Quality expectations stated? |
| Scope Control | Is it appropriately scoped? Clear stopping points? |

Identify which dimensions are weak or missing in the input prompt.

## Step 2: Apply Transformation Rules

### Task Clarity
- Convert vague requests → specific task type + scope
- Add "implement", "fix", "refactor", "review", or "test" when ambiguous
- Specify affected files/components when inferable

### Investigation-First
- Add "Read and understand [relevant files] before making changes"
- For bugs: "Reproduce and understand the root cause first"
- For features: "Check existing patterns in the codebase"

### Anti-Hallucination
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

## Step 3: Generate Output

Produce output in this exact format:

### Analysis

[2-3 sentences identifying the prompt type and which dimensions are weak]

### Improvements Applied

- [Bullet list of specific transformations applied]

### Optimized Prompt

```
[The improved prompt, ready to copy and use]
```

### Tips for This Prompt Type

[1-2 sentences of relevant tips from the Task-Type Tips table]
