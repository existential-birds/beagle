# Response Format

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
