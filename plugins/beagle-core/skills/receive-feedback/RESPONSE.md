# Response Format

## Pre-Dispatch Summary (before the confirmation prompt)

Print invalid items with evidence, then valid items numbered, then the single prompt.

```markdown
### Invalid (rejected with evidence)
| # | Item | Evidence |
|---|------|----------|
| 2 | Remove `validate_user` | Called at `middleware.py:45` |
| 5 | Switch to generator | Input is <1KB read once at startup (`config.py:12`) |

### Valid (will be fixed by subagents)
| # | Item | Target |
|---|------|--------|
| 1 | Null check on session | `src/auth.py:42` |
| 3 | Rename `data` → `user_data` | `src/utils.py:15` |
| 4 | Typo `usr` → `user` | `src/models.py:88` |

launch fixes for 1,3,4?
```

The confirmation line is the entire prompt. Do not append "or let me know which ones to skip" or similar — that re-opens deferral.

## Post-Dispatch Summary (after subagents return)

Exactly two sections. No third bucket.

```markdown
## Feedback Response

### Implemented
| # | Item | Location | Subagent Notes |
|---|------|----------|----------------|
| 1 | Null check on session | `src/auth.py:42` | Added guard + test |
| 3 | Rename variable | `src/utils.py:15` | `data` → `user_data`, 4 callsites updated |
| 4 | Fix typo | `src/models.py:88` | `usr` → `user` |

### Rejected
| # | Item | Reason | Evidence |
|---|------|--------|----------|
| 2 | Remove `validate_user` | Function is used | Called at `middleware.py:45` |
| 5 | Add generator | Input is tiny and read once | `config.py:12`, <1KB at startup |
```

## Response Guidelines

- **Be terse** — No filler words, no apologies.
- **Be specific** — Include file:line references.
- **Be evidenced** — Rejections must cite verification results.
- **No Deferred section.** If you typed "Deferred", delete it and dispatch a subagent.
- **No "out of scope" / "pre-existing" / "follow-up" language anywhere in the response.**

## Single-Item Responses

For quick acknowledgments during a one-item flow:

| Outcome | Response Format |
|---------|-----------------|
| Implemented (by subagent) | "Fixed in `file:line` (subagent <id>)" |
| Rejected | "Verified: [evidence]. Keeping current implementation." |
| Needs clarification | "Need clarification: [specific question]" |

There is no single-item "deferred" response.
