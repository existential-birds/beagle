# Synthesis Skeleton

The synthesis document, saved as `report.md` under the run's output directory, uses a fixed four-section layout. Sections appear in this order, every time, even when one is short. `Gaps & Limitations` is required even when findings look complete — honest accounting of what could not be established is part of the product.

Copy the skeleton below into the synthesis file and fill each section.

## Layout

```markdown
# Research: <research question, verbatim from plan.md>

## TL;DR

- <3 to 5 bullets, highest-signal findings first>
- <each bullet stands alone — a reader should grasp the answer without scrolling further>
- <cite with [^n] when a bullet makes a specific factual claim>

## Findings

### <Subtopic or theme 1>

<Paragraphs or bullets. Every factual claim carries a [^n] footnote. Group claims by subtopic or by theme that cuts across subtopics — choose whichever reads better for this question.>

### <Subtopic or theme 2>

<...>

### <Subtopic or theme N>

<...>

## Gaps & Limitations

- <What the research could not establish, and why. One bullet per gap.>
- <Any subagent that failed or returned empty — name the subtopic and the reason from its stub file.>
- <Claims that required a freshness check (retrieval date) but were not time-stamped.>
- <Questions that surfaced during research but were out of scope for this run.>

## Sources

[^1]: **Title**: <page title>
      **URL**: <url>
      **Excerpt**: "<verbatim quote>"
      **Retrieved**: <YYYY-MM-DD, omit if absent>
      **Source type**: <official-docs | vendor | blog | forum | news | other, omit if absent>

[^2]: **Title**: <...>
      **URL**: <...>
      **Excerpt**: "<...>"

[^n]: <...>
```

## Rules

- **Title line** reproduces the research question verbatim from `plan.md`. Do not paraphrase.
- **`TL;DR`** is 3-5 bullets. Not 1, not 10. If only one thing is worth saying, the research is thin — flag it in `Gaps & Limitations`.
- **`Findings`** groups by subtopic by default. If a cross-cutting theme reads better, use that instead, but keep every claim footnoted. Structure serves the reader.
- **`Gaps & Limitations`** is never empty. At minimum, include what future work would sharpen the answer. When subagents fail, each failed subtopic gets its own bullet with the subtopic name and the reason from its stub file (see `failure-modes.md`).
- **`Sources`** uses global numbering — `[^1]` through `[^n]` across the whole document, not per-section. Citation shape per `citation-schema.md`.

## Sourcing discipline

- Every bullet in `TL;DR` that makes a specific factual claim carries a footnote. Broad synthesis statements ("the market is split between two approaches") can stand without a footnote if they summarize cited claims in `Findings`.
- Inside `Findings`, no unsourced claims. If a claim cannot be cited, either drop it or move it to `Gaps & Limitations` as something the research could not establish.
- `Sources` entries match every `[^n]` used in `TL;DR` and `Findings`. Orphan citations (listed in `Sources` but never referenced) should be removed.
