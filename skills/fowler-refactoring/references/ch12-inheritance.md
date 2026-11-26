# Chapter 12 — Dealing with Inheritance

Source: Fowler, Second Edition, Chapter 12, PDF pp. 389–453.
Judge both implementation reuse and substitutability; inheritance and delegation have different costs.

## Pull Up Method — pp. 389–392

- Inverse: Push Down Method.
- Use for equivalent subclass behavior that belongs on their common abstraction.
- Compare implementations semantically; investigate differences rather than assuming duplication.
- Refactor equivalent bodies and signatures into matching forms before moving them.
- Ensure the superclass can access every required field and operation.
- Create the common implementation on the superclass and run static checks.
- Remove one subclass implementation and test, then repeat.
- If only the overall flow matches, extract common steps or consider a template structure rather than erasing real variation.

## Pull Up Field — pp. 393–394

- Inverse: Push Down Field.
- Verify that subclass fields have the same meaning and usage, not merely the same name.
- Align their names before introducing common storage on the superclass.
- Give subclasses the access required by the language without exposing unnecessary public state.
- Remove duplicate subclass declarations and test.
- In languages with assignment-created fields, the practical move may be Pull Up Constructor Body.

## Pull Up Constructor Body — pp. 394–398

- Use for equivalent initialization shared by subclasses.
- Establish a superclass constructor and ensure subclasses invoke it correctly.
- Slide common initialization to a movable position, respecting language rules around superclass construction.
- Move common statements into the superclass and pass the values they require.
- Test initialized state and constructor failures for every affected variant.
- Common logic that cannot move to the beginning may be extracted into a shared method instead.
- If initialization sequencing becomes too tangled, consider Replace Constructor with Factory Function.
- Calling overridable behavior during construction requires attention to which subclass state already exists.

## Push Down Method — pp. 399–400

- Inverse: Pull Up Method.
- Use when behavior is meaningful only for specific subtypes.
- Copy the method to the subclasses that need it, then remove it from the superclass and test.
- Remove any redundant copies on subclasses that do not need it and test again.
- Callers must know they have a supporting subtype.
- If clients need a uniform superclass protocol, preserve it through suitable polymorphic behavior rather than breaking the contract.

## Push Down Field — pp. 400–401

- Inverse: Pull Up Field.
- Use for state required only by particular subclasses.
- Declare the state where needed and adjust its initialization and accesses.
- Remove common storage and test all affected variants.
- Remove any unnecessary subclass copies.
- Confirm no inherited method still assumes every instance has that field.

## Replace Type Code with Subclasses — pp. 401–408

- Includes the older Extract Subclass and Replace Type Code with State/Strategy ideas; inverse: Remove Subclass.
- Use when classifications drive repeated behavior differences or subtype-specific fields.
- A simple type code is often sufficient; classification alone does not justify a hierarchy.
- Encapsulate access to the code before changing its representation.
- Create one subtype overriding the type getter with its corresponding literal value.
- Add selection logic in a factory for direct inheritance, or in the appropriate owner for indirect inheritance.
- Test and repeat for each existing classification.
- Remove redundant type storage after the subtype representation supplies the value.
- Then move appropriate behavior down or apply Replace Conditional with Polymorphism.
- Remove type accessors only when no legitimate consumer remains.
- Direct subtyping fits a stable classification when the inheritance axis is available.
- For mutable classification or another existing inheritance axis, wrap the type as an object and subtype that component instead.

## Remove Subclass — pp. 409–415

- Formerly Replace Subclass with Fields; inverse: Replace Type Code with Subclasses.
- Use when subclasses no longer carry meaningful behavioral or structural differences.
- Encapsulate subclass construction behind a factory.
- Move explicit subtype tests behind superclass operations before removing the types they inspect.
- Introduce a field representing the residual distinction.
- Migrate behavior to that field, then remove the unnecessary subclass and test.
- For several subclasses, first centralize construction and type tests, then fold each subclass independently.
- Do not replace useful variant behavior with sprawling repeated switches merely to reduce class count.

## Extract Superclass — pp. 416–421

- Use when existing classes reveal coherent shared behavior and data.
- Introduce an empty superclass and make the original classes inherit it.
- Adapt construction if needed and test before moving features.
- Pull up common initialization, fields, and methods one at a time.
- Extract common fragments from remaining methods where they have genuine shared meaning.
- Consider whether clients should depend on the new common interface.
- Alternative: Extract Class and delegate to a component when shared implementation is not a valid subtype relationship.
- Discovery during development is legitimate; inheritance need not have been planned in advance.

## Collapse Hierarchy — pp. 422–423

- Use when a class and its immediate parent no longer differ enough to justify both.
- Choose the surviving responsibility and name.
- Move fields and methods up or down into that survivor using the corresponding small refactorings.
- Redirect references from the removed class to the survivor.
- Delete the empty class and test.
- Check construction, runtime type checks, and external type contracts in addition to method calls.

## Replace Subclass with Delegate — pp. 423–446

- Use for multiple variation axes, runtime-varying roles, or excessive subclass/superclass coupling.
- Centralize construction in factories if many clients directly instantiate variants.
- Introduce a delegate class receiving subtype-specific data and, when needed, a reference to its host.
- Add a delegate field to the host and initialize it in the appropriate construction path.
- Move one subclass method to the delegate while retaining forwarding behavior.
- Move subtype-owned state with it; access retained host state through an explicit relationship.
- Move required public dispatch to the host, with a delegate-presence guard where absence is valid.
- Test each method migration, then move the remaining subtype behavior.
- If several delegates share behavior, a delegate hierarchy can provide a default instead of repeated guards.
- Update construction to return the host with its appropriate delegate, then delete the emptied subclass.

### Important worked-example hazards — pp. 429–435

- A former `super` call must not call the host dispatcher that delegates straight back, creating recursion.
- Extract a non-dispatching base calculation or pass its result to a delegate extension operation.
- Preserve missing-member behavior rather than inventing a new error or default during the move.
- A host back-reference makes previously implicit dependencies explicit but creates additional coupling to manage.
- Delegation can be more code than inheritance; choose it for the required flexibility, not as automatic improvement.
- The single-axis limitation discussed in the example applies to its inheritance model; check the actual language's facilities.

## Replace Superclass with Delegate — pp. 447–453

- Formerly Replace Inheritance with Delegation.
- Use when the superclass's public operations do not make sense on the subtype or the subtype is not substitutable.
- Add a field referring to a separate superclass instance and initialize it.
- Add forwarders for the inherited behavior the host must preserve.
- Test each consistent group, treating coupled getter/setter behavior together when required.
- Remove the inheritance link after inherited dependencies are accounted for.
- Explicitly review consumers relying on runtime type membership or the former superclass interface.
- A stack reusing list storage need not expose every list operation.
- Distinguish a kind of thing from one physical instance of it; their identifiers and lifecycles may differ.
- The scroll example separates a physical scroll's ID from its catalog item's ID before sharing catalog data.
- Changing a private component into a canonical shared reference is a separate Change Value to Reference step.
- Preserve distinct identities and obtain shared entities from the correct repository rather than conflating their keys.

## Hierarchy review questions

- Is every inherited operation meaningful, and can the subtype safely stand in for the supertype?
- Are shared fields genuinely the same concept across all variants?
- Does variation need to change while object identity remains stable?
- Would a second independent variation axis make subtype combinations unwieldy?
- Do constructor order, base calls, and delegate dispatch remain correct after the move?
