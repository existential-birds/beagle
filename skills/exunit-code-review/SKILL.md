---
name: exunit-code-review
description: Reviews ExUnit test code for async safety, Ecto Sandbox usage, boundary mocking with Req.Test and Mox, and test adapters. Use when reviewing _test.exs files or test helper configurations.
---

# ExUnit Code Review

## Quick Reference

| Issue Type | Reference |
|------------|-----------|
| Async pitfalls, `Application.put_env`, `CaptureLog`, `setup_all` | [references/exunit-patterns.md](references/exunit-patterns.md) |
| Behavior-based mocking, `$callers`, `Mox.allow` | [references/mox-boundaries.md](references/mox-boundaries.md) |
| `Req.Test`, `Bypass`, Swoosh, Oban testing | [references/test-adapters.md](references/test-adapters.md) |
| What to mock vs real, Ecto Sandbox, fixtures | [references/integration-tests.md](references/integration-tests.md) |

## Mock Boundary Philosophy

**Mock at external boundaries:**
- HTTP clients, external APIs, third-party services (`Req.Test` for `Req`, `Bypass` / `Mox` for other clients)
- Slow resources: file system, email (`Swoosh.Adapters.Test`), job queues (`Oban.Testing`)
- Non-deterministic: `DateTime.utc_now/0`, `:rand`

**DO NOT mock internal code:**
- Contexts, schemas, GenServers
- Internal modules, PubSub
- Anything you wrote

## Review Checklist

### Test Structure & Async Safety
- [ ] Tests use `async: true` when isolated (including `use MyApp.DataCase, async: true` via Ecto Sandbox)
- [ ] `async: false` used when mutating global state (`Application.put_env/3`, named singletons, `{:shared, self()}` sandbox, global `CaptureLog`)
- [ ] `setup_all` does not leak sandbox connections or per-test state across tests

### Mocking & HTTP Testing
- [ ] `Req.Test` (`stub/2`, `expect/3`, `json/2`) used for `Req`-based HTTP clients (`nimble_ownership` supports `async: true` without ports)
- [ ] `Bypass` or `Mox` used for non-`Req` external boundaries (behaviors defined for interfaces)
- [ ] No mocking of internal modules (contexts, schemas, `Repo`)
- [ ] `verify_on_exit!` in setup for strict `Mox` mocking; no `Mox.allow` race conditions after process spawn

### Test Adapters
- [ ] `Req.Test` or `Bypass` for HTTP endpoint mocking
- [ ] `Swoosh.Adapters.Test` for email testing
- [ ] `Oban.Testing` for background job assertions (asserting `Oban.drain_queue` return map `%{success: _, failure: 0}`)

### Database
- [ ] `Ecto.Adapters.SQL.Sandbox` (`start_owner!(Repo, shared: not tags[:async])`) for isolation
- [ ] Shared sandbox calls use `{:shared, self()}` (not bare `:shared`)
- [ ] Phoenix fixtures (`test/support/fixtures/`) used consistently (`ExMachina` is legacy)

## Valid Patterns (Do NOT Flag)

- **`use MyApp.DataCase, async: true`** - Database tests run in isolated Ecto Sandbox transactions
- **Mock in unit test, real in integration** - Different test levels have different needs
- **Not mocking database in integration tests** - Database is internal
- **Simple inline test data** - Not everything needs fixtures or factories
- **Testing private functions via public API** - Correct approach
- **`Task.async` inheriting `Mox` / `Req.Test` / Sandbox via `$callers`** - Automatic in modern Elixir without manual `allow`

## Context-Sensitive Rules

| Issue | Flag ONLY IF |
|-------|--------------|
| `async: true` race | Test mutates global state (`Application.put_env`, named process, ETS, `{:shared, self()}`) |
| Missing mock | External call exists AND no `Req.Test` / `Bypass` / `Mox` |
| Mock internal | Module being mocked is internal code |

## Gates (sequence)

Complete **in order**. Do not emit a finding until the prior step passes for that issue.

1. **Evidence from the file** — Open the test module (or helper) and tie the claim to concrete lines.
   - **Pass when:** Each prospective finding includes `[FILE:LINE]` **and** a one-line factual description of what is on that line (or an adjacent line you name), not a generic style complaint.

2. **ExUnit false-positive veto** — Check this skill’s **Valid Patterns** and **Context-Sensitive Rules** for the case.
   - **Pass when:** You can state “not covered by Do NOT Flag / Flag ONLY IF” in one sentence, or you drop the finding.

3. **Cross-protocol verification** — Apply the `review-verification-protocol` skill ([review-verification-protocol](../review-verification-protocol/SKILL.md)) (e.g. read full function/block, search usages before “unused” claims) to that same finding.
   - **Pass when:** At least one protocol check relevant to the claim type is satisfied and would appear in your rationale if challenged.

## Before Submitting Findings

Use `[FILE:LINE] ISSUE_TITLE` per finding after **Gates (sequence)** and the `review-verification-protocol` skill ([review-verification-protocol](../review-verification-protocol/SKILL.md)) are satisfied.
