# Chapter 4 — Building Tests

Source: Fowler, Second Edition, Chapter 4, PDF pp. 100–117.
Scope: fast tests for business logic; not a complete testing or UI-automation textbook.

## Self-testing code — pp. 100–102

- Tests perform their own expected-versus-actual comparison.
- Console output requiring human inspection is not the safety net described here.
- Keep execution cheap enough to repeat during development.
- A short interval between passing runs limits the code in which a regression can hide.
- The main return is less debugging time, not a larger test count.
- New-feature TDD uses a failing test, an implementation that passes it, and structural cleanup.
- For existing code, establish useful tests before beginning refactoring.
- Do not postpone all coverage until the end of a structural rewrite.

## Example model and test seam — pp. 102–106

- A province contains producers, demand, price, and aggregate production data.
- The UI edits values; business logic calculates shortfall and profit.
- Test the calculation model independently of HTML and UI event wiring.
- The chapter deliberately avoids persistence and external-service dependencies.
- A fixture factory supplies representative province and producer input data.
- Some setters parse string inputs because that is what the UI supplies.
- The production setter also maintains province-derived state, making it a high-risk target.
- Do not refactor that awkward update path before tests cover its effects.
- Transfer the seam principle, not the example's class names or framework choices, to a real project.

## Anatomy of a useful test — pp. 106–109

1. Construct a known fixture.
2. Exercise the behavior if the test concerns a change rather than initial state.
3. Assert an expected result or invariant.
4. Ensure test state and resources do not leak into another test.

- Common names: arrange-act-assert, given-when-then, setup-exercise-verify.
- Teardown is an implicit fourth phase for simple memory-only objects, but explicit for shared resources.
- Give each test a failure-identifying description.
- Failure output should expose expected and actual values and identify the test.
- The source demonstrates Mocha `describe`, `it`, and `beforeEach`, with Chai assertions.
- These are examples, not dependencies to install into an unrelated repository.
- Discover the actual runner and canonical invocation from repository files.

## Verify that the test can detect a defect

- Observe a new test fail for the intended reason at least once.
- For existing behavior, a temporary localized fault can prove the assertion reaches the code.
- Remove the injected fault immediately and confirm a passing run.
- Do not confuse an unrelated setup error with evidence that the behavior assertion works.
- Fault injection belongs in isolated local test work, never in shared or production systems.
- The book's green-bar language means the relevant suite is passing before structural work.
- A red bar is a reason to resolve or explicitly isolate the failure, not continue blind.

## Expectations for existing behavior — pp. 109–110

- Prioritize outcomes likely to be broken by the intended change.
- The source sometimes records output from code assumed to work, then checks test sensitivity with a fault.
- Such a recorded expectation characterizes current behavior; it does not independently establish domain correctness.
- Hand-check critical rules or compare with an authoritative contract when correctness is in doubt.
- Keep potential pre-existing defects separate from the refactoring scope.
- A small valuable suite now is better than abandoning tests because complete coverage is unattainable.

## Fixture isolation — pp. 110–112

- A constant binding does not make the referenced object immutable.
- A shared mutable fixture creates order-dependent test failures.
- Build a fresh fixture before each test as the default.
- Common setup makes the baseline easy to learn without sharing its mutable instance.
- A fixture factory can serve the same purpose in a different testing framework.
- Consider sharing only if construction is measurably expensive or data is truly immutable.
- Shared resources need clear teardown and reset semantics.
- A test that passes alone but fails in a group warrants an isolation investigation.
- Protect the suite's determinism; confidence is damaged by unexplained intermittent failures.

## Updating the fixture — p. 112

- Cover meaningful mutation, not merely the initial getters.
- Exercise the production update and verify affected aggregate outcomes.
- Distinguish straightforward field access from setters with parsing or synchronization behavior.
- Prefer focused assertions because an early failure can hide later diagnostic information.
- Closely related outcomes may reasonably be verified together.
- Do not turn "one assertion" into a ritual that duplicates complicated setup without benefit.

## Boundary probes — pp. 113–116

| Input or situation | What to investigate |
|---|---|
| Empty producer collection | Aggregate identities and absence handling |
| Zero demand or zero values | Division, minimums, and empty-work paths |
| Negative demand or production | Whether the domain permits it and how it should behave |
| Blank UI input | Parsing and representation of missing numeric values |
| Malformed collection input | Trust boundary and meaningful validation behavior |
| State changed after construction | Derived totals and dependent results |

- Boundary tests raise domain questions; they do not answer those questions automatically.
- Do not silently clamp, reject, or default an input during behavior-preserving work.
- External input needs validation at an appropriate boundary.
- Repeated defensive validation inside a trusted boundary can obscure the code and duplicate policy.
- An unexpected exception during setup differs from a failed expected-result assertion.
- Determine whether a failure lies inside the supported contract before preserving or changing it.
- Fowler excludes an invalid internal-input example from his refactoring contract; do not assume every malformed input is unobservable in a real system.
- Assertions document programmer assumptions; they are not substitutes for external validation.

## Risk-driven coverage — pp. 109, 116–117

- Focus on complex calculations, likely mistakes, and behavior the planned transformation threatens.
- Do not test every trivial accessor merely to satisfy a method-count goal.
- Use coverage reports to find untested areas, not to certify assertion quality.
- Passing tests support confidence but cannot prove the absence of every bug.
- Reassess missing cases as understanding improves during refactoring.
- Fast unit tests are the backbone, not the entirety, of system verification.
- Add integration and other checks when the actual risk crosses those boundaries.
- Excessive coupling to internal structure can make tests expensive to maintain.

## Bug-response and maintenance loop — p. 117

1. Reproduce a reported bug with a focused automated test.
2. Confirm the test fails because of that bug.
3. Fix the behavior in its own change.
4. Run the regression and relevant surrounding checks.
5. Ask whether the failure suggests sibling gaps in coverage.
6. Refactor the tests when their own duplication or naming obscures intent.

## Completion evidence

- Record the actual test command and result, not just "tests added."
- Confirm the baseline, intended failure where a new test was introduced, and final passing state.
- Explicitly identify uncovered behavior or unavailable test infrastructure.
