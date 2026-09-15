# Chapter 3 — Bad Smells in Code

Source: Kent Beck and Martin Fowler, Second Edition, Chapter 3, PDF pp. 85–99.
Smells are contextual evidence for investigation, not defects established by a metric.

## Mysterious Name — p. 86
- Symptom: a reader must inspect implementation to understand a name.
- Moves: Change Function Declaration, Rename Variable, Rename Field.
- Trouble naming a responsibility may reveal a missing concept or mixed concerns.

## Duplicated Code — pp. 86–87
- Symptom: one conceptual change requires keeping equivalent code fragments synchronized.
- Moves: Extract Function; Slide Statements to align near-duplicates; Pull Up Method for common subclass behavior.
- Confirm shared meaning, not merely similar syntax, before unifying implementations.

## Long Function — pp. 87–88
- Symptom: excessive distance between the code's purpose and its detailed mechanics.
- Moves: Extract Function; Replace Temp with Query; Introduce Parameter Object; Preserve Whole Object.
- If local state still obstructs extraction, consider Replace Function with Command.
- Decompose conditionals and split multi-purpose loops; names matter more than line-count thresholds.

## Long Parameter List — p. 88
- Symptom: callers must coordinate many details or pass values derivable from other arguments.
- Moves: Replace Parameter with Query, Preserve Whole Object, Introduce Parameter Object, Remove Flag Argument.
- Combine Functions into Class when several functions repeatedly receive the same context.

## Global Data — pp. 88–89
- Symptom: distant code can change shared state without a discoverable control point.
- Moves: Encapsulate Variable, then narrow scope to the responsible module or class.
- Class variables and singletons can have the same problem; enforced immutable globals are different.

## Mutable Data — pp. 89–90
- Symptom: writes invalidate assumptions elsewhere, especially for derived or widely scoped state.
- Moves: Encapsulate Variable, Split Variable, Separate Query from Modifier, Remove Setting Method.
- Replace Derived Variable with Query eliminates redundant synchronization obligations.
- Combine related processing or use Change Reference to Value where immutable replacement fits.

## Divergent Change — pp. 90–91
- Symptom: one module changes for several unrelated reasons.
- Moves: Split Phase for sequential contexts; Extract Function and Move Function for interleaved contexts; Extract Class.
- Direction: split unrelated responsibilities into cohesive destinations.

## Shotgun Surgery — p. 91
- Symptom: one kind of change requires edits across many modules.
- Moves: Move Function, Move Field, Combine Functions into Class or Transform, sometimes Split Phase.
- Direction: bring scattered related responsibility together; inline first and re-extract if current boundaries obstruct it.

## Feature Envy — pp. 91–92
- Symptom: a function mostly interrogates another module's data and behavior.
- Moves: Move Function, or Extract Function then move the relevant piece.
- Group what changes together; Strategy or Visitor can deliberately separate behavior from data.

## Data Clumps — p. 92
- Symptom: the same related values recur in fields and parameter lists.
- Moves: Extract Class, Introduce Parameter Object, Preserve Whole Object.
- Ask whether the remaining values still make sense when one is removed; find behavior for the new concept.

## Primitive Obsession — p. 93
- Symptom: domain semantics, units, validation, or formatting are scattered around strings and numbers.
- Moves: Replace Primitive with Object; Extract Class or Introduce Parameter Object for groups.
- For behavior-driving classifications, consider Replace Type Code with Subclasses and then polymorphism.

## Repeated Switches — pp. 93–94
- Symptom: the same classification is dispatched in multiple places that must evolve together.
- Move: Replace Conditional with Polymorphism.
- A single simple switch is not the smell; modern matching constructs are not automatically inferior.

## Loops — p. 94
- Symptom: traversal mechanics hide selection and transformation intent.
- Move: Replace Loop with Pipeline when named operations clarify that intent.
- Preserve ordering, early exits, state effects, and collection semantics when evaluating the choice.

## Lazy Element — p. 94
- Symptom: a function, class, or hierarchy level no longer contributes meaning or behavior.
- Moves: Inline Function, Inline Class, Collapse Hierarchy.
- Removal depends on actual consumers and contracts, not an aesthetic dislike of delegation.

## Speculative Generality — pp. 94–95
- Symptom: unused hooks, parameters, and layers support only imagined future requirements.
- Moves: Collapse Hierarchy, Inline Function/Class, Change Function Declaration, Remove Dead Code.
- Tests-only use is a clue, not proof of dead public, plugin, reflective, or externally invoked behavior.

## Temporary Field — p. 95
- Symptom: a field is meaningful only during a narrow operation or special state of an otherwise broader object.
- Moves: Extract Class and Move Function to collect the conditional state and its behavior.
- Introduce Special Case when a missing or inactive variant has consistent behavior.

## Message Chains — p. 95
- Symptom: a consumer knows the sequence of intermediate objects needed to reach its real dependency.
- Moves: Hide Delegate at a useful boundary; or extract consumer behavior and move it toward the data.
- Do not hide every hop indiscriminately; that can create a Middle Man.

## Middle Man — pp. 95–96
- Symptom: an interface mostly forwards operations without earning the maintenance cost.
- Moves: Remove Middle Man, Inline Function; use delegation-based redesign where inheritance also misleads.
- Balance representation hiding against the forwarding surface clients actually need.

## Insider Trading — p. 96
- Symptom: modules share too much internal knowledge or subclasses exploit intimate superclass details.
- Moves: Move Function/Field, create a module for shared responsibility, Hide Delegate.
- Replace Subclass or Superclass with Delegate when inheritance is the source of inappropriate coupling.

## Large Class — pp. 96–97
- Symptom: unrelated field clusters and client-specific subsets indicate multiple responsibilities.
- Moves: Extract Class, Extract Superclass, Replace Type Code with Subclasses where the relationship is valid.
- Remove internal duplication; use actual client usage and coherent field groups to choose boundaries.

## Alternative Classes with Different Interfaces — p. 97
- Symptom: interchangeable implementations cannot substitute because their protocols differ.
- Moves: Change Function Declaration, Move Function, and possibly Extract Superclass for real commonality.
- Match behavioral meaning as well as signatures.

## Data Class — pp. 97–98
- Symptom: clients manipulate a data holder in detail and own behavior that belongs with it.
- Moves: Encapsulate Record, Remove Setting Method, Move Function, or extract then move.
- Exception: an effectively immutable intermediate result from Split Phase may correctly remain plain data.

## Refused Bequest — p. 98
- Symptom: a subclass inherits behavior or an interface that does not fit its meaning.
- Moves: Push Down Method/Field for misplaced commonality; Replace Subclass/Superclass with Delegate for interface mismatch.
- Reusing only part of an implementation can be acceptable; violating substitutability is more serious.

## Comments — pp. 98–99
- Symptom: prose explains convoluted implementation instead of the code exposing its intent.
- Moves: Extract Function, Change Function Declaration, Introduce Assertion for internal assumptions.
- Preserve rationale, constraints, and uncertainty; the chapter does not advocate deleting useful comments.

## Choosing and stopping

- Describe the observed change cost before selecting a transformation.
- Trace definitions, callers, and relevant history before declaring a boundary accidental.
- Distinguish divergent change from shotgun surgery; their structural directions are opposite.
- Load the selected catalog chapter for mechanics rather than treating this list as an editing recipe.
- Reassess after each small step; stop when the concrete comprehension or change obstacle is addressed.
