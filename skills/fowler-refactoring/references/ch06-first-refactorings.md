# Chapter 6 — A First Set of Refactorings

Source: Fowler, Second Edition, Chapter 6, PDF pp. 121–182.
Read these mechanics with a passing baseline; test after each migrated use or structural step.

## Extract Function — pp. 121–130

- Also called Extract Method; inverse: Inline Function.
- Use when a name can explain intention better than readers reconstructing implementation.
- Create an intention-revealing function and copy the selected code into it.
- Inventory free variables; pass read-only dependencies or deliberately retain lexical scope.
- Move declarations used only inside the extraction into the new function.
- Return a value that must update the caller; do not accidentally lose assignments across a pass-by-value boundary.
- If many independent outputs block extraction, first use Split Variable or Replace Temp with Query.
- Check compilation/binding, replace the original block with a call, and test.
- Search for genuinely equivalent fragments that can call the new function.
- No useful name or clarity gain: reconsider extraction; a one-line body is not itself a reason against it.

## Inline Function — pp. 131–134

- Also called Inline Method; inverse: Extract Function.
- Use for unhelpful indirection or to regroup poorly separated functions before extracting differently.
- First establish that polymorphic overrides do not change the call's meaning.
- Find callers and substitute the body at one site at a time, translating parameters to caller expressions.
- Test after each substitution; remove the definition only after its callers are gone.
- Preserve argument evaluation, local scope, returns, and side effects.
- Recursion, complicated control flow, and inaccessible object state are reasons not to use the simple recipe.

## Extract Variable — pp. 135–139

- Formerly Introduce Explaining Variable; inverse: Inline Variable.
- Use to name a meaningful subexpression and expose intermediate values to a debugger.
- Check that the expression is side-effect free at the proposed evaluation point.
- Introduce an immutable binding initialized from the expression.
- Replace one occurrence and test, then consider other equivalent occurrences.
- If the concept belongs beyond this function, prefer a query or extracted function in that wider context.
- Do not hoist evaluation across a guard that previously prevented it.

## Inline Variable — pp. 140–141

- Formerly Inline Temp; inverse: Extract Variable.
- Use when the binding adds no meaning or obstructs another transformation.
- Confirm the initializer is side-effect free and the variable is assigned only once.
- Make it immutable where the language permits, and test that assumption.
- Replace references one at a time with the initializer, testing between replacements.
- Remove the now-unused declaration and test again.
- Re-evaluation must see equivalent inputs; purity alone does not prove a mutable dependency stays unchanged.

## Change Function Declaration — pp. 141–149

- Includes Rename Function/Method, Add Parameter, Remove Parameter, and Change Signature.
- Change names to express intent and arguments to express the right dependency boundary.
- Simple route: stop using removed parameters, change declaration and all callers, then test.
- Separate rename and argument changes when combining them makes failures hard to localize.
- Migration route: extract the body behind the desired signature, leaving the old entry point forwarding to it.
- Introduce extra parameters on the new function and test the forwarding path.
- Migrate callers incrementally, then remove the old wrapper and restore any temporary name.
- Preserve polymorphic binding: the necessary forwarding path must cover each implementation.
- Published API: retain and deprecate the old entry point until independent consumers migrate, possibly indefinitely.
- Choosing a whole object versus one property is a coupling tradeoff, not a universally correct direction.

## Encapsulate Variable — pp. 150–155

- Formerly Encapsulate Field or Self-Encapsulate Field.
- Use to turn a difficult data migration into an incremental function-access migration.
- Introduce access/update functions, run static checks, and migrate each reference with tests.
- Restrict the original variable's visibility after direct consumers have migrated.
- Where privacy cannot be enforced, a controlled rename can help uncover remaining accesses.
- Encapsulate Record if callers can still mutate a record's internals through the getter.
- Encapsulating a binding does not automatically encapsulate the referenced value.
- Wide mutable scope is the main concern; immutable values need less defensive machinery.
- Internal self-encapsulation may be a useful migration seam, not a demand that every field access call a getter.

## Rename Variable — pp. 156–158

- Use when a better name records the variable's real purpose.
- For a narrow binding, update all references and test.
- For a widely used mutable binding, encapsulate access before renaming the representation.
- An immutable value can temporarily exist under both names while consumers migrate.
- Published variables cannot be renamed unilaterally with this simple recipe.
- Match the scope: a short local name can be clear; persistent or widely shared fields need richer meaning.

## Introduce Parameter Object — pp. 158–163

- Use for a recurring clump of related arguments, not arbitrary parameter-count reduction.
- Find an existing suitable structure or introduce a meaningful one, preferably with value semantics.
- Add a parameter for that structure using Change Function Declaration.
- Migrate callers to construct or pass the right object, testing each.
- Replace old parameter reads with the corresponding object member and remove each redundant parameter.
- Look for domain behavior that now belongs with the newly explicit concept.
- Do not create a generic bag that hides unrelated dependencies.

## Combine Functions into Class — pp. 164–169

- Use when functions operate on the same body of data and should share an explicit context.
- Group scattered shared arguments first if needed with Introduce Parameter Object.
- Encapsulate the common record as an object.
- Move each function to the class and remove parameters now supplied by its instance state.
- Extract and move additional behavior that belongs to the same data.
- Favor this over a snapshot transform when source data changes and derived results must remain consistent.
- A class or language-equivalent function object can expose several coherent operations.
- The goal is a cohesive context, not converting every function to a method.

## Combine Functions into Transform — pp. 170–175

- Use when consumers repeatedly compute the same derived information from stable source data.
- Create a transform initially returning the same values without modifying the original record.
- Copy deeply enough for the actual mutation depth and test that the input remains untouched.
- Move one derivation into the transform as an output field; change consumers to read it.
- Extract complex calculations first; repeat for the related derivations with tests.
- Derived fields are snapshots: mutating their source later can make them stale.
- Choose a class or recomputation strategy instead when live consistency is required.

## Split Phase — pp. 176–182

- Use when sequential processing stages operate on distinct models or responsibilities.
- Extract the second phase first and test the preserved behavior.
- Add an intermediate-data parameter to it.
- Move values produced by or shared with the first phase into that structure one at a time.
- When a second-phase parameter belongs only to earlier work, compute the needed result upstream instead.
- Move those producing statements to the caller while keeping the second phase focused on consumption.
- Extract the first phase so it returns the intermediate structure, or use an appropriate transformer object.
- Test the boundary and the complete operation.
- Parsing versus execution and calculation versus rendering are useful examples, not mandatory architectures.

## Selection checklist

- Name a local expression: Extract Variable; name a reusable operation: Extract Function.
- Shared mutable context: consider Class; stable enriched snapshot: consider Transform.
- Independent sequential models: Split Phase; recurring argument concept: Parameter Object.
- Interface migration across ownership boundaries: forwarding declaration plus compatibility interval.
- For every move, inspect evaluation order, mutation, binding, and callers before editing.
