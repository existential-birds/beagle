# Test Quality Criteria (language-neutral)

Detection criteria for test quality issues commonly introduced by LLM coding agents. Everything here applies in any language.

Worked BAD/GOOD examples live in a separate per-language file. Load [examples/python/tests.md](examples/python/tests.md) **only** when the tests under review are Python. For any other language, apply the criteria below directly — substitute the local equivalents (fixture ≈ setup helper, factory, builder, or `TestMain`; mock ≈ double, stub, fake, or interface substitution).

## 1. DRY Violations

**What to look for:** setup or teardown repeated across test functions instead of a shared fixture, factory, or helper.

| Sub-pattern | Signal |
|---|---|
| Repeated object construction | The same value built literally, identically, in three or more tests |
| Repeated double configuration | The same stub/mock wiring copied per test |
| Copy-pasted resource setup | Database, temp dir, server, or client bootstrapped inline in every test |

**How to fix:**

1. Extract to the language's shared-setup mechanism — a fixture file, a setup function, a builder, or a suite-level hook.
2. Choose the narrowest scope that still shares the work: per-test, per-suite, per-run.
3. Prefer factories over fixed literals when the tests need varying data.
4. Compose small helpers rather than growing one setup that every test partially ignores.

**Before flagging:** repetition in tests is not automatically a defect. Explicit, duplicated setup is often *more* readable than a shared fixture that hides what a test depends on. Flag it when the duplication is mechanical and identical, not when it is deliberately explicit.

## 2. Library Testing

**What to look for:** tests validating the standard library or a third-party framework rather than the project's own code.

**Signals:**

- The test file imports only stdlib and third-party packages, and nothing from the project.
- The assertions restate documented framework behavior.
- The assertions match examples from the framework's own documentation.
- No domain logic is exercised anywhere in the test.

**How to fix:**

1. Delete tests that only verify framework behavior.
2. Test the project's code that *uses* the framework.
3. Test business logic, not library internals.
4. Trust well-tested dependencies.

**Before flagging:** a test that pins framework behavior the project genuinely depends on — a serialization format, a specific coercion rule, a version-sensitive default — is a regression guard, not library testing. The distinction is whether the project would break if the behavior changed.

## 3. Mock Boundaries

**What to look for:** doubles placed at the wrong level — too deep, or too shallow.

**Too deep — mocking internals.** Substituting private helpers, internal methods, or implementation details of the unit under test.

Problems: tests break on refactors that change nothing observable; the test encodes implementation knowledge; internals can change while the test still passes, which is false confidence.

**Too shallow — missing integration points.** Leaving real network, database, or filesystem calls in a unit test.

Problems: slow tests; flaky tests bound to external availability; edge cases that cannot be provoked.

**Correct boundary:** substitute at architectural seams — the interfaces the unit talks *through* — and let everything inside the unit run for real.

| Test type | Substitute | Do NOT substitute |
|-----------|-----------|-------------------|
| Unit | External APIs, database, filesystem, clock | Internal helpers, private methods |
| Integration | External APIs only | Database, internal services |
| E2E | Nothing, or external APIs only | Internal systems |

## Review Questions

1. Are private or internal helpers being substituted?
2. Are tests making real external calls?
3. Do the substitution boundaries match the project's architectural boundaries?
4. Would refactoring internals — with no behavior change — break these tests?
5. Is the duplicated setup mechanical, or deliberately explicit?
