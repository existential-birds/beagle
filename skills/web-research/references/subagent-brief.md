# Subagent Brief Template

The orchestrator builds one brief per subtopic, mechanically, from `plan.md`. Every subagent gets the same shape so a caller reading `plan.md` can predict what each subagent was told.

Fill the template verbatim — no paraphrasing, no interpretation drift. Subagents return one terse status line to the orchestrator; all findings land in the output file.

## Template

```
You are one of up to 3 parallel research subagents. Investigate a single subtopic and write findings to disk.

Subtopic: <subtopic name, copied from plan.md>
Research question: <main research_question, verbatim from plan.md>
What to establish:
- <bullet 1 from plan.md for this subtopic>
- <bullet 2 from plan.md for this subtopic>
- <...>
Budget: up to <N> web searches. Write exactly one findings file. Do not return findings inline.
Output path: <output_dir>/findings/<subtopic-slug>.md

Citation rules: every claim carries a `[^n]` footnote. Citations use URL + page title + verbatim excerpt; add retrieved_at and source_type only when the source naturally provides them. See references/citation-schema.md for the full shape.

Required frontmatter on the output file:
---
status: ok | empty | failed
subtopic: <subtopic name>
brief_hash: <hash of this brief, supplied by the orchestrator>
started_at: <ISO timestamp>
finished_at: <ISO timestamp>
reason: <one line — required when status is empty or failed, omit otherwise>
---

Partial-failure protocol: always write the output file, even if the subagent fails or finds nothing. Use status: failed with a one-line reason on tool errors or exhaustion. Use status: empty with a reason when the topic is legitimately unsearchable ("no public sources found for <specific claim>"). Never exit without writing the file — absence of the file is treated as a silent failure.

Return: a single status line in this exact shape, and nothing else:
<path-to-findings-file> <status>

Example: /abs/path/findings/pricing-models.md ok
```

## Orchestrator responsibilities

- **Build `<subtopic-slug>`** by the same rule as the research-question slug in SKILL.md (lowercase, punctuation stripped, whitespace to hyphens, truncated to 60 chars on a word boundary). Keep it stable across runs so `refresh: true` can match archived prior files.
- **Compute `brief_hash`** over the filled-in brief text before dispatch so the findings file's provenance is verifiable.
- **Verify every expected file exists** after all subagents return. Any missing file = silent failure per `failure-modes.md`.
- **Never merge findings into one file**. Synthesis happens later, in `report.md`.

## Subagent responsibilities

- **Write the output file even on failure.** Absence is treated as silent context exhaustion.
- **Do not reshape the subtopic or the research question.** If the brief is wrong, flag it in `reason` and return `status: failed` — do not silently pivot to a different question.
- **Cap the budget.** Stop at N searches. More searches without new signal means the subtopic is saturated; write what you have with `status: ok`.
- **No inline returns.** The only thing that crosses back to the orchestrator is the status line. All evidence lives in the findings file.
