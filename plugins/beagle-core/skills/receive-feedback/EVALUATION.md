# Evaluation Rules

## Binary Classification

Every feedback item is exactly one of:

| Classification | Meaning | Action |
|----------------|---------|--------|
| **VALID** | Verification confirmed the claim holds and the suggested change (or a clear equivalent) is implementable | Add to the `launch fixes for ...` confirmation prompt. On confirm, spawn a dedicated subagent. |
| **INVALID** | Verification disproved the claim — the code is correct, the symbol is used, the bug does not reproduce | Reject with cited verification evidence. |
| **NEEDS CLARIFICATION** | The feedback is genuinely unparseable (e.g., "fix the auth flow" with no further detail) | Ask one specific clarifying question. Do not use this bucket to dodge a fix. |

There is no fourth bucket. There is no "Deferred". There is no "Out of scope". There is no "Pre-existing".

## Prohibited Reasoning

The following are NOT valid reasons to downgrade a VALID item or move it out of the fix queue:

- "This is pre-existing." — If the reviewer found it on this PR, it is in scope.
- "This is out of scope for the PR." — If the bug exists on this branch, the PR owns it.
- "We can fix this in a follow-up." — No. Fix it now.
- "This is minor / cosmetic / an edge case." — Irrelevant. A valid bug is a valid bug.
- "This would be too much churn." — Irrelevant.
- "The reviewer lacks context." — If you can prove that with a verification artifact, the item is INVALID. If you cannot, it is VALID.
- "YAGNI." — Only applies when verification proves the code or feature has zero consumers; then the item is INVALID with evidence, not deferred.

If you find yourself reasoning toward any of the above, stop and ask: *did verification actually disprove the claim?* If no, the item is VALID and must be dispatched to a subagent.

## Evaluation Order

Within the verification pass, work top-to-bottom through the feedback list. Do not reorder by perceived priority — the user sees the same numbering the reviewer used.

## When To Reject (INVALID)

Reject only with a concrete verification artifact:

- Suggestion targets code that does not exist on this branch (cite path).
- Symbol the reviewer wants removed is referenced (cite `Grep` hit at file:line).
- Bug the reviewer reports does not reproduce (cite the test or script output).
- Suggestion contradicts an established codebase pattern documented in a beagle skill (cite the skill and the existing usage).

A rejection without an artifact is not a rejection — it is deferral in disguise. Treat it as VALID.

## Anti-Patterns

| Forbidden | Why | Instead |
|-----------|-----|---------|
| "You're absolutely right!" | Performative, adds no value | State the fix or push back with evidence |
| "Great catch!" | Social noise | Just dispatch the subagent |
| Implementing without verifying | May introduce bugs or miss the real issue | Verify first, then dispatch |
| Orchestrator editing files directly | Violates the dispatch model | Spawn one subagent per valid item |
| Asking "which of these would you like to fix?" | Implies deferral is on the table | Ask only `launch fixes for <numbers>?` |
| Inventing a "Deferred" bucket in the response | There is no deferred bucket | Implemented or Rejected, nothing else |
