# Synthesis Skeleton

The synthesis document, saved as `report.md` under the run's output directory, uses a fixed seven-section layout. Sections appear in this order, every time, even when one is short. `Gaps & Limitations` is required even when findings look complete — honest accounting of what could not be established is part of the product.

Copy the skeleton below into the synthesis file and fill each section.

## Layout

```markdown
# Analysis: <intent, verbatim from plan.md — or "Generic extraction of <slug>" when intent is absent>

## Documents Found

- `<relative path 1>` — <one-line note on what this document covers and why it was included>
- `<relative path 2>` — <...>
- `<relative path N>` — <...>

Include every path that was actually scanned (end-to-end or skimmed). Paths that were under the skip denylist go in `Gaps & Limitations`, not here.

## Key Insights

Group by theme. Every claim carries a [^n] footnote.

### <Theme 1>

<Bullets or short paragraphs. Each factual claim has a footnote.>

### <Theme 2>

<...>

### <Theme N>

<...>

## User / Market Context

<Users, customers, competition, market data surfaced from the documents. Footnote every specific claim. If the corpus does not contain user/market content, write a single bullet: "No user/market content surfaced by this scan." — do not delete the section.>

## Technical Context

<Platforms, constraints, integrations, dependencies, operational considerations. Footnote every specific claim. If the corpus does not contain technical content, write a single bullet noting so — do not delete the section.>

## Ideas & Decisions

Every idea carries a tag — `accepted`, `rejected`, or `open` — and rationale. Preserve rejected ideas so future work does not re-propose them.

- **[accepted]** <idea> — <rationale from the document> [^n]
- **[rejected]** <idea> — <rationale for rejection> [^n]
- **[open]** <idea> — <what is still undecided> [^n]

## Raw Detail Worth Preserving

Specific quotes, metrics, and data points that would be lost to summarization. Each entry is a verbatim excerpt (or near-verbatim with explicit ellipsis) plus a footnote.

- "<quote>" [^n]
- "<data point>" [^n]

## Gaps & Limitations

- <What the corpus could not establish, and why. One bullet per gap.>
- <Any path that was empty, unreadable, or skipped via the denylist — name the path and the reason.>
- <Any subagent that failed or returned empty — name the slice and the reason from its stub file.>
- <Claims that were dropped because the citation would have had to be fabricated.>

This section is never empty. If the scan was clean, include at minimum a bullet naming what follow-up reading would sharpen the picture.

## Sources

[^1]: **Path**: <relative path>
      **Excerpt**: "<verbatim quote>"
      **Lines**: <optional, omit if absent>
      **Heading**: <optional, omit if absent>
      **Document type**: <optional, omit if absent>

[^2]: **Path**: <...>
      **Excerpt**: "<...>"

[^n]: <...>
```

## Rules

- **Title line** uses the intent verbatim from `plan.md`. When intent is absent, use `Generic extraction of <slug>`.
- **`Documents Found`** lists every included path (read or skimmed). Skipped paths go in `Gaps & Limitations`.
- **`Key Insights`** groups by theme, not by source document. If one theme only came from one document, that is fine — one bullet, one footnote.
- **`User / Market Context`, `Technical Context`, `Raw Detail Worth Preserving`** — never delete these sections. If the corpus has nothing to say, include a single bullet saying so. Prefer `"No <section> content surfaced by this scan."` over synthesized content — an empty placeholder is correct when the corpus is thin; fabricated content is not.
- **`Ideas & Decisions`** preserves rejected ideas with the rationale for rejection, not just accepted ones. This is the feature, not a nice-to-have.
- **`Gaps & Limitations`** is never empty. At minimum, name what follow-up reading would sharpen the answer.
- **`Sources`** uses global numbering — `[^1]` through `[^n]` across the whole document, not per-section. Citation shape per `citation-schema.md`.

## Sourcing discipline

- Every bullet in `Key Insights`, `User / Market Context`, `Technical Context`, and `Ideas & Decisions` that makes a specific factual claim carries a footnote. Broad synthesis statements can stand without a footnote only if they summarize cited claims elsewhere in the document.
- `Raw Detail Worth Preserving` is 100% cited — every entry is an excerpt with a footnote.
- If a claim cannot be cited, either drop it or move it to `Gaps & Limitations` as something the corpus did not establish.
- `Sources` entries match every `[^n]` used in the body. Orphan citations (listed in `Sources` but never referenced) should be removed.
