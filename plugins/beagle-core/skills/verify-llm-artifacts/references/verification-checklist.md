# LLM artifact finding — verification checklist

Use this **before** marking a review finding as `confirmed_issue`. Skipping steps causes false positives (especially for dead code and “verbose” style).

## Universal

- [ ] Opened the **full** surrounding context (function/class/module), not only the cited line.
- [ ] Confirmed the **file path and line** still match current tree (report may be stale).
- [ ] Distinguished **invalid critique** from **style preference** — both can be valid.

## Dead code (`dead_code`)

- [ ] **References:** Searched the repo for symbol name, string literals, and re-exports.
- [ ] **Dynamic use:** Considered reflection, `getattr`, serialization, RPC/CLI registration, DI containers, framework callbacks (e.g. Flask routes by string).
- [ ] **Cross-package:** If monorepo, checked other packages or apps that might import this module.
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
| Finding is factually wrong or harmful if “fixed” | `false_positive` |
| Finding is valid and fix is appropriate | `confirmed_issue` |
| Cannot decide without domain/product context | `inconclusive` |

Prefer `inconclusive` over guessing when evidence is mixed.
