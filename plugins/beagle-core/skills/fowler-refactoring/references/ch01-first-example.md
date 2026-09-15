# Chapter 1 — Refactoring: A First Example

Source: Fowler, *Refactoring*, Second Edition, Chapter 1, PDF pp. 5–55.
These are synthesized decision and mechanics notes, not a reproduction of the example program.

## Problem and change drivers

- The example produces theater invoices from performance and play data.
- The existing program works; its weakness appears when requirements change.
- One new requirement is HTML output in addition to plain text.
- Another is more play categories with different pricing and volume-credit rules.
- Copying the original function for a new renderer would duplicate business calculations.
- Scattering new type conditions through independent calculations would multiply change sites.
- Refactor to make those changes easier, rather than because the small example looks untidy.
- Leave stable, understandable code alone when there is no change or comprehension benefit.

## Safety foundation — PDF pp. 9–15

- Establish self-checking tests before structural changes.
- For a string-producing function, compare output against manually checked expected strings.
- Include different categories and input cases rather than only one happy-path invoice.
- Run tests after every small move; minimize the interval in which a failure could originate.
- Compile or perform the language's equivalent syntax/build check where applicable.
- A failed tiny change is easier to diagnose than a failed batch of plausible edits.
- If diagnosis is not immediate, restore the last good state and retry with smaller moves.
- The book uses private version-control checkpoints; follow the user's actual Git permissions.

## Stage 1: expose intent with named functions — PDF pp. 10–31

### Extract the amount calculation

1. Identify the contiguous block that calculates one performance's charge.
2. Name the extracted function for that responsibility rather than for its syntax.
3. Inventory every variable read or written in the block.
4. Pass values read but not modified as parameters, unless the surrounding scope supplies them deliberately.
5. Move an internal-only temporary and its initialization into the new function.
6. Return the single value needed by the caller rather than mutating an outer accumulator.
7. Replace the original block with a call and run the tests.
8. Rename local variables in separate checked steps as understanding improves.

### Replace derived temporaries with queries

- The play can be obtained from the performance; passing both creates redundant knowledge.
- Extract the lookup into a query before replacing its local variable.
- Inline the temporary's uses, then migrate the calculation to obtain the value itself.
- Remove the redundant parameter only after the function no longer depends on it.
- This reduces local-variable coupling and makes later extractions easier.
- Repeating a pure lookup is not equivalent to repeating I/O or a stateful operation.
- Assess the actual cost and semantics before generalizing the example.

### Extract volume credits

- Distinguish the per-performance credit from the accumulated invoice credit.
- Return a per-performance value; let the caller accumulate it.
- Do not accidentally reset the total or retain a dependency on the enclosing loop.
- Remove explanatory comments only when the named function makes their explanation redundant.

### Name and centralize formatting

- A general name such as `format` hides what kind of formatting is performed.
- Choose a name that communicates currency and relevant units in its context.
- Keep the conversion from integer monetary units to display units in one place.
- The source uses integer cents and display conversion; do not impose that model on a different domain.
- Good names can be revised later; a provisional meaningful name is better than a vague permanent one.

### Remove loop accumulators in four separate moves

1. Split Loop to isolate the particular accumulation.
2. Slide Statements to place its initialization beside that loop.
3. Extract Function around initialization, accumulation, and result.
4. Inline Variable so the caller asks for the total directly.

- Repeat independently for each total.
- Resolve naming collisions with a temporary name, then rename after removing the old binding.
- Test after each transformation, not only after the four-move sequence.
- Multiple traversals may be an acceptable trade for simpler responsibilities.
- Do not assume repeated traversal is free or prematurely optimize it without measurement.

## Stage 2: separate calculation and rendering — PDF pp. 31–43

1. Extract the second phase, initially retaining its existing inputs and nested helpers.
2. Introduce an intermediate statement-data record and pass it to the renderer.
3. Move one required input at a time into that record.
4. Enrich each performance record with the values required for rendering.
5. Copy input records before adding derived fields so callers' data is not changed.
6. Move lookup and calculation functions to the producer of the intermediate data.
7. Replace renderer calculations with reads from that data structure.
8. Move aggregate calculations into the producer as well.
9. Extract the first phase into its own function and module once its boundary is clear.
10. Add the HTML renderer against the same calculated data as a separate behavior addition.

- Renderer responsibility: layout and representation.
- Producer responsibility: business calculations and statement data.
- The intermediate record is a contract between phases, not a dumping ground for all inputs.
- A plain data boundary can hide the producer's eventual class hierarchy.
- Add direct tests for intermediate results when they provide a stable and useful seam.
- More lines can be worthwhile if they eliminate duplicated business knowledge and reduce change coupling.
- The book's shallow-copy idiom protects only top-level enrichment, not arbitrary nested mutation.

## Stage 3: reorganize calculations by type — PDF pp. 43–54

1. Introduce a performance-calculator class holding the data its calculations require.
2. Move a calculation by copying it into the class and adapting its context references.
3. Make the original function delegate to the method, then test the moved implementation.
4. Inline the forwarding function after callers can use the calculator directly.
5. Repeat for the other calculation.
6. Replace construction with a factory so type selection has one explicit location.
7. Introduce a subclass for each existing category.
8. Move one conditional branch into the matching override and test.
9. Preserve common volume-credit behavior as a default; override only genuine variation.
10. Retire unreachable base behavior once all cases have migrated.

- The payoff increases when several functions vary along the same classification axis.
- The type decision is centralized in construction rather than repeated across calculations.
- New categories still require intentional factory support; polymorphism does not remove all selection.
- Returning intermediate data avoids exposing calculator implementation choices to renderers.
- Do not introduce this hierarchy for an isolated, simple conditional without a changeability benefit.

## Transferable outcome

- Decomposition helps discover the program before deciding its final structure.
- Split Phase enables independent presentation changes without copying calculations.
- Polymorphism groups the calculations that vary together.
- The important invariant is a working program after each small transformation.
- Success is easier, safer change—not minimum line count or completion of every imaginable cleanup.
