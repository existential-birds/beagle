---
name: ensure-docs
description: Verify documentation coverage and generate missing docs interactively
disable-model-invocation: true
---

# Ensure Documentation Coverage

Verify documentation coverage across a codebase, report gaps, and generate missing docs. **If the agent supports subagents**, dispatch one verifier per detected language in parallel; **otherwise** run the same per-language verification sequentially — the output is identical either way.

Coverage has two complementary lenses, and a healthy project needs both:

1. **Symbol coverage** — are the functions, classes, and modules documented to the language's standard (docstrings, JSDoc, GoDoc)? This is the per-language verification below.
2. **Diataxis type balance** — does the *doc set as a whole* serve all four user needs: a Tutorial to learn, How-To guides for tasks, Reference for lookups, and Explanation for understanding? A codebase can have 100% docstring coverage and still have no way for a newcomer to get started. See the [Diataxis balance check](#diataxis-type-balance-check) below.

## Workflow

Complete steps in order. Do not advance until each step’s **Pass** is satisfied.

1. **Language detection** — Follow Phase 1 (language detection) in [`references/workflow.md`](references/workflow.md).
   - **Pass:** For each language you will verify, you have evidence of at least one matching source file (counts or command output); if none qualify, stop with a short “no applicable languages” message and do not run verifiers.

2. **Load standards** — Read the sections for your detected languages (language standards, verifier prompts, consolidation format) in the same reference file.
   - **Pass:** You can state which standard applies per language (e.g. Google docstrings, JSDoc, GoDoc) before verification begins.

3. **Verification** — Verify each qualifying language using the verifier prompts and JSON output shape in the reference (Phase 2). If the agent supports subagents, run one verifier per language in parallel; otherwise run them sequentially.
   - **Pass:** Each completed verification returns parseable JSON including `language`, `files_scanned`, and `findings` (array, possibly empty).

4. **Diataxis balance check** — Run the [Diataxis type balance check](#diataxis-type-balance-check) against the project's existing docs (e.g. a `docs/` tree, README, or wiki).
   - **Pass:** You can state, for each of the four types (Tutorial, How-To, Reference, Explanation), whether the project has at least one document serving that need, and you have noted any missing or thin type.

5. **Consolidated report** — Merge results per Phase 3 (summary table, severity grouping, detailed findings if requested). Include the Diataxis balance alongside symbol coverage.
   - **Pass:** The user sees the merged report (inline or written to an agreed path) — covering both symbol coverage and Diataxis type balance — before you claim the audit is done or propose fixes.

6. **Generation** — Only if `--report-only` is not set: offer choices per Phase 4; apply doc edits only after an explicit user choice to generate. For a missing Diataxis type, route generation through [draft-docs](../draft-docs/SKILL.md) for the relevant type rather than generating inline.
   - **Pass:** No documentation edits for gaps until the user selects an option that includes generation; if they decline or choose report-only behavior, end after the report.

7. **Post-edit verification** — After any generation, run or offer the linter commands in Phase 5 of the reference for languages you changed, when those tools exist in the repo.
   - **Pass:** Linter run completed with output captured, or `N/A` with a one-line reason (e.g. tool not configured); remaining issues are listed or cleared.

## Diataxis Type Balance Check

Survey the project's prose documentation (a `docs/` tree, README, wiki, or doc site) and classify what exists into the four [Diataxis](https://diataxis.fr/) types. Use the compass to classify — *action or cognition? acquisition or application?* — per [docs-style/references/diataxis-compass.md](../docs-style/references/diataxis-compass.md).

Report the balance as a table:

| Type | Present? | Notes |
|------|----------|-------|
| **Tutorial** (learning) | yes / no / thin | e.g. "No getting-started / first-project guide" |
| **How-To** (tasks) | yes / no / thin | e.g. "Several task guides under `docs/how-to/`" |
| **Reference** (lookup) | yes / no / thin | e.g. "API reference generated, but no CLI reference" |
| **Explanation** (understanding) | yes / no / thin | e.g. "No architecture / design-rationale docs" |

Flag, in priority order:

1. **A missing type** — the doc set serves none of that user need. The most common and most damaging gap is a missing **Tutorial**: a project can have exhaustive reference and still leave a newcomer with no way in.
2. **A thin type** — present but doesn't cover the project's major features or surfaces.
3. **Mixed documents** — a single page trying to be two types at once (e.g. reference tables embedded in a how-to). Recommend splitting via [improve-doc](../improve-doc/SKILL.md).

Do **not** propose generating empty skeletons for missing types. Following the Diataxis "work by improvement" principle, recommend the single highest-value document to add or fix next, and offer to draft it via [draft-docs](../draft-docs/SKILL.md).

## Notes

- Use `--report-only` to skip generation.
- Avoid test files unless they are test helpers.
- Keep report output aligned with the language-specific standards in the reference file.
- The Diataxis balance check is about the doc set as a whole; per-language symbol coverage and type balance are independent — report both.
