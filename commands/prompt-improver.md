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
