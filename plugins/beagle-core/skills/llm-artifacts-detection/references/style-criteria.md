# Style Criteria (language-neutral)

Detection criteria for verbose LLM-style patterns that reduce code clarity. Everything here applies in any language.

Worked BAD/GOOD examples live in a separate per-language file. Load [examples/python/style.md](examples/python/style.md) **only** when the code under review is Python. For any other language, apply the criteria below directly — substitute the local equivalents (docstring ≈ doc comment, `///`, `@doc`, JSDoc, or godoc block; type hint ≈ annotation, declared type, or explicit generic parameter).

Style findings are the highest false-positive category in this skill. Every criterion below carries a "before flagging" line — apply it.

## 1. Obvious Comments

**What to look for:** comments that restate what the code already says.

| Sub-pattern | Signal |
|---|---|
| Restating the operation | A comment that is a natural-language transcription of the line under it |
| Describing simple control flow | "check if X", "loop over Y", "handle the error case" |
| Doc comment repeating the name | A doc block whose entire content is the identifier respaced |
| Loop and block narration | A comment on every branch of a short, self-evident conditional |

**Before flagging:** comments carrying *why* rather than *what* are valuable even when they sit above obvious code. Legal notices, links to issues, references to a spec or RFC, and warnings about non-obvious ordering are not obvious comments.

## 2. Over-Documentation

**What to look for:** documentation weight disproportionate to the code it documents.

| Sub-pattern | Signal |
|---|---|
| Full doc block on a trivial accessor | Multi-section documentation on a one-line getter |
| Parameter docs for self-evident args | Every parameter documented as a restatement of its name |
| Return docs for self-evident returns | A return section that restates the declared return type |

**Before flagging:** in a **public API**, a library, or any codebase whose docs are generated from source, complete parameter and return documentation is the standard, not bloat. Restrict this criterion to internal, non-published surfaces — and check whether the project runs a docstring-coverage linter before recommending removal.

## 3. Defensive Overkill

**What to look for:** defensive code that cannot prevent a failure that can actually occur.

| Sub-pattern | Signal |
|---|---|
| Error handling around infallible code | try/catch/recover wrapping operations with no failure mode |
| Nullability check on a non-nullable value | A null/nil/None guard on something the type system already excludes |
| Type check after a declared type | A runtime type assertion on an already-typed parameter |
| Re-validating validated input | Manual validation of a value a schema or parser already guaranteed |

**Before flagging:** the guarantee must be real and enforced. A type annotation in a **gradually typed** language (Python, TypeScript with `any` at boundaries, unchecked casts) is documentation, not enforcement — a null check at a trust boundary that receives external input is correct defensive code, not overkill. Confirm the value is not crossing a deserialization, FFI, or network boundary before flagging.

## 4. Unnecessary Type Annotations

**What to look for:** annotations that add no information a reader lacks.

| Sub-pattern | Signal |
|---|---|
| Annotation on an obvious literal | An explicit type on an assignment from a literal of that type |
| Redundant annotation in clear context | An explicit type on a value returned by a well-known, precisely-typed call |
| Over-annotated locals | Every intermediate binding in a function body annotated |

**Where annotations DO add value:**

- Function parameters and return types.
- Type/struct/class fields.
- Bindings whose type is not obvious from the assignment.
- Collections where the element type matters.
- Optional and union types.

**Before flagging:** some languages and some project configurations *require* explicit annotations — a strict linter, an inference limitation, or a team convention enforced in CI. Check the project's linter configuration before recommending removal, and never flag an annotation that a build would fail without.

## Review Questions

1. Does this comment tell me something the code does not?
2. Is this surface public or documentation-generated, where full docs are the standard?
3. Can this error actually be raised, given real enforcement rather than an annotation?
4. Is this null check at a trust boundary receiving external input?
5. Would the project's linter or compiler fail without this annotation?
