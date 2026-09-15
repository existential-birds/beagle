# Chapter 2 — Principles in Refactoring

Source: Fowler, Second Edition, Chapter 2, PDF pp. 56–84.

## Definitions and boundaries — pp. 56–58

- A refactoring is an internal structural change that preserves observable behavior and improves comprehension or modification cost.
- Refactoring as an activity composes these transformations into a larger design change.
- Restructuring is the broader category; a multi-day broken rewrite is not the book's refactoring process.
- Behavior preservation concerns what users and consumers depend on, not identical implementation.
- Internal interfaces may change when all callers can be migrated together.
- Published interfaces require compatibility handling because consumers cannot all be controlled.
- Optimization has a different objective: better resource use, potentially at the expense of clarity.
- Keep the two activities distinguishable even when one enables the other.

## Two hats

- Feature hat: intentionally change capabilities and make new behavior tests pass.
- Refactoring hat: change structure while existing behavior remains stable.
- Switch hats frequently, but know which kind of change each step represents.
- Add missing coverage when discovered; adjust tests for an intentionally migrated internal interface.
- Do not hide a bug fix inside a supposedly behavior-preserving change.
- Commit separation is a team choice, not a universal rule established by Fowler.

## Why refactor — pp. 58–61

- Restore structure eroded by local changes and incomplete understanding.
- Remove duplicated knowledge so a conceptual change does not require synchronized edits.
- Make code understandable to the next reader, including its original author later.
- Externalize understanding through names and boundaries rather than relying on memory.
- Clarified assumptions can reveal bugs; finding one does not authorize an unrelated behavior change.
- Improve delivery speed by reducing comprehension, coordination, and debugging cost.
- The Design Stamina Hypothesis links internal quality to sustained delivery speed.
- Fowler labels it a hypothesis; do not turn its illustrative curves into measured forecasts.

## Timing decision table — pp. 61–68

| Situation | Response | Boundary |
|---|---|---|
| Next feature is awkward to add | Preparatory refactoring | Make this change easier, not every possible future change |
| Reading requires reconstructing intent | Comprehension refactoring | Encode a tested understanding in the code |
| Small local mess obstructs current work | Litter-pickup refactoring | Repair cheaply or record larger work separately |
| Neglect has accumulated into a serious obstacle | Planned refactoring may be justified | Keep intermediate states working |
| Cross-cutting migration spans weeks | Incremental coordinated transformation | Agree direction and migrate reachable pieces |
| Ugly implementation behind a stable usable boundary | Often leave it alone | Refactor when understanding or modification is needed |
| Rewrite may genuinely cost less | Investigate and compare | No simple size or age threshold decides this |

## Rule of three and opportunistic work

- The rule of three suggests tolerating early repetition until a recurring pattern is clearer.
- It is a heuristic for abstraction timing, not permission to preserve harmful duplicated policy.
- Excellent code also needs refactoring when requirements change its former tradeoffs.
- Most refactoring belongs inside ordinary development rather than a separate cleanup season.
- Large planned episodes are possible, but should not become the routine remedy for continual neglect.
- Prioritize code visited repeatedly; its comprehension cost recurs most often.
- Explain the payoff in delivery and reliability terms, not moral claims about cleanliness.

## Long-running changes and review — pp. 65–67

- Branch By Abstraction: introduce an abstraction usable by old and new implementations.
- Move clients to it before replacing the implementation behind it.
- Keep each intermediate deployment or checkpoint usable.
- In a review, trying a small refactoring can reveal consequences that discussion alone misses.
- Working with the author preserves context; pair review supports immediate feedback.
- Do not reinterpret the book's management commentary as permission to conceal scope or bypass approvals.

## Ownership and published interfaces — pp. 69–70

- If declaration and all callers are controlled together, migrate them as one logical change.
- Otherwise retain the original entry point as a forwarding compatibility path.
- Deprecate and retire only when external use is known to have ended.
- Sometimes that compatibility path must remain indefinitely.
- Fine-grained exclusive ownership can turn ordinary changes into published-API migrations.
- Team ownership lowers coordination barriers without eliminating responsibility or review.
- Cross-team changes need acceptance by the owners of affected consumers.

## Branches, tests, and integration — pp. 70–72

- Textually successful merges can still create semantic failures, such as calls to a renamed method.
- Pulling mainline into a branch is one-way synchronization, not completed integration with peers.
- The book's CI model integrates each developer's changes with mainline at least daily.
- Long isolation makes widespread small refactorings harder to combine safely.
- Small feature slices and feature toggles can help preserve a healthy mainline.
- Respect the actual repository branching policy rather than imposing a different one.
- A fast self-checking suite makes frequent safe steps practical.
- Automated refactorings can help when coverage is weak, but only within their actual semantic guarantees.
- Dynamic dispatch, reflection, generated code, and external consumers reduce those guarantees.

## Legacy code — pp. 72–73

- Missing tests create a circular problem: test seams may require risky structural changes.
- Find narrow seams to introduce coverage instead of redesigning the whole system first.
- Prefer narrowly justified, well-supported mechanical moves for that initial seam work.
- Make the uncovered risk explicit rather than claiming automated syntax changes prove behavior.
- Improve frequently changed regions incrementally.
- The book points to Michael Feathers for detailed legacy-code techniques; it does not supply a complete method here.

## Database changes — pp. 73–74

- Treat schema, access code, and existing stored data as one migration problem.
- Version small composable data-migration steps with their related code changes.
- For a cross-release rename, first add the new field without removing the old one.
- Introduce compatible writes to both representations as needed.
- Migrate readers progressively and verify the new representation.
- Retain a compatibility interval before removing the obsolete field.
- This is parallel change, also called expand-contract.
- Deployment coordination and reversibility are part of the design, not afterthoughts.

## Architecture and YAGNI — pp. 74–77

- Refactoring permits architecture to evolve as real requirements become clearer.
- Speculative flexibility carries present complexity and may encode the wrong future.
- Build a clear design for current needs; add variation when actual callers require it.
- Simple boundaries and meaningful names are useful even without speculative extension machinery.
- Consider how expensive a deferred change would be; hard-to-reverse decisions still deserve advance thought.
- YAGNI is not the absence of architecture.
- Self-testing code, frequent integration, and refactoring reinforce one another.
- Those foundations support evolutionary design and continuously releasable software.

## Performance — pp. 77–80

- Hard real-time systems need explicit resource budgets; ordinary tuning advice is not a substitute.
- Continuous speculative micro-optimization distributes effort poorly and can obscure design.
- Profile a representative workload to identify actual hot spots.
- Change one hot spot, run correctness tests, and measure again.
- Discard optimizations that do not deliver the required benefit.
- Stop when performance satisfies the real requirement, not when every line looks optimal.
- The chapter's percentages and success anecdote illustrate concentration of cost; they are not universal guarantees.

## History, automation, and further study — pp. 80–84

- Smalltalk practice, Beck and Cunningham, Johnson and Opdyke, and the Refactoring Browser shaped the technique.
- Reliable automation understands syntax and binding, not just matching text.
- Static type information can distinguish identically named methods on unrelated classes.
- Tool maturity and language features determine safety; tool-era comparisons are historical, not current rankings.
- The chapter points to exercises, refactoring-to-patterns, database, HTML, legacy-code, and language-specific literature.
- These notes cover Fowler's book only; those works have not been silently imported as additional sources.
