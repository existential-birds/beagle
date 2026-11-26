---
name: pytest-code-review
description: Reviews pytest test code for pytest-asyncio configuration, async resource cleanup, fixture scoping, parametrize usage, and mock/patch correctness. Use when reviewing test_*.py or conftest.py files.
---

# Pytest Code Review

## Quick Reference

| Issue Type | Reference |
|------------|-----------|
| `pytest-asyncio` `strict`/`auto` mode, `AsyncMock`, task cleanup | [references/async-testing.md](references/async-testing.md) |
| `conftest.py`, `tmp_path`, fixture scope, async `try`/`finally` cleanup | [references/fixtures.md](references/fixtures.md) |
| `@pytest.mark.parametrize`, `pytest.param`, `indirect` fixtures | [references/parametrize.md](references/parametrize.md) |
| Call-site `patch()`, `AsyncMock`, `spec_set`, `mocker` | [references/mocking.md](references/mocking.md) |

## Review gates

Work in order. Do not assert pytest-specific problems until each applicable gate passes.

1. **Scoped files** — **Pass when:** You list every `test_*.py` and any `conftest.py` you will cite; no findings for files outside that list.
2. **Async vs sync** — **Pass when:** Per scoped file, you note whether it uses `async def test_*` / `await` and check project `asyncio_mode` (`strict` vs `auto`); if async, open [references/async-testing.md](references/async-testing.md) before criticizing async usage.
3. **Fixtures** — **Pass when:** If shared setup matters, you name the `conftest.py` path(s) or state none; for yield fixtures, confirm cleanup exists before claiming resource leaks.
4. **patch / mocks** — **Pass when:** For any `patch` or mock critique, you give the import path where the symbol is **used** (call site), or mark N/A; open [references/mocking.md](references/mocking.md) when mocking is central to the review.
5. **Findings** — **Pass when:** Each finding includes a file path and line(s) or test node id, not a generic rule restatement.

## Review Checklist

- [ ] Async tests match configured `pytest-asyncio` mode (`strict` requires `@pytest.mark.asyncio` + `@pytest_asyncio.fixture`; `auto` discovers `async def` tests/fixtures automatically)
- [ ] `asyncio_default_fixture_loop_scope` configured explicitly in `pyproject.toml` / `pytest.ini`
- [ ] `AsyncMock` used for async dependencies (not `Mock`) and all coroutines/async mocks awaited
- [ ] Background tasks and async resources cleaned up in `finally` blocks
- [ ] Fixture scope appropriate (`function` for mutable state, `module`/`session` only for immutable/isolated expensive setup)
- [ ] Yield fixtures wrap cleanup in `try`/`finally` and use `tmp_path` instead of hardcoded `/tmp` paths
- [ ] `@pytest.mark.parametrize` uses `pytest.param(..., id=...)` / `indirect=` cleanly for similar cases
- [ ] `patch()` targets where the symbol is **used** (imported/looked up), not where defined
- [ ] Mocks use `spec`/`spec_set` and verify exact call arguments when behavior depends on them
- [ ] Tests remain isolated (no shared module-level mock or mutable state)

## Valid Patterns (Do NOT Flag)

- **`assert` without custom message** — `pytest` rewrites `assert` statements to render detailed diffs automatically
- **`@pytest.fixture` without explicit scope** — Default `function` scope is correct for most fixtures, including those returning fresh mutable state per test
- **`monkeypatch` instead of `unittest.mock`** — Simpler `pytest`-native patching with automatic teardown
- **`async def test_*` without `@pytest.mark.asyncio` when `asyncio_mode = "auto"`** — Intentional in `auto` mode

## When to Load References

- Reviewing async test functions or `pytest-asyncio` config → `references/async-testing.md`
- Reviewing fixtures or `conftest.py` → `references/fixtures.md`
- Reviewing parametrized tests → `references/parametrize.md`
- Reviewing mocks and patches → `references/mocking.md`

## Review Questions

1. Does async test/fixture syntax match the project's `pytest-asyncio` `asyncio_mode` (`strict` vs `auto`)?
2. Are fixtures properly scoped with `try`/`finally` cleanup and `tmp_path`?
3. Can duplicated test cases be simplified with `@pytest.mark.parametrize`?
4. Do `patch()` calls target the call-site namespace, use `AsyncMock`/`spec_set`, and verify arguments accurately?
