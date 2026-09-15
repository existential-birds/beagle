---
name: fowler-refactoring
description: Use when refactoring code with behavior-preserving steps.
user-invocable: false
---

# Fowler Refactoring

Apply the decision rules and small-step transformations in Martin Fowler's *Refactoring: Improving the Design of Existing Code*, Second Edition, with contributions by Kent Beck (2019). This is a knowledge base for improving existing code, not permission to rewrite a system or alter its behavior; it needs no package, credential, or original PDF at runtime.

## When to Use

- "Refactor this without changing behavior."
- "Which refactoring fits this code smell?"
- "Separate calculation from presentation."
- "Improve these functions, data structures, APIs, or classes."
- "Explain Fowler's refactoring mechanics and tradeoffs."

## Prerequisites

- For code changes: access to the relevant repository, its instructions, and its existing test/build tooling.
- Establish a passing baseline and tests for the behavior at risk; do not invent a project test command.
- No environment variables, credentials, MCP server, or additional dependencies for these notes.

## How to Run

Read this file, then load the relevant chapter by reading its relative path (for example `references/ch01-first-example.md`).
For implementation, inspect definitions and callers with `search_files` and `read_file`, edit with `patch` or `write_file`, and invoke the repository's verified test command through `terminal` after each small transformation.
The chapter files are on-demand detail, not mandatory bulk reading.
Tool names (`terminal`, `read_file`, `search_files`, `patch`, `write_file`) denote capabilities — shell execution, file reading, content search, scoped edits, and file writing — and map to the host agent's native equivalents; they are not a required product.

## Quick Reference

- `references/ch01-first-example.md` — load the relevant chapter by relative path.
- `search_files` — definitions, callers, state writes, and existing tests.
- `read_file` — repository instructions, implementation, and test configuration.
- `patch` / `write_file` — scoped implementation and test edits.
- `terminal` — established tests, builds, type checks, and diff inspection.

## Procedure

1. Identify the actual next change or comprehension obstacle. Improve changeability, not aesthetics or line count.
2. Inspect observable behavior, dependencies, mutation, error paths, and callers; establish a self-checking test baseline.
3. Choose a small named transformation and load its chapter mechanics before editing.
4. Separate structural work from feature work. Preserve behavior during the refactoring step.
5. Make one small change, run the relevant checks through `terminal`, and inspect the result. If it fails, repair or undo only that change; reduce the step size.
6. Use temporary adapters or delegation when a move cannot be atomic; remove obsolete paths only when consumers have migrated.
7. Stop when the intended change is easier and the scoped obstacle is removed. Add the new behavior in a separate, tested step if requested.
8. Report changed locations, the reason for the transformation, actual check results, and remaining uncertainty. Do not commit, push, or change public contracts without authorization.

### Central decision rules

- Prefer short, reversible transformations over a long broken intermediate state.
- Use names to store understanding; extraction pays for itself when intention becomes clearer, even without reuse.
- Structure follows the expected axis of change: separate independent concerns; group behavior and data that change together.
- Inverse refactorings are legitimate choices, not contradictions. Judge the target context, not an abstract preference for more objects or fewer functions.
- Treat smells as investigation prompts, not proof of a defect or a numerical cleanup quota.
- Keep externally observable results, side effects, errors, ordering, and contracts stable; repository-specific constraints take precedence over book-era examples.
- Prefer measured performance evidence to intuition. Preserve explicit latency, memory, and concurrency requirements while changing structure.
- Fowler's private-commit rhythm illustrates recovery checkpoints; it does not authorize Git writes in the user's repository.

### Chapter index

Load only the relevant file by reading its relative path (for example `references/ch01-first-example.md`); every file below is part of this skill.

- [Chapter 1: First example](references/ch01-first-example.md) — load for a complete decomposition, phase separation, and polymorphism sequence.
- [Chapter 2: Principles](references/ch02-principles.md) — load for scope, timing, legacy code, published interfaces, migrations, architecture, and performance.
- [Chapter 3: Code smells](references/ch03-code-smells.md) — load to diagnose a concrete change obstacle and select candidate transformations.
- [Chapter 4: Building tests](references/ch04-building-tests.md) — load for self-checking baselines, isolated fixtures, boundary probes, and regression tests.
- [Chapter 5: Using the catalog](references/ch05-using-the-catalog.md) — load to interpret mechanics, examples, inverse moves, and their limits.
- [Chapter 6: First refactorings](references/ch06-first-refactorings.md) — load for extraction, inlining, names, signatures, parameter objects, classes, transforms, and phases.
- [Chapter 7: Encapsulation](references/ch07-encapsulation.md) — load for records, collections, domain values, class boundaries, delegation, and algorithm replacement.
- [Chapter 8: Moving features](references/ch08-moving-features.md) — load for moving functions, fields, and statements; loops; and verified dead-code removal.
- [Chapter 9: Organizing data](references/ch09-organizing-data.md) — load for variable roles, derived state, field names, value semantics, and shared identity.
- [Chapter 10: Conditional logic](references/ch10-conditional-logic.md) — load for predicates, guards, polymorphism, special cases, and assertions.
- [Chapter 11: Refactoring APIs](references/ch11-refactoring-apis.md) — load for query/modifier separation, parameter tradeoffs, flags, setters, factories, and commands.
- [Chapter 12: Inheritance](references/ch12-inheritance.md) — load for pulling/pushing features, type codes, hierarchy changes, and delegation migrations.
- [Decision guide](references/decision-guide.md) — load to compare inverse moves, select boundaries, or compose a multi-step refactoring.
- [Glossary and source map](references/glossary.md) — load for definitions, older catalog names, edition details, and PDF chapter locations.

## Pitfalls

- A passing test suite reduces risk; it is not proof that all behavior is unchanged.
- Moving or repeating an expression can change mutation, exception timing, I/O, identity, or evaluation count.
- A shallow copy does not isolate nested mutable data.
- Public APIs, persisted field names, and serialization formats need an explicit compatibility plan.
- Book examples use JavaScript; check the actual language's binding, dispatch, equality, and initialization rules.
- Do not treat every conditional as a demand for inheritance, or every temporary variable as harmful.
- Source provenance uses this PDF's 1-based page positions, not the printed-page numbers embedded in catalog cross-references.

## Verification

One completion check: confirm that the repository's established behavior checks pass after the final transformation and that the scoped diff contains no unapproved behavior or contract changes; report the exact command and result, or explicitly mark unverified work.
