# Subagent Brief Template

The orchestrator builds one brief per slice, mechanically, from `plan.md`. Every subagent gets the same shape so a caller reading `plan.md` can predict what each subagent was told.

Fill the template verbatim — no paraphrasing, no interpretation drift. Subagents return one terse status line to the orchestrator; all findings land in the output file.

## Template

```
You are one of up to 3 parallel artifact-analysis subagents. Scan a single slice of paths and write findings to disk.

Slice: <slice name, copied from plan.md>
Intent: <intent string, verbatim from plan.md — or "generic salient extraction" if absent>
Paths to scan:
  - <path 1 from plan.md for this slice>
  - <path 2 from plan.md for this slice>
  - <...>

What to extract:
  - Key insights — structurally important observations, decisions, and themes
  - User / market context — users, customers, competition, market data
  - Technical context — platforms, constraints, integrations, dependencies
  - Ideas & decisions — tagged accepted / rejected / open (preserve rejected ideas with rationale)
  - Raw detail worth preserving — specific quotes, metrics, and data points
  - Gaps — what the corpus could not establish; empty/unreadable paths

  When intent is present, weight extraction toward what is relevant to that intent. When intent is absent, extract anything structurally important without an interpretive filter.

Skim strategy:
  - Sharded documents (folder with index.md plus multiple files): read index.md first, then only the sub-files the index points to as relevant.
  - Large documents (single file > ~2000 lines or > ~50 pages): read the TOC, executive summary, and section headings first; pull full content only from relevant sections. Record skimmed-vs-read status per file.
  - Short documents: read end-to-end.

Skip patterns: apply the default denylist from references/skip-patterns.md (sensitive, binary/media, vendor/build). Record every skipped path under the paths_skipped frontmatter field.

Output path: <output_dir>/findings/<slice-slug>.md

Citation rules: every claim carries a [^n] footnote. Citations use source path (relative to the scanned root when possible) + verbatim excerpt. Include lines and heading only when the subagent naturally has them; never synthesized or guessed. See references/citation-schema.md for the full shape.

Required frontmatter on the output file:
---
status: ok | empty | failed
slice: <slice name>
brief_hash: <hash of this brief, supplied by the orchestrator>
started_at: <ISO timestamp>
finished_at: <ISO timestamp>
paths_read: [<paths read end-to-end>]
paths_skimmed: [<paths where only TOC/index/headings were consumed>]
paths_skipped: [<paths skipped via the default denylist>]
reason: <one line — required when status is empty or failed, omit otherwise>
---

Partial-failure protocol: always write the output file, even if the subagent fails or finds nothing. Use status: failed with a one-line reason on tool errors or exhaustion. Use status: empty with a reason when the slice is legitimately empty ("all paths under this slice were under the skip denylist" or "all files were unreadable"). Never exit without writing the file — absence of the file is treated as a silent failure.

Return: a single status line in this exact shape, and nothing else:
<path-to-findings-file> <status>

Example: /abs/path/findings/planning-folder.md ok
```

## Orchestrator responsibilities

- **Build `<slice-slug>`** by the same rule as the run slug in SKILL.md (lowercase, punctuation stripped, whitespace → hyphens, truncated to 60 chars on a word boundary). Keep it stable across runs so `refresh: true` can match archived prior files.
- **Compute `brief_hash`** over the filled-in brief text before dispatch so the findings file's provenance is verifiable.
- **Guarantee non-overlapping slices.** The orchestrator partitions resolved paths before building briefs; no path appears in more than one slice.
- **Verify every expected file exists** after all subagents return. Any missing file = silent failure per `failure-modes.md`.
- **Never merge findings into one file.** Synthesis happens later, in `report.md`.

## Subagent responsibilities

- **Write the output file even on failure.** Absence is treated as silent context exhaustion.
- **Do not reshape the intent or the slice.** If the brief is wrong, flag it in `reason` and return `status: failed` — do not silently pivot to a different scope.
- **Apply skim strategies.** Do not read a 2000-line file end-to-end when the TOC tells you only three sections are relevant. Record the skim/read decision in the frontmatter path lists.
- **Apply skip patterns silently.** Every skipped path goes in `paths_skipped` — no need to note it in the findings body.
- **No inline returns.** The only thing that crosses back to the orchestrator is the status line. All evidence lives in the findings file.
