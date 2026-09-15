# Chapter 7 — Encapsulation

Source: Fowler, Second Edition, Chapter 7, PDF pp. 183–223.
Core question: which representation or relationship should callers not need to know?

## Encapsulate Record — pp. 183–193

- Formerly Replace Record with Data Class.
- Use for mutable records whose representation and update paths are leaking into clients.
- First encapsulate the variable holding the record behind easily located access functions.
- Wrap the raw record in a class while temporarily retaining a raw-data accessor for compatibility.
- Add a separate access path returning the wrapper object.
- Migrate clients to object accessors one at a time, creating field operations as required and testing each move.
- For nested records, migrate mutating clients first; consider copies or read-only views for readers.
- Remove the raw-record escape hatches after consumers have migrated.
- Recursively encapsulate nested records or collections only as far as protection requires.
- Stored versus derived fields can then change without exposing the representation to clients.
- Do not mistake a wrapper returning its raw mutable internals for complete encapsulation.
- Effectively immutable result records may not need this machinery.

## Encapsulate Collection — pp. 194–198

- Use when callers can change membership through a getter, bypassing its owner.
- Encapsulate the collection binding and provide explicit add/remove operations.
- Remove a whole-collection setter if possible; otherwise copy incoming membership to avoid outside aliases.
- Migrate external collection modifiers to the owner's operations, testing each caller.
- Change the getter to return a protected view or copy and test the chosen contract.
- A read-only proxy can reflect later changes to the original collection.
- A copy is a snapshot of membership and does not reflect subsequent source additions/removals.
- Choose a consistent convention across the codebase so callers know what they receive.
- Protecting membership does not make each element immutable.
- Do not replace every useful collection operation with a bespoke forwarding method.
- Measure copying costs for large collections rather than assuming either zero cost or unacceptable cost.

## Replace Primitive with Object — pp. 199–203

- Formerly Replace Data Value with Object or Replace Type Code with Class.
- Use when a primitive accumulates domain-specific formatting, validation, comparison, or behavior.
- Encapsulate the original value first.
- Introduce a small class constructed from that value and able to return the original representation.
- Change the enclosing setter to construct the wrapper and the getter to preserve the former outward value.
- Run static checks and behavior tests before changing clients to a richer API.
- Rename accessors when their actual roles need clarification.
- Move duplicated domain operations into the new concept as follow-up small steps.
- Decide explicitly whether the object has value semantics or shared identity.
- A thin wrapper is a stepping stone, not justification for creating a type with no domain benefit.

## Replace Temp with Query — pp. 204–207

- Use when a derived temporary obstructs extraction or repeats the same calculation in several functions.
- Check that the value is fully determined before use and recalculation at each use gives the same result.
- Make the binding read-only if possible and test.
- Extract its complete calculation into a query, using a temporary function name if needed.
- Remove side effects from the query, using Separate Query from Modifier where required.
- Test, then Inline Variable to replace temporary reads with the query.
- Several assignments can be part of one complete initial calculation; extract them together.
- A snapshot such as an old address must not become a query for the current address.
- Shared class context often makes this useful; a large new parameter list can erase the benefit.
- Nested functions can help scope but restrict reuse outside their enclosing operation.

## Extract Class — pp. 208–211

- Inverse: Inline Class.
- Use when a subset of fields and methods forms a coherent separate responsibility.
- Determine the split from dependencies, change patterns, and client usage rather than class size alone.
- Create the new component and connect an instance of it from the original object.
- Move fields individually, testing after each move.
- Move methods from lower-level dependencies upward, testing after each move.
- Review both interfaces and rename the remaining original responsibility if needed.
- Decide whether clients should see the component or only the original object's delegation.
- Consider value semantics for an exposed component where identity is not needed.
- The book's parent/child wording here describes composition, not a required subclass relationship.

## Inline Class — pp. 212–215

- Inverse: Extract Class.
- Use when a class no longer contributes enough responsibility, or before choosing a better split.
- Add forwarding operations on the destination for the source class's public behavior.
- Redirect clients to those destination operations incrementally and test.
- Move source functions and data into the destination one at a time.
- Remove the source only after no required behavior or consumer remains there.
- A temporarily larger class can be a legitimate intermediate state before re-extraction.
- Preserve object identity and lifecycle requirements when consolidating instances.

## Hide Delegate — pp. 216–218

- Inverse: Remove Middle Man.
- Use when clients unnecessarily depend on an intermediate object's structure to reach behavior.
- Introduce a forwarding operation on the server object for the required delegate behavior.
- Migrate the client to the server and test; repeat for relevant operations.
- Remove direct delegate access only when no client requires it.
- The benefit is confining future delegate-interface changes to one boundary.
- Hide useful secrets rather than mechanically forbidding every chained call.

## Remove Middle Man — pp. 219–220

- Inverse: Hide Delegate.
- Use when maintaining numerous trivial forwarding methods costs more than the hiding is worth.
- Expose the delegate through an accessor.
- Replace one forwarding-method use with a call through that accessor and test.
- Delete each forwarding operation only when its callers have migrated.
- The right degree of hiding can change with requirements; reversing an earlier choice is legitimate.
- Confirm that exposing the delegate does not bypass a real policy, validation, or compatibility boundary.

## Substitute Algorithm — pp. 221–223

- Use when an alternative implementation is simpler, better supported, or makes an intended change easier.
- Isolate the existing algorithm behind a complete function before replacing it.
- Establish tests against that function's behavior.
- Prepare the alternative and run static checks.
- Compare old and new behavior under the tests; use disagreements to guide diagnosis.
- Keep the old implementation as a comparison aid while investigating, not as a permanent duplicate by default.
- Simplify a large tangled function before attempting wholesale algorithm substitution.
- A matching happy-path result does not establish equivalent errors, ordering, mutations, or boundary behavior.

## Boundary audit

- Does any constructor, setter, or getter leak a mutable alias?
- Is a returned collection a live view or a snapshot, and do clients depend on the distinction?
- Is the value stored, derived, or deliberately captured at an earlier time?
- Does a delegation layer hide a genuine secret or merely add maintenance work?
- Can the same tests verify the boundary before and after its representation changes?
