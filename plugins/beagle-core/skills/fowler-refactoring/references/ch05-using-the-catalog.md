# Chapter 5 — Introducing the Catalog

Source: Fowler, Second Edition, Chapter 5, PDF pp. 118–120.
This short chapter defines how to use the catalog; it does not introduce a new transformation.

## Entry structure

| Part | Purpose | How to use it |
|---|---|---|
| Name and aliases | Shared vocabulary | Identify the exact move, including older terminology |
| Sketch | Recognition aid | Recall a transformation already understood |
| Motivation | Reasons and counterconditions | Decide whether the destination helps this code |
| Mechanics | Ordered safe steps | Execute and check each small state transition |
| Examples | Explanation in context | Understand why mechanics are arranged that way |

- A before/after sketch is not a sufficient safety recipe.
- The mechanics are terse because the examples explain the reasoning and edge cases.
- Read the motivation before choosing a move, not just after deciding to apply it.
- Use the mechanics as a checklist when a transformation is unfamiliar or infrequently used.
- In these distilled notes, each catalog entry combines motive, sequence, and hazards.

## Step size and adaptation

1. Begin with a working, tested baseline.
2. Choose a named transformation and check its preconditions in the actual language.
3. Read special cases before editing.
4. Make the smallest useful step and test it.
5. If a larger step fails, undo that step and retry with smaller ones.
6. Adapt the mechanics only when the alternative preserves the same safety properties.

- The published mechanics are a useful route, not the only possible route.
- Experience can permit larger steps; difficulty is a reason to shrink them again.
- Automation may combine mechanics, but its binding and semantic assumptions still matter.
- The destination can be reached through several compositions of simpler refactorings.

## Limits of the examples

- Examples minimize distracting complexity rather than model ideal business domains.
- A completed example may intentionally retain other smells outside the named transformation.
- Do not reproduce its residual weaknesses as recommended architecture.
- Do not expand a scoped refactoring merely because further improvements are imaginable.
- Some simple transformations do not need a worked example.
- Colored code changes are reading aids, not an exhaustive diff or formal proof.
- JavaScript examples need translation to the project's real semantics and test tools.

## Catalog completeness and inverses

- The catalog is selected, not exhaustive.
- Entries were chosen for frequency, instructive mechanics, or significant design impact.
- A useful unnamed small move can still be a refactoring.
- Every move has a logical inverse; not every inverse earns a separate catalog entry.
- An omitted inverse is not necessarily unsafe, and a listed inverse is not necessarily preferable.
- Prefer a direction because it improves the current context, not because it appears in a book.
- Extract versus inline, value versus reference, and parameter versus query are contextual pairs.

## Practical reading sequence

- For a smell: load Chapter 3, then the chapter containing the candidate move.
- For an unfamiliar mechanic: consult its full motive and hazards before applying it.
- For a multi-step redesign: plan a chain of named transformations with passing intermediate states.
- For a disputed direction: describe the dependency, variation, or ownership tradeoff being changed.
- For an unrepresented case: reason explicitly from behavior preservation rather than inventing a Fowler attribution.

## Citation and provenance convention

- References in this skill name source chapter and 1-based PDF pages.
- The PDF includes preliminary pages; printed catalog-page references use a different numbering sequence.
- Refactoring names remain recognizable; explanations are original structured synthesis.
- Repository-specific safety guidance is application advice, not a claim that the book contains a particular CLI workflow.
- Load another reference on demand with the agent's file reader; no original PDF is required for routine use.
