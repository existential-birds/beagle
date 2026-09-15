# Cross-Chapter Decision Guide

Source: synthesis of Fowler, Second Edition, Chapters 1–12.
This guide chooses candidates; load the relevant chapter for mechanics before editing.
Application safety checks extend the book's principles to repository-specific contracts.

## Start from change cost

| Observed obstacle | Candidate | Chapter |
|---|---|---|
| Reader must reconstruct a block's purpose | Extract Function or Variable | 6 |
| Names hide a known concept | Change Function Declaration, Rename Variable/Field | 6, 9 |
| One module changes for unrelated reasons | Split Phase, Extract Class, Move Function | 6–8 |
| One policy change touches many modules | Move Function/Field, Combine Functions | 6, 8 |
| Temporary state prevents extraction | Split Variable, Replace Temp with Query | 7, 9 |
| Several values always travel together | Introduce Parameter Object | 6 |
| Same primitive-specific behavior repeats | Replace Primitive with Object | 7 |
| Updates bypass the intended owner | Encapsulate Variable/Record/Collection | 6–7 |
| Stored derivations become stale | Replace Derived Variable with Query | 9 |
| Independent computations share one traversal | Split Loop | 8 |
| Traversal syntax hides a simple transformation | Replace Loop with Pipeline | 8 |
| Repeated type-based dispatch must evolve together | Replace Conditional with Polymorphism | 10 |
| Many clients implement identical missing-value defaults | Introduce Special Case | 10 |
| Interface names hide selected modes | Remove Flag Argument | 11 |
| Function depends on hidden environmental state | Replace Query with Parameter | 11 |
| Inherited interface is not meaningful on subtype | Replace Superclass with Delegate | 12 |
| Role changes independently of host identity | Replace Subclass with Delegate | 12 |

## Resolve inverse choices

| Choice | Favor first direction when… | Favor reverse when… |
|---|---|---|
| Extract / Inline Function | A name expresses important intent | Indirection adds no meaning or obstructs regrouping |
| Extract / Inline Variable | A local concept needs a readable name | A pure stable initializer is clearer at use sites |
| Extract / Inline Class | A distinct cohesive responsibility exists | The component no longer earns its own identity/interface |
| Hide Delegate / Remove Middle Man | A relationship is an implementation secret | Forwarding surface is burdensome without meaningful protection |
| Move statements in / out | Work is inherently common to every call | Caller-specific variation should not live in the callee |
| Reference to Value / Value to Reference | Contents and snapshots matter | Shared entity updates must remain visible |
| Parameter to Query / Query to Parameter | Callee already owns the derivation | Hidden context harms isolation or purity |
| Function to Command / Command to Function | Lifecycle or shared operation state is needed | Ordinary invocation now suffices |
| Pull Up / Push Down | Behavior is truly common to subtypes | Only certain subtypes support it |
| Type Code to Subclasses / Remove Subclass | Variant behavior earns structural separation | Only a simple residual data distinction remains |

## Choose a data boundary

- Local immutable expression: a named binding may be sufficient. [Ch. 6]
- Broad mutable binding: access functions expose a migration seam. [Ch. 6]
- Mutable record: object accessors can hide stored versus calculated representation. [Ch. 7]
- Collection membership: owner methods plus protected view or copy. [Ch. 7]
- Stable source plus derived output: a transform can create a readable result record. [Ch. 6, 9]
- Mutable source with live derivations: queries on a cohesive object avoid stale snapshots. [Ch. 6, 9]
- Shared logical entity: canonical reference via a repository. [Ch. 9]
- Independent interchangeable contents: immutable value with field-based equality. [Ch. 9]

## Compose a safe sequence

### Calculation mixed with presentation — Chapters 1 and 6

1. Establish output tests.
2. Extract and name coherent calculations.
3. Remove only those temporaries that obstruct the separation.
4. Extract the rendering phase.
5. Introduce the intermediate result and move calculations upstream one at a time.
6. Add the new renderer only after the structural boundary is verified.

### Awkward parameter clump — Chapters 6 and 11

1. Identify the domain concept represented by the recurring values.
2. Introduce or reuse the parameter object.
3. Migrate the signature and callers incrementally.
4. Preserve the whole object where other callers still unpack it.
5. Move related behavior only when it belongs with that concept.

### Repeated classification logic — Chapters 6, 10, and 12

1. Encapsulate the type and centralize construction if necessary.
2. Introduce the appropriate direct subtype or delegated type object.
3. Move one branch into the corresponding implementation and test.
4. Repeat while retaining explicit default and unsupported-case behavior.
5. Remove redundant dispatch and storage only after the migrated protocol covers consumers.

### Public rename or representation migration — Chapters 2, 6, and 9

1. Determine whether every consumer is controlled by the same change.
2. For local consumers, migrate declaration and uses together when tractable.
3. For independent consumers, introduce the replacement behind a compatible old entry point.
4. Migrate consumers and observe compatibility before retiring the old form.
5. For stored data, coordinate schema, data conversion, access code, and release sequence.

## Safety questions before a step

- Does it repeat a calculation that reads changing data?
- Does it move an expression across a short-circuit guard, write, or possible exception?
- Does it turn a snapshot into a live view, or a live view into a snapshot?
- Does it change shared object identity or the scope of a mutable alias?
- Does it bypass dynamic dispatch, reflection, serialization, or an external caller?
- Does it separate an operation that must be atomic?
- Does it introduce a dependency merely to shorten a signature?
- Does the test suite actually assert the affected behavior?

## Stop and evidence rules

- Passing small steps are progress even if the larger target is not yet reached. [Ch. 1–2]
- Failed step: repair or undo only that step, then reduce its size. [Ch. 1, 5]
- Missing tests: create a narrow protective seam before broad structural changes. [Ch. 2, 4]
- Smell without demonstrated cost: investigate, do not auto-edit. [Ch. 3]
- Performance claim: measure the relevant workload rather than guess. [Ch. 2]
- Completion: name the obstacle removed, report the actual checks, and state residual uncertainty.
