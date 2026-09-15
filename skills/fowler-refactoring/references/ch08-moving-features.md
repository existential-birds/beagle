# Chapter 8 — Moving Features

Source: Fowler, Second Edition, Chapter 8, PDF pp. 224–267.
Move responsibilities to reduce the knowledge required for the next change.

## Move Function — pp. 224–233

- Formerly Move Method.
- Use when data, dependencies, callers, or reuse opportunities point to a better context.
- Inspect all referenced elements and any polymorphic declarations before selecting the destination.
- Move required helper functions first when that reduces dependency complexity.
- Another route is to inline private helpers into the moving function and re-extract at the destination.
- Copy the function to its target context; adjust names and references to fit that context.
- Pass source data or a source-context reference only where still necessary.
- Run static checks, establish access to the target, and make the source function delegate there.
- Test the forwarding path before migrating or inlining callers.
- Keep forwarding when compatibility or a useful boundary requires it; otherwise remove the unnecessary hop.
- A move can change lexical scope, receiver binding, imports, and visibility even when the body looks identical.

## Move Field — pp. 234–240

- Use when a field travels with another record or changes with a different responsibility.
- Encapsulate the field and test before moving its storage.
- Add the corresponding target field and accessors, then establish source-to-target access.
- Redirect the source accessors to the target field and test.
- Remove the original storage only when all reads and writes use the destination.
- If several source objects share one target, inspect whether their formerly separate values actually agree.
- A temporary dual-write and consistency assertion can expose disagreement before changing authority.
- Do not silently collapse distinct per-object state into shared state.
- Bare records lack accessors, so their consumers and representation changes need extra coordination.
- Moving persisted data also requires the separate migration treatment discussed in Chapter 2.

## Move Statements into Function — pp. 241–244

- Inverse: Move Statements to Callers.
- Use when every relevant call performs the same adjacent work and that work belongs to the callee.
- Slide the statements next to the call if dependency analysis permits.
- With one caller, move the statements directly and test.
- With several callers, extract a temporary wrapper containing the call and repeated statements.
- Migrate each equivalent call sequence to that wrapper and test.
- Inline the original function into the wrapper after its former call sites have migrated.
- Rename the wrapper to the original or a better responsibility name.
- If the extra work does not belong to the original abstraction, retain a separately named wrapper instead.
- Do not force caller-specific behavior into a supposedly common function.

## Move Statements to Callers — pp. 245–249

- Inverse: Move Statements into Function.
- Use when behavior formerly common to all calls now needs to vary independently.
- Move varying statements to the function's edge with Slide Statements first when needed.
- For a very small function and few callers, move the statement directly to each caller and test.
- Otherwise extract the part that should remain into a temporarily named function.
- Inline the original wrapper into callers so the varying work becomes visible there.
- Rename the retained core operation and test.
- For overridden methods, preserve dispatch while arranging equivalent wrappers across implementations.
- If the boundary is broadly wrong, inline and re-extract rather than wrestling with many tiny relocations.
- Preserve before/after order and exception behavior at each caller.

## Replace Inline Code with Function Call — pp. 250–251

- Use when an existing function already expresses the same behavior and purpose.
- Check its definition, contract, and availability rather than guessing from its name.
- Substitute the function call and test.
- Similar-looking code with a different reason to change is coincidental duplication, not necessarily shared behavior.
- Rename a misleading function first when its real intent is appropriate.
- A suitable library function can eliminate owned implementation, but its edge behavior must also match.

## Slide Statements — pp. 252–256

- Formerly Consolidate Duplicate Conditional Fragments.
- Use to group related operations or make a coherent extraction contiguous.
- Pick the destination and analyze every crossed statement for interference.
- Do not move earlier than required declarations or later than dependent uses.
- Do not cross writes to values read by the moving fragment.
- Do not move a write across other reads or writes that depend on its ordering.
- Include hidden effects in function calls, not only visible variable assignments.
- Move the fragment and test; if it fails, reduce distance or fragment size.
- Grouping visually similar statements is not enough to justify changing their execution order.

## Split Loop — pp. 256–259

- Use when one traversal performs independent jobs that should be understood separately.
- Copy the loop, then partition responsibilities so each effect occurs in the intended loop only.
- Eliminate duplicated side effects introduced by the copy before executing the changed program.
- Test the split, then consider Extract Function for each complete responsibility.
- Move each accumulator's initialization and result use with its corresponding computation.
- Check that an operation on item A need not happen before another operation on item B.
- Preserve early termination and exception-order requirements; independent-looking bodies may not be reorderable.
- Additional traversals are a performance tradeoff to measure, not an automatic rejection.

## Replace Loop with Pipeline — pp. 260–266

- Use when filtering, mapping, or aggregation operations communicate the algorithm better.
- Introduce a variable representing the collection being processed.
- Translate the first piece of loop behavior into a pipeline operation and test.
- Repeat in order until no behavior remains in the loop.
- Remove the empty loop and connect the pipeline result to the former accumulator as required.
- Choose operations supported by the actual language and collection implementation.
- Check ordering, laziness, intermediate allocations, mutation, and early exits.
- Avoid a pipeline that hides complicated state transitions more than it explains them.

## Remove Dead Code — pp. 266–267

- Use for code established to be unneeded, not merely unfamiliar.
- Search for references when the code can be invoked from elsewhere.
- Check external entry points, reflection, framework registration, generated consumers, and conditional paths.
- Remove the dead code, then run relevant checks.
- Do not preserve whole obsolete implementations as commented-out blocks when version control retains history.
- Tool reports and local search absence are evidence, not proof that a published entry point is unused.
- Record uncertainty instead of deleting code whose reachability cannot be established.

## Move safety checklist

- Ownership: does the destination really own the responsibility or just happen to call it today?
- Identity: does one source map to one target, or are formerly separate values becoming shared?
- Dispatch: do receiver, overrides, closures, and bound callbacks retain their meaning?
- Order: are crossed operations independent, including their failures and external effects?
- Compatibility: can all consumers migrate now, or must a forwarding layer remain?
- Verification: run the same behavior checks before and after each small movement.
