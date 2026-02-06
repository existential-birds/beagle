# Evaluation Rules

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
