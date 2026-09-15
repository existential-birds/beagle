# Glossary, Aliases, and Source Map

Source: Martin Fowler, *Refactoring: Improving the Design of Existing Code*, Second Edition,
with contributions by Kent Beck; copyright 2019; ISBN-13 9780134757599.
Input supplied as `fowler_refactoring.pdf`; these are original synthesized notes, not copied book text.

## Page convention and coverage

- Page citations are 1-based positions in the supplied PDF.
- Do not substitute the printed-page numbers found in the book's internal catalog references.
- The supplied PDF contains 455 pages and 12 chapter bookmarks.
- PDF page 1 is the cover; pages 2–4 are title/copyright material.
- PDF pages 454–455 are promotional/registration back matter, not additional chapters.
- Chapters 1–5 provide the example, principles, smells, tests, and catalog conventions.
- Chapters 6–12 contain the named transformation catalog.
- Notes prioritize motivations, decision rules, mechanics, hazards, and selected worked-example lessons.
- Complete code listings, decorative graphics, historical anecdotes, and marketing pages are not reproduced.
- Additional repository, concurrency, and compatibility cautions are application guidance, not verbatim source claims.

| Chapter | Subject | PDF pages | Reference |
|---|---|---|---|
| 1 | First example | 5–55 | ch01-first-example.md |
| 2 | Principles | 56–84 | ch02-principles.md |
| 3 | Code smells | 85–99 | ch03-code-smells.md |
| 4 | Building tests | 100–117 | ch04-building-tests.md |
| 5 | Using the catalog | 118–120 | ch05-using-the-catalog.md |
| 6 | First refactorings | 121–182 | ch06-first-refactorings.md |
| 7 | Encapsulation | 183–223 | ch07-encapsulation.md |
| 8 | Moving features | 224–267 | ch08-moving-features.md |
| 9 | Organizing data | 268–288 | ch09-organizing-data.md |
| 10 | Conditional logic | 289–341 | ch10-conditional-logic.md |
| 11 | APIs | 342–388 | ch11-refactoring-apis.md |
| 12 | Inheritance | 389–453 | ch12-inheritance.md |

## Core terms

- **Refactoring:** an internal behavior-preserving structural change, or the activity of composing such changes. [Ch. 2]
- **Restructuring:** broader reorganization that need not use refactoring's small safe steps. [Ch. 2]
- **Observable behavior:** externally relevant results and effects under the actual supported contract. [Ch. 2]
- **Two hats:** distinguish adding/changing functionality from preserving it while improving structure. [Ch. 2]
- **Design Stamina Hypothesis:** better internal design sustains delivery speed; presented as a hypothesis, not a measured universal curve. [Ch. 2]
- **Preparatory refactoring:** first make the intended change easier, then perform it. [Ch. 2]
- **Comprehension refactoring:** encode newly understood intent into names and structure. [Ch. 2]
- **Litter-pickup refactoring:** small opportunistic improvements in code being visited. [Ch. 2]
- **Rule of three:** repeated use can supply evidence for an abstraction; a heuristic, not a mandatory duplication count. [Ch. 2]
- **YAGNI:** avoid speculative complexity while preserving the ability to evolve a clear current design. [Ch. 2]
- **Branch By Abstraction:** migrate behind a boundary supporting old and new implementations. [Ch. 2]
- **Parallel change / expand-contract:** introduce a replacement, migrate consumers, then retire the original. [Ch. 2]
- **Published interface:** an interface consumed outside the producer's control over coordinated edits. [Ch. 2]
- **Self-testing code:** automatically executed checks judge their own results. [Ch. 4]
- **Fixture:** known data and objects on which a test operates; mutable fixtures should normally be fresh per test. [Ch. 4]
- **Characterization:** recording current behavior to detect later change, without proving that behavior is correct; descriptive application terminology. [Ch. 4]
- **Code smell:** contextual indication of a possible design problem, not a mechanically proven defect. [Ch. 3]
- **Divergent change:** one module changes for multiple unrelated reasons. [Ch. 3]
- **Shotgun surgery:** one conceptual change requires edits across many modules. [Ch. 3]
- **Feature envy:** a function's dependencies suggest it belongs closer to another module's data. [Ch. 3]
- **Data clump:** related values recur together and suggest a missing concept. [Ch. 3]
- **Encapsulation:** hide a representation or relationship behind a controlled interface. [Ch. 7]
- **Query:** operation without observable modification; distinguish pure calculation from time-varying reads. [Ch. 7, 11]
- **Modifier / mutator:** operation that changes observable state. [Ch. 11]
- **Referential transparency:** equal argument values yield equivalent behavior, enabling substitution and simpler reasoning. [Ch. 11]
- **Value object:** immutable contents define equality; replace the whole value rather than mutate its identity. [Ch. 9]
- **Reference object:** a shared entity whose identity and visible updates matter to collaborators. [Ch. 9]
- **Repository:** an access point for canonical instances when shared identity is required. [Ch. 9]
- **Transform:** computation produces a derived output record from source data. [Ch. 6]
- **Intermediate data:** an explicit contract between sequential phases. [Ch. 1, 6]
- **Guard clause:** early handling of an exceptional path that leaves the main path prominent. [Ch. 10]
- **Special case:** an object or record encapsulating shared behavior for a distinguished input; Null Object is one instance. [Ch. 10]
- **Assertion:** executable statement of a necessary internal assumption, not normal external-input validation. [Ch. 10]
- **Command object:** an object representing an operation and its execution context; not necessarily a state modifier. [Ch. 11]
- **Type-instance homonym:** confusing a kind/catalog description with a physical individual of that kind. [Ch. 12]
- **Delegation:** one object explicitly forwards behavior to a collaborator instead of inheriting it. [Ch. 7, 12]

## Catalog alias lookup

| Older or alternative term | Name used in these notes | Chapter |
|---|---|---|
| Extract Method / Inline Method | Extract Function / Inline Function | 6 |
| Introduce Explaining Variable | Extract Variable | 6 |
| Inline Temp | Inline Variable | 6 |
| Rename Method / Add Parameter / Remove Parameter / Change Signature | Change Function Declaration | 6 |
| Encapsulate Field / Self-Encapsulate Field | Encapsulate Variable | 6 |
| Replace Record with Data Class | Encapsulate Record | 7 |
| Replace Data Value with Object / Replace Type Code with Class | Replace Primitive with Object | 7 |
| Move Method | Move Function | 8 |
| Consolidate Duplicate Conditional Fragments | Slide Statements | 8 |
| Split Temp / Remove Assignments to Parameters | Split Variable | 9 |
| Introduce Null Object | Introduce Special Case | 10 |
| Parameterize Method | Parameterize Function | 11 |
| Replace Parameter with Explicit Methods | Remove Flag Argument | 11 |
| Replace Parameter with Method | Replace Parameter with Query | 11 |
| Replace Constructor with Factory Method | Replace Constructor with Factory Function | 11 |
| Replace Method with Method Object | Replace Function with Command | 11 |
| Replace Subclass with Fields | Remove Subclass | 12 |
| Replace Inheritance with Delegation | Replace Superclass with Delegate | 12 |

## Terminology cautions

- Chapter 12's Replace Type Code with Subclasses subsumes older State/Strategy and Extract Subclass techniques rather than being a one-to-one rename of each.
- Chapter 7's extracted parent/component relationship is composition; the word child there does not require inheritance.
- A constructor wrapper is a factory even before it starts choosing among implementations.
- A data-only object is not automatically deficient when it is an immutable result between phases.
