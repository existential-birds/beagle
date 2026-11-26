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

The confirmation line is the entire prompt and must list **every** valid item's number. Do not pre-narrow the set, and do not append "or let me know which ones to skip" or similar — that re-opens deferral.

### Accepted user replies

| User reply | Meaning |
|------------|---------|
| `y` / `yes` / `go` / `ok` / `lgtm` / ↵ | Dispatch the full proposed set. |
| Comma- or space-separated numbers (e.g. `1,3` or `1 3 4`) | Dispatch only those numbers. Must be a subset of the proposed set. |
| `no` / `cancel` / `stop` | Halt without dispatching. |
| Anything else | Re-print the prompt once. Do not invent a disposition. |

A subset reply is a user override, not an agent narrowing. Items the user omits are **not** deferred — they are simply not run this round. Surface them only on the line described below.

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

Not run this round: 4 (user-excluded)
```

The trailing `Not run this round` line is the **only** place user-excluded valid items appear. Omit the line entirely if the user accepted the full set. Never reword this as "deferred", "skipped for now", or "follow-up".

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
