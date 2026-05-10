---
name: latex-code-review
description: Reviews `.tex` source files for the long-form anti-patterns LLM-generated LaTeX usually ships with — wall-of-bullets, oversized images, silent encoding errors (`<`/`>` rendering as inverted punctuation), missing `\noindent` after display math, hardcoded dimensions, widow/orphan lines, and missing `\usepackage` for cited commands. Use when reviewing LaTeX before delivery, auditing a thesis or report, or hardening a paper before submission. Produces `[FILE:LINE] ISSUE_TITLE` findings calibrated by document length.
---

# LaTeX Code Review

A `.tex` file that compiles cleanly is not the same as a `.tex` file that reads as professionally authored. This skill audits for the patterns that produce technically-valid-but-machine-feeling LaTeX.

## When to run

- Before delivering any document of 5+ pages
- Before submitting a paper, thesis, or report
- After a large LLM-generated draft, before the user sees the PDF
- When a PDF "looks off" but you can't pin down why

For documents under 3 pages (one-page CV, single-page memo) the long-form anti-patterns mostly don't apply — skip this skill and rely on the compile pass alone.

## Workflow

1. **Read the source.** Open the full `.tex` (and any included chapter files). Don't review from a diff alone — anti-patterns hide in surrounding context.
2. **Estimate page count.** From `\documentclass`, `geometry`, and content volume — a rough estimate is enough. This sets which anti-patterns apply.
3. **Load the anti-patterns reference.** Read [references/anti-patterns.md](references/anti-patterns.md) — the 9 patterns plus the reviewer checklist.
4. **Run the checklist.** For each pattern, count occurrences in the file. Calibrate severity by document length (1 itemize block in a 2-page memo is fine; 50 in a 40-page report is a finding).
5. **Verify before reporting.** Complete the gates below.

## Output Format

```text
[FILE:LINE] ISSUE_TITLE
Severity: Critical | Major | Minor | Informational
Description of the issue, why it matters, and the fix.
```

Anchor every finding to a specific file and line. If the issue spans the whole document (e.g., "no global list compaction"), cite the preamble line where the package import would land.

## Severity calibration

- **Critical**: silent encoding errors that produce wrong characters in the PDF (anti-pattern #6); document fails to compile due to missing `\usepackage` for a used command.
- **Major**: wall-of-bullets in long documents, oversized images that push pages around, monotonous structure across many sections, hardcoded dimensions causing layout breakage on different paper sizes.
- **Minor**: missing `\noindent` after display math, missing widow/club penalties, naked floats without placement specifiers.
- **Informational**: stylistic preferences, suggestions for `tcolorbox` callouts, format variety opportunities.

## Gates

Sequenced. Do not skip.

1. **Anti-patterns reference loaded** — Before reporting any finding from anti-patterns 1–9. **Pass:** You read [references/anti-patterns.md](references/anti-patterns.md) in full this turn and can cite which pattern number each finding maps to.
2. **Length calibration** — Before assigning severity. **Pass:** You stated the document's approximate page count and used it to rule out patterns that don't apply (e.g., widow penalties on a 2-page memo).
3. **Encoding scan** — Before finalizing the report. **Pass:** You grepped for `<`, `>`, `~`, `|`, `\`, `{`, `}` in text mode (outside `$...$` and command arguments) and reported any unescaped occurrences with line numbers.
4. **Verification protocol** — Before submitting findings. **Pass:** `beagle-core:review-verification-protocol` is loaded and every applicable step is completed.

## Quick reference

The full anti-pattern list lives in [references/anti-patterns.md](references/anti-patterns.md). Summary:

| # | Pattern | Heaviest signal |
|---|---|---|
| 1 | Wall of bullets | >15 itemize/enumerate per 40 pages |
| 2 | Excessive `\newpage` | `\newpage` before every section |
| 3 | Oversized images, rigid floats | `width=0.95\textwidth`, blanket `[H]` |
| 4 | No global list compaction | Missing `\setlist[...]{nosep, ...}` |
| 5 | Monotonous section structure | 3+ adjacent subsections ending in itemize |
| 6 | Silent encoding errors | `<`, `>`, `~`, `|` unescaped in text mode |
| 7 | Hardcoded dimensions | Widths in `cm`/`in`/`pt` outside `geometry` |
| 8 | Missing `\noindent` after display math | "where ... " indented as new paragraph |
| 9 | Widow/orphan lines | Missing widowpenalty/clubpenalty in 5+ page doc |

Special-character escaping in text mode: `%`, `$`, `&`, `#`, `_`, `<`, `>`, `~`, `^`, `\`, `{`, `}` all need explicit escapes.

## Common false positives to avoid

- **Bullet lists in bibliographies, glossaries, prerequisites, or genuinely parallel reference data** — anti-pattern #1 explicitly carves these out. Don't flag them.
- **`\newpage` around `\tableofcontents`** — that's standard, not abuse (#2).
- **Wide images that are intended as full-bleed cover plates** — check the caption and surrounding context before flagging #3.
- **Hardcoded margins via `geometry`** — `margin=1in` is the documented usage, not a violation of #7.

## Output checklist

Before submitting findings, confirm:

- [ ] Each finding has `[FILE:LINE]` anchor
- [ ] Severity matches the calibration above
- [ ] At least one fix suggestion per Major/Critical finding
- [ ] Anti-pattern number cited where applicable (`Anti-pattern #6`)
- [ ] Gates 1–4 all passed
