# Publication Protocol

## Authorization and ownership

- "Create a skill" authorizes skill artifacts and their tests, not a real issue campaign.
- "Scan this repo" without publication wording yields local drafts.
- "Create/file GitHub issues for proposed refactors" authorizes the accepted in-scope issue batch.
- A drafts-only or no-post instruction always wins.
- Discover and verify the exact GitHub target before any write.
- Only the coordinator/publisher writes GitHub issues; analysis shards never do.
- Maintain one publisher per repository across campaigns, not merely one process per output directory.
- The directory lock serializes helper invocations in one campaign; it does not provide a distributed GitHub uniqueness constraint.

## Existing work and duplicates

1. Read all-state issues with `gh api` pagination; retain PR records separately when distinguishing counts.
2. Compare candidates by root cause, ownership boundary, affected paths, proposed transformation, and acceptance scope.
3. Inspect closest open issues and PRs, including linked changes and migration work.
4. Read relevant closed decisions: a previously declined idea should not silently reappear as a fresh ticket.
5. Merge overlapping proposed occurrences into one coherent issue.
6. Record duplicate decisions and existing URLs in the ledger rather than creating replacements.
7. Refresh this check immediately before publication; the helper's exact marker/title check is only a final guard.

- GitHub search is a supplement, not proof of complete backlog coverage; it can have result limits.
- A successful empty paginated listing is different from a failed request.
- Stable keys survive line movement and a new scan SHA; do not change keys just to bypass a prior decision.
- Never close, reopen, comment on, or edit an existing issue without that additional authority.
- The all-state issue endpoint is not a transaction; concurrent edits can still race across pages.
- If another campaign is actively publishing to the same repository, coordinate or pause.

## Labels and assignees

- Enumerate actual labels with the paginated repository labels endpoint.
- Reuse the repository's existing Priority/Effort/Type scheme when present.
- Do not create guessed names such as `refactor`, `P2`, or `effort:small` merely because they seem conventional.
- If a required classification has no usable label, surface the decision rather than inventing one.
- Explicitly use empty labels/assignees arrays when unlabelled/unassigned is intended and policy allows it.
- Check the chosen assignee is valid and assignable to this repository.
- Only use an explicitly requested owner when assignable; never infer ownership of arbitrary third-party repositories.
- The helper rechecks live label membership and each assignee's repository access before creation.

## Publish sequence

1. Read the generated markdown and exact JSON payload; confirm no secrets, raw personal data, or unsupported claims.
2. Confirm evidence links point to the pinned, published commit and correct line ranges.
3. Recheck semantic duplication and publication authorization.
4. Invoke through `terminal`:
   `python <skill-dir>/scripts/repo_refactor.py publish --draft <campaign>/drafts/<id>.json --confirm-repo OWNER/REPO`
5. The helper searches all-state items for its stable marker before considering a new POST.
6. If the marker exists, it reads that exact issue and verifies fields; it does not create another issue.
7. Otherwise it requires an absent journal, unchanged remote ref SHA, valid labels, assignable users, and no fresh marker/title collision.
8. It writes a pending journal, then sends one POST using explicit title/body/labels/assignees.
9. It records the returned number and reads `repos/OWNER/REPO/issues/NUMBER` directly.
10. It verifies that the result is an open issue with the intended title, body, label set, assignee set, and URL. GitHub repository casing may differ, but HTTPS host, repository identity, and issue number must match; URL query strings or suffixes are rejected.
11. Only a successful readback produces a verified-created or verified-existing receipt.
12. Persist the result before proceeding to the next manifest ID.

## Failure and recovery

- Authentication or network failure: stop; never infer an empty backlog or fabricate a receipt.
- Rate limit: preserve artifacts, surface the error, and follow GitHub's observed retry guidance; never hammer POST.
- Remote ref changed: refresh the pinned inventory, revalidate affected evidence, rerun semantic duplication review, and prepare a fresh draft directory.
- Existing marker after an interrupted POST: retrying the helper can reconcile it with a GET and no duplicate POST.
- Pending journal but no remote marker: outcome is ambiguous. Inspect the exact recorded number if available, full listing, and GitHub state before a human authorizes a new attempt.
- Do not delete the journal, change the stable key, or create another directory simply to bypass that ambiguity.
- Readback mismatch: report created-unverified with its known number; automation might have altered labels, or the issue might have been edited.
- Closed marker match: do not reopen or recreate it; review why it closed.
- Stale publisher lock: confirm the original writer is no longer active and reconcile its journal before authorized cleanup.
- GitHub does not provide atomic uniqueness on issue-body markers. Cross-process/cross-host serialization is an operational requirement.

## Reporting

- Derive totals from manifest and journals with Python, not manually counted chat bullets.
- Separate verified-created, verified-existing, pending, created-unverified, and unpublished drafts.
- Include exact verified URLs for successful issues.
- Include accepted/rejected/duplicate/needs-evidence counts and concrete coverage gaps.
- Do not claim every source file was deeply reviewed when the coverage says only triaged.
- Do not mark proposed refactoring work complete; only the survey phase is complete.
- Keep implementation dispatch a separate user request or an explicitly pre-authorized downstream workflow.

## Test stance

- The helper test suite uses temporary synthetic Git repositories and mocked GitHub responses.
- Test success does not claim live GitHub publication or permissions were exercised.
- Do not create throwaway issues in a real repository as a test unless the user explicitly authorizes that target.
