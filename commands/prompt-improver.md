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
