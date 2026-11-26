# Chapter 10 — Simplifying Conditional Logic

Source: Fowler, Second Edition, Chapter 10, PDF pp. 289–341.
Use the representation that exposes the decision's meaning without changing its semantics.

## Decompose Conditional — pp. 289–291

- Use when the condition and its branches obscure why the decision exists.
- Extract the condition into a predicate named for its domain meaning.
- Extract each branch into an intention-revealing operation where that clarifies it.
- Follow Extract Function's handling of inputs, outputs, and mutation.
- Preserve which expressions are evaluated and which branches perform effects.
- Test each extraction rather than rewriting all branches at once.
- This is a focused application of Extract Function, not a mandate to wrap every simple boolean.

## Consolidate Conditional Expression — pp. 292–295

- Use when several checks produce the same action and express one combined decision.
- Confirm that the predicates have no side effects; separate queries from modifiers first if needed.
- Combine equivalent alternatives with logical OR.
- Combine nested required conditions with logical AND.
- Test each pairwise consolidation before combining another condition.
- Extract the resulting predicate when a name better communicates its purpose.
- Preserve short-circuit order and branch precedence.
- Do not combine independent business decisions solely because they currently return the same value.

## Replace Nested Conditional with Guard Clauses — pp. 295–300

- Use when exceptional or prerequisite cases bury the primary path inside nesting.
- Distinguish a special-case exit from two equally normal alternatives.
- Convert one suitable outermost special case to an early exit and test.
- Repeat until the main path is clear.
- Consolidate guards that truly express the same outcome when appropriate.
- A single-exit rule is not a stronger design principle than clarity.
- Do not skip cleanup, mandatory side effects, or error handling that previously followed the branch.
- Preserve whether a guard returns, throws, or performs a particular effect before exiting.
- Reversed conditions can clarify the normal path, but check boolean and null semantics carefully.

## Replace Conditional with Polymorphism — pp. 301–319

- Use for repeated type-based dispatch or a meaningful base case with distinct variants.
- Do not replace every conditional with classes; the source explicitly rejects that rule.
- Establish classes and a factory if the required polymorphic structure does not exist.
- Migrate construction to the factory.
- Extract the conditional into a function if needed, then place it on the common abstraction.
- Create an override for one case, copy that branch's logic, and adapt references to the new context.
- Test the migrated case and preserve the remaining cases while proceeding.
- Repeat for each variant.
- Keep legitimate default behavior in the base implementation.
- If no base behavior is valid, make the operation abstract or explicitly unreachable in the language's idiom.
- Type selection may remain in the factory; the benefit is removing repeated dispatch across operations.
- For a base-plus-variation model, emphasize only the variant's differences rather than copying the whole base algorithm.
- Verify unknown classifications and fallback paths as well as known subclasses.
- A new hierarchy should reflect an actual variation axis, not accidental syntactic similarity.

## Introduce Special Case — pp. 320–337

- Formerly Introduce Null Object; null is only one possible special value.
- Use when many clients recognize the same special value and apply the same substitute behavior.
- Start by inventorying special-case reads, writes, and exceptions across consumers.
- Give normal subjects a special-case indicator returning false.
- Introduce a special subject whose indicator returns true.
- Extract direct comparisons into a shared check and migrate all those comparisons to it.
- Introduce the special object at the producing boundary or through a transform.
- Change the shared check to inspect the indicator, then test representation compatibility.
- Move common fallback behavior into the special object or enriched record.
- Replace repeated client branches with ordinary operations on that subject.
- Inline the comparison helper at sites that genuinely still need an explicit distinction.

### Choosing the representation

- Read-only fixed defaults: an object literal or immutable record may suffice.
- Methods or more involved behavior: a dedicated special-case object can provide the common protocol.
- A transform can normalize a data graph before consumers use it.
- Keep the special-case object immutable, even if ordinary subjects are mutable.
- A setter that does nothing preserves behavior only when the previous special-case path also skipped that update.
- Do not silently discard updates that previously mattered.
- Related values may need their own special-case objects to keep the protocol coherent.
- Clients with genuinely different fallback requirements keep an explicit check rather than being forced into the majority default.
- Do not collapse distinct states such as unknown, absent, invalid, and unauthorized without a domain reason.

### Verification for special cases

- Normal subject still uses its original data and behavior.
- Special subject returns the previous common defaults.
- Writes retain the previous contract for both variants.
- Nested related values support the methods clients expect.
- Exceptional clients still receive their intentionally different fallback.
- No mutable shared singleton accumulates client-specific state.

## Introduce Assertion — pp. 338–341

- Use to state an internal condition that must already hold for the code to be correct.
- Failure denotes a programmer error, not an expected alternative outcome.
- Add the assertion at the point where the assumption matters, or nearer the source of invalid internal state.
- Write the condition without side effects.
- The program's valid behavior must remain correct if assertions are disabled or removed.
- Do not build normal recovery logic around catching assertion failures.
- Assert necessary invariants, not everything that currently happens to be true.
- Consolidate repeated predicates so assumptions do not drift between copies.
- External-input validation is ordinary program behavior and must not rely on optional assertions.
- The source calls this behavior-preserving under its invariant assumption; first establish that the invariant actually belongs to the supported contract.
- If legitimate inputs can fail it, adding the assertion changes behavior and requires a separate decision.

## Conditional selection table

| Problem | First candidate | Key question |
|---|---|---|
| Hard-to-read test and branch bodies | Decompose Conditional | Can names express the decision? |
| Same result under equivalent alternatives | Consolidate Conditional Expression | Is it one concept with pure predicates? |
| Special paths bury ordinary work | Guard Clauses | Can early exits preserve cleanup and effects? |
| Repeated classification-specific behavior | Polymorphism | Is the shared variation axis real? |
| Repeated identical fallback policy | Special Case | Which consumers actually share the fallback? |
| Hidden necessary internal assumption | Assertion | Is this an invariant, not input validation? |

## Cross-cutting hazards

- Short-circuiting, evaluation count, and exception timing are observable in many programs.
- Named predicates should not conceal mutation or network/database access.
- Removing a conditional is not inherently better than making it understandable.
- Stop at the simplest representation that makes future edits local and clear.
