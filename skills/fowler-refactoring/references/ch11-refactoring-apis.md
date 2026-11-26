# Chapter 11 — Refactoring APIs

Source: Fowler, Second Edition, Chapter 11, PDF pp. 342–388.
API shape allocates responsibility between a function, its caller, and its context.

## Separate Query from Modifier — pp. 342–345

- Use when a returned value and observable side effects are tangled together.
- Copy the operation under a query-oriented name and remove its observable effects.
- Run static checks before changing callers.
- At each caller that uses the result, obtain it from the query and retain the original modifying call in the correct sequence.
- Test each migration; remove the modifier's return value once no consumer uses it.
- Consolidate remaining duplicated calculation after the split is verified.
- Internal caching can still qualify as an unobservable implementation detail when query results and contracts remain stable.
- Do not split a genuinely atomic read-modify operation if a concurrent change can intervene.
- Verify whether the result describes pre-update or post-update state; do not blindly reorder it.
- Command-query separation is a strong design preference here, not an absolute prohibition on every combined operation.

## Parameterize Function — pp. 346–349

- Formerly Parameterize Method.
- Use when similar operations vary in literal values while sharing the same conceptual algorithm.
- Select an existing function and add parameters for those varying literals.
- Update its callers to pass the former values and test.
- Replace literals in the body one at a time and test.
- Migrate each related operation to the parameterized function with its corresponding values.
- Adjust the abstraction only when its semantics genuinely cover the next variant.
- Avoid combining unrelated policies merely because their current arithmetic happens to look alike.

## Remove Flag Argument — pp. 350–355

- Formerly Replace Parameter with Explicit Methods.
- Use when callers choose different operations through literal booleans, strings, or enums.
- Create a clearly named operation for each relevant mode.
- If dispatch is clean, decompose it into those operations; otherwise introduce explicit wrappers.
- Replace literal-mode callers with the matching operation and test each migration.
- An input boolean passed as ordinary data is not automatically a flag argument.
- Data-driven selection may still need the original dispatching form.
- Several interacting flags may indicate a function that needs decomposition, not an explosion of names for every combination.
- An internal flag-bearing implementation can remain behind clearer public wrappers when untangling it is not yet useful.

## Preserve Whole Object — pp. 356–361

- Use when callers unpack related properties only to pass them together to another function.
- Create a temporary function accepting the whole object.
- Initially delegate to the old function by deriving its original arguments from that object.
- Run static checks, then migrate callers individually with tests.
- Remove now-unused caller-side extraction code.
- Inline the old function into the new boundary and rename the replacement appropriately.
- Passing the whole can reduce signature churn and keep interpretation in one place.
- Countercondition: the receiver may need independence from the whole object's module or type.
- Repeated use of only one coherent subset can indicate Extract Class instead.
- If the behavior belongs with the data itself, consider Move Function rather than only changing its arguments.

## Replace Parameter with Query — pp. 362–365

- Formerly Replace Parameter with Method; inverse: Replace Query with Parameter.
- Use when the callee can derive a passed value just as appropriately as the caller.
- Prefer the straightforward case where the value follows from another existing parameter.
- Extract the derivation into a query if that clarifies it.
- Replace parameter uses in the body with that calculation, testing each change.
- Remove the redundant parameter through Change Function Declaration.
- Do not add an unwanted dependency simply to shorten the argument list.
- Do not destroy referential transparency by replacing explicit data with mutable global access.
- Check whether the caller intentionally supplied a snapshot or override rather than a redundant calculation.

## Replace Query with Parameter — pp. 366–369

- Inverse: Replace Parameter with Query.
- Use to remove a hidden environmental dependency or prepare to move a function to another context.
- Extract the query into a local binding.
- Extract the remaining computation into a new function receiving that value.
- Inline the temporary binding so the wrapper passes the query result explicitly.
- Inline the old wrapper into callers where migration is appropriate.
- Rename the extracted computation once the old declaration no longer conflicts.
- Pure calculations surrounded by an I/O-handling layer become easier to test and reason about.
- The tradeoff is extra responsibility for callers; do not parameterize every dependency indiscriminately.

## Remove Setting Method — pp. 370–372

- Use when a field should be initialized once rather than changed throughout the object's lifetime.
- Add required values to the constructor, initially reusing the existing setter there.
- Migrate external setup sequences to supply constructor values instead of calling the setter.
- Test each construction-path change.
- Inline the remaining setter into construction and make the field immutable if supported.
- If callers must update a shared reference object and cannot replace it, stop: the premise does not hold.
- Keep constructor validation and normalization behavior when removing the method.
- Removing a setter does not protect nested mutable objects automatically.

## Replace Constructor with Factory Function — pp. 373–375

- Formerly Replace Constructor with Factory Method.
- Use for meaningful construction names, alternative implementations, or ordinary-function composition.
- Introduce a factory initially calling the existing constructor without changing behavior.
- Migrate constructor calls one at a time and test.
- Restrict direct construction only as far as the language and compatibility contract allow.
- A factory creates an evolution point; it need not immediately introduce caching or subclass selection.
- Keep object identity, initialization side effects, and failure behavior stable during this move.

## Replace Function with Command — pp. 376–383

- Formerly Replace Method with Method Object; inverse: Replace Command with Function.
- Use when an operation needs a richer lifecycle, undo, customization, or shared state for decomposition.
- Introduce a class representing the operation and move its body into an execution method.
- Retain the original function as a forwarding facade during the transformation.
- Follow the project's execution-method convention; the source suggests `execute` or `call` when none exists.
- Consider moving arguments into constructor-initialized fields so helper methods share context.
- Extract subsidiary operations after the state has an explicit home.
- Distinguish a command object from a modifier in command-query separation; a command object can represent a pure calculation.
- Added lifecycle and state are costs; prefer an ordinary function when they provide no necessary capability.
- Do not reuse a stateful command instance across invocations without explicitly preserving initialization semantics.

## Replace Command with Function — pp. 384–388

- Inverse: Replace Function with Command.
- Use when a command object's lifecycle and structure no longer earn their complexity.
- Extract object construction plus execution into the replacement function.
- Inline helper methods into the execution method, exposing return values as locals where needed.
- Move constructor parameters into the execution signature.
- Replace field reads with parameters one at a time and test.
- Inline construction and execution into the replacement function.
- Test, then remove the unused command class.
- Preserve per-invocation state and ordering; do not turn former instance fields into shared module state.

## API decision rules

- Distinct operations chosen by literals: explicit names; one algorithm with varying data: parameters.
- Callee already owns the information: query may simplify callers; hidden environment: parameter may improve isolation.
- Cohesive related inputs: whole object; unwanted module coupling: narrower values.
- Necessary operation lifecycle: command; straightforward invocation: function.
- Across published boundaries, retain a compatibility path until consumer migration is verified.
