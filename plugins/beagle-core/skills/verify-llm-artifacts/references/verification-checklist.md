# LLM artifact finding — IRREVERSIBLE evidence gate

Load this file **only** for findings tiered IRREVERSIBLE by `verify-llm-artifacts` — that is, `fix_action == "delete"`. REVERSIBLE findings are adjudicated from the finding record and never reach this checklist.

Everything below is the `verification-budget` tier-IRREVERSIBLE evidence gate made concrete for one finding category.

## Existence precondition (first check)

- [ ] **Cited file exists at `source_git_head`.** `git cat-file -e <source_git_head>:<file>`, or `test -f <file>` when verifying the working tree. Record `file_exists` in `checks_performed`.

Branch on the result:

- **Exists** → proceed to the category checks.
- **Does not exist** → stop the symbol/usage checks for this finding and adjudicate on the absence: `false_positive` if the cited issue no longer exists, `inconclusive` if you cannot tell. Note it explicitly.

A wall of missing-file results means the report may not match the tree. That is bounded by the step-3 missing-files loop budget in `verify-llm-artifacts` — **one** re-echo pass, then proceed and flag. Do not restart repeatedly.

## Universal

- [ ] Opened the **full** surrounding context — function, class, or module — not only the cited line.
- [ ] Confirmed the file path and line still match the current tree; the report may be stale.
- [ ] Distinguished an **invalid critique** from a **style preference**. Both can be valid.

## Dead code (`dead_code`)

Reference search is an **enumerated** list, not a proof of absence (`verification-budget` §4). Run these four and report each result; do not widen the search past them:

- [ ] 1. **Direct references** — symbol name across the repo.
- [ ] 2. **String and re-export references** — the name as a string literal, and re-exports or barrel-file entries.
- [ ] 3. **Dynamic use** — reflection, `getattr`, serialization, RPC/CLI registration, DI containers, framework callbacks registered by string.
- [ ] 4. **Cross-package** — required only when a monorepo marker is present: `[workspace]` in the root `Cargo.toml`, a `workspaces` key in the root `package.json`, `pnpm-workspace.yaml`, `lerna.json`, or `turbo.json`. If present, grep the symbol across sibling packages (`rg '<symbol>' packages/ apps/ crates/`).

Then:

- [ ] **Tests-only usage:** if only tests reference it, decide whether that is intentional — test helpers and fakes are not dead.
- [ ] **Public API:** if exported, check the language's export manifest (`__all__` / `index.ts` / `mod.rs` / `lib.rs` / package exports) before confirming.

Record the outcome as a bounded claim: *"no references across the 4 enumerated patterns"* — never *"no references."*

## Tests (`tests`)

- [ ] **Intent:** the test is actually wrong or redundant, not merely repetitive.
- [ ] **Mock level:** the mock is misplaced against the project's real boundaries — see the `llm-artifacts-detection` tests criteria.

## Abstraction (`abstraction`)

- [ ] **Requirements:** the abstraction has no current or near-term second use — a documented need, not "might generalize later."
- [ ] **Team convention:** the pattern does not match existing codebase style.

## Style (`style`)

- [ ] **Obvious comment:** the comment adds nothing a reader would miss — not an onboarding, legal, or compliance note.
- [ ] **Defensive code:** the check is redundant given types, framework guarantees, or an earlier guard.

## Verdict guidance

| Situation | `status` |
|-----------|----------|
| Finding in the report is factually wrong, or harmful if "fixed" | `false_positive` |
| Finding in the report is valid and the fix is appropriate | `confirmed_issue` |
| Cannot decide without domain or product context | `inconclusive` |
| Evidence is mixed after the enumerated checks above | `inconclusive` |

`false_positive` means *"the finding in the report is invalid."* It never means *"this finding isn't in the report."* An id you cannot trace to the echoed table is handled by the step-3 findings-mismatch budget, not by giving it a status.
