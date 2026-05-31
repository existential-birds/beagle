# LLM artifact finding — verification checklist

Use this **before** marking a review finding as `confirmed_issue`. Skipping steps causes false positives (especially for dead code and “verbose” style).

## Existence precondition (FIRST check, every category)

Run this **before** any symbol/usage check, for **every** finding regardless of category:

- [ ] **Cited file exists at `source_git_head`.** Confirm with `git cat-file -e <source_git_head>:<file>` (or `test -f <file>` when verifying the working tree). Record `file_exists` in `checks_performed`.

Branch on the result:

- **Exists** → proceed to the category checks below.
- **Does not exist** → **do not** proceed to symbol/usage checks. It is one of:
  - A finding about a **deleted file** — note it explicitly in `notes` and adjudicate accordingly (often `false_positive` if the cited issue no longer exists, or `inconclusive`).
  - A sign the report is **corrupt or you are not looking at the real report** — **STOP**, re-read `findings[]` (verify-llm-artifacts step 1a echo), and confirm the file path came from the parsed JSON, not from memory or the branch name.

> A **wall of missing-file results** (most or all findings citing nonexistent files) is an explicit **stop-and-reload trigger**, not routine evidence. It almost always means you are adjudicating confabulated findings rather than the report's `findings[]`. Stop, re-echo the finding table, and restart — do not keep writing `false_positive` rows.

## Universal

- [ ] Opened the **full** surrounding context (function/class/module), not only the cited line.
- [ ] Confirmed the **file path and line** still match current tree (report may be stale).
- [ ] Distinguished **invalid critique** from **style preference** — both can be valid.

## Dead code (`dead_code`)

- [ ] **References:** Searched the repo for symbol name, string literals, and re-exports.
- [ ] **Dynamic use:** Considered reflection, `getattr`, serialization, RPC/CLI registration, DI containers, framework callbacks (e.g. Flask routes by string).
- [ ] **Cross-package:** Detect monorepo by checking for any of: `[workspace]` in the root `Cargo.toml`; a `workspaces` key in the root `package.json`; `pnpm-workspace.yaml`; `lerna.json`; or `turbo.json`. If **any** marker is present, this check is **required** — grep the symbol name across sibling packages (e.g. `rg '<symbol>' packages/ apps/ crates/`) before marking `confirmed_issue`.
- [ ] **Tests-only usage:** Confirmed whether “only tests use it” is intentional (test helpers, fakes).
- [ ] **Public API:** If exported, checked `__all__`, package `__init__.py`, and consuming repos (if applicable).

## Tests (`tests`)

- [ ] **Intent:** Verified the test is actually wrong or redundant, not merely repetitive.
- [ ] **Mock level:** Confirmed mocks are incorrectly placed vs project boundaries (see `llm-artifacts-detection` tests criteria).

## Abstraction (`abstraction`)

- [ ] **Requirements:** Confirmed the abstraction has no current or near-term second use — not “might generalize later” vs documented need.
- [ ] **Team convention:** Checked whether the pattern matches existing codebase style.

## Style (`style`)

- [ ] **Obvious comment:** Confirmed the comment adds no information a reader would miss — not onboarding, legal, or compliance notes.
- [ ] **Defensive code:** Confirmed the check is redundant given types, framework guarantees, or earlier guards.

## Verdict guidance

| Situation | `status` |
|-----------|----------|
| Finding in the report is factually wrong or harmful if “fixed” | `false_positive` |
| Finding in the report is valid and fix is appropriate | `confirmed_issue` |
| Cannot decide without domain/product context | `inconclusive` |
| Apparent finding has **no matching id in the locked set** (not in the report) | **none — STOP, re-read `findings[]`, restart** |

Prefer `inconclusive` over guessing when evidence is mixed.

`false_positive` means *"the finding in the report is invalid."* It never means *"this finding isn't in the report."* A finding you cannot trace back to a locked id is agent error, not a false positive — do not give it a status.
