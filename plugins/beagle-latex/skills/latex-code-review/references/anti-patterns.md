# Long-Form LaTeX Anti-Patterns

This reference enumerates the patterns that silently degrade LaTeX documents of 5+ pages — reports, theses, books, strategic documents. Each anti-pattern produces a document that compiles cleanly but reads as machine-generated. The code-review skill loads this file when reviewing long-form work.

The frame for every entry: when reviewing, check whether the document under review violates the rule, and if so emit a finding in `[FILE:LINE] ISSUE_TITLE` format. The "Why" line in each section gives the rationale you can paste into the description.

---

## 1. Wall of Bullets — Over-reliance on itemize/enumerate

**The pattern:** Every group of related points becomes `\begin{itemize}`. A 40-page report ends up with 50–80 bulleted blocks, reading like a slide deck rather than a document.

**The rule:** In reports and articles, prose paragraphs are the default. Bullet lists are the exception. Use this decision frame:

| Content | Format | Examples |
|---|---|---|
| Analysis, explanation, argument | Prose paragraph | Trends, rationale, findings |
| Genuinely parallel items | Table (`tabularx` + `booktabs`) | Specs, pricing tiers |
| 3–5 labeled concepts | Bold-label paragraphs | `\textbf{Concept:} Explanation...` |
| Personas, callouts | `tcolorbox` cards | Customer profiles, executive summaries |
| Sequential process | Numbered prose or table | Phases, roadmap |
| Raw reference data | Bullet list (only here) | Bibliography, prerequisites |

**Target:** A well-formed 40-page report has fewer than 15 itemize/enumerate blocks total. Above 20, refactor.

**Bad:**
```latex
\textbf{Market Trends:}
\begin{itemize}
  \item Multi-model adoption is increasing
  \item Open-source models growing at 46\%
  \item Startups adopt 3-5x faster than enterprises
\end{itemize}
```

**Good (prose):**
```latex
\textbf{Market Trends:} Multi-model adoption is accelerating, with nearly all
enterprises testing multiple AI providers rather than standardizing on one.
Open-source models gain traction—46\% of organizations prefer them for cost
and control. Startups adopt agentic tools 3–5x faster than enterprises.
```

**Good (bold-label paragraphs):**
```latex
\textbf{Multi-Model Adoption:} Nearly all enterprises now test multiple
AI models, favoring flexibility per task.

\textbf{Open-Source Surge:} 46\% of organizations prefer open-source models,
creating demand for platforms supporting both commercial and open-source.
```

---

## 2. Excessive `\newpage`

**The pattern:** `\newpage` before every `\section`, creating pages 30–50% empty.

**The rule:** Let LaTeX handle page breaks. `\newpage` is appropriate only:
- Around `\tableofcontents` (front and back)
- Before the first `\section` after front matter
- Between truly independent major parts (e.g., a 20-page analysis and a 10-page appendix)
- When a figure or table would split awkwardly across pages

Never before every section or subsection. LaTeX's page-breaking algorithm is sophisticated — let it work.

---

## 3. Oversized Images and Rigid Float Placement

**The pattern:** Images at `width=0.95\textwidth` plus `[H]` placement push surrounding text to the next page, producing half-empty pages.

**The rule:**
- Default image width: `0.75\textwidth` to `0.85\textwidth`. Not 0.95.
- Use `[htbp]` for most figures — let LaTeX optimize placement.
- `[H]` only when the figure must appear at that exact spot (e.g., immediately after "as shown below").
- AI-generated images (1–2 MB sources) are usually fine at `0.75\textwidth`.
- Charts and graphs: `0.80–0.85\textwidth`.
- Full-page figures: `0.90\textwidth` maximum.

```latex
% Good
\begin{figure}[htbp]
\centering
\includegraphics[width=0.80\textwidth]{chart.png}
\caption{Revenue growth by quarter}
\end{figure}
```

---

## 4. No Global List Compaction

**The pattern:** LaTeX's default list spacing (`itemsep`, `topsep`, `parsep`, `partopsep`) is generous. A 4-item list consumes paragraph-equivalent vertical space.

**The rule:** Add global list compaction to the preamble for any report or article:

```latex
\usepackage{enumitem}
\setlist[itemize]{nosep, leftmargin=*, topsep=2pt, partopsep=0pt}
\setlist[enumerate]{nosep, leftmargin=*, topsep=2pt, partopsep=0pt}
```

This matches list spacing to body text density without losing readability.

---

## 5. Monotonous Section Structure

**The pattern:** Every subsection follows the same shape — intro sentence, bullet list, bold conclusion. Over 40 pages, this repetition makes the document feel generated.

**The rule:** Vary presentation. A long document should use at least 3–4 different content formats:

1. Prose paragraphs (analysis, narrative, argument)
2. Tables (`booktabs` + `tabularx`) for comparisons
3. `tcolorbox` cards for profiles and callouts
4. Bold-label paragraphs for distinct concepts
5. Figures with captions
6. `longtable` for multi-page structured comparisons

Adjacent sections should not use the same format. If 3.1 uses a table, 3.2 should use prose or a callout, not another table.

---

## 6. Silent Encoding Errors

**The pattern:** Document compiles cleanly but the PDF contains garbage characters (inverted question marks, missing symbols). Compilation success masks the failure.

**Common silent errors:**

| You write | PDF shows | Fix |
|---|---|---|
| `<5%` in text | ¿5% | `$<$5\%` |
| `>50` in text | ¡50 | `$>$50` |
| `~` in text | (tilde accent on next char) | `\textasciitilde` |
| `\|` in text | (renders unpredictably) | `\textbar` or `$\vert$` |
| `\` in text | (starts a command) | `\textbackslash` |
| `{` or `}` in text | (grouping chars vanish) | `\{` or `\}` |

**The rule:** After generating LaTeX content, scan for these characters in text mode (outside `$...$` and command arguments). The most commonly missed are `<` and `>` — they look fine in source but render inverted.

---

## 7. Hardcoded Dimensions

**The pattern:** Absolute units (`12cm`, `5in`, `300pt`) for widths, margins, spacing. The document breaks when paper size, font size, or column layout changes. A figure at `width=15cm` overflows on letter paper with 1-inch margins.

**The rule:** Use relative units that adapt to the layout:

| Instead of | Use | Why |
|---|---|---|
| `width=15cm` | `width=0.8\textwidth` | Adapts to margins and columns |
| `\hspace{2cm}` | `\hspace{2em}` or `\quad` | Scales with font size |
| `\vspace{1in}` | `\vspace{\baselineskip}` | Consistent with line spacing |
| `\parindent=20pt` | `\parindent=1.5em` | Scales with font |
| `\setlength{\tabcolsep}{12pt}` | `\setlength{\tabcolsep}{1em}` | Font-relative |

**Exception:** Page margins via `geometry` use absolute units by design (`margin=1in`).

---

## 8. Missing `\noindent` After Display Math

**The pattern:** LaTeX treats text after a display math environment as a new paragraph and indents it. When the text is a continuation ("where $a$, $b$, $c$ are coefficients"), the indent reads as a discontinuity.

**Wrong:**
```latex
The quadratic formula is:
\[ x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a} \]
where $a$, $b$, and $c$ are coefficients.   % indented — looks like new paragraph
```

**Right:**
```latex
The quadratic formula is:
\[ x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a} \]
\noindent where $a$, $b$, and $c$ are coefficients.
```

**The rule:** When text after a display equation continues the same thought (starts with "where", "for", "with", "so", "thus"), prefix it with `\noindent`.

---

## 9. Widow and Orphan Lines

**The pattern:** A single line of a paragraph appears alone at the bottom of a page (orphan) or top of the next page (widow). Default LaTeX penalties are too low to prevent it reliably.

**The rule:** Add these penalties to the preamble for any document over 5 pages:

```latex
\widowpenalty=10000
\clubpenalty=10000
```

For critical documents, also:

```latex
\brokenpenalty=10000     % avoid breaks after hyphenated lines
\predisplaypenalty=10000 % avoid breaks before display math
```

---

## Quick reference: Report-class baseline preamble

Any report-class document over 10 pages should include this baseline:

```latex
\documentclass[11pt,a4paper]{article}

\usepackage[margin=1in]{geometry}
\usepackage{graphicx}
\usepackage[colorlinks=true, linkcolor=blue, urlcolor=blue]{hyperref}
\usepackage[table]{xcolor}
\usepackage{colortbl, booktabs, tabularx, longtable}
\usepackage{float, enumitem}
\usepackage{amsmath, amssymb}
\usepackage[most]{tcolorbox}
\usepackage{titlesec, fancyhdr}
\usepackage{microtype}

\setlist[itemize]{nosep, leftmargin=*, topsep=2pt, partopsep=0pt}
\setlist[enumerate]{nosep, leftmargin=*, topsep=2pt, partopsep=0pt}

\widowpenalty=10000
\clubpenalty=10000
```

---

## Reviewer checklist (before reporting findings)

For each anti-pattern, count occurrences in the file under review and report only meaningful violations — a 2-page CV doesn't need 9 anti-pattern coverage. Calibrate by document length:

- **Bullet count:** Fewer than 15 itemize/enumerate per 40 pages? If not, flag #1.
- **Angle brackets:** `<` or `>` outside math mode? Flag #6 with line numbers.
- **`\newpage` count:** More than ~5 in a 40-page doc? Flag #2.
- **Image widths:** Any at `0.95\textwidth` without "full-bleed" intent? Flag #3.
- **List compaction:** `\setlist[itemize]{nosep, ...}` present? If not, flag #4.
- **Float placement:** Most figures `[H]`? Flag #3 unless exact placement matters.
- **Hardcoded dims:** Width/spacing in `cm`/`in`/`pt` outside `geometry`? Flag #7.
- **Section variety:** Three adjacent subsections all ending in itemize? Flag #5.
- **`\noindent` after display math:** Missing where text continues the thought? Flag #8.
- **Widow/club penalties:** Missing in 5+ page document? Flag #9.

Special characters that need escaping in text mode: `%`, `$`, `&`, `#`, `_`, `<`, `>`, `~`, `^`, `\`, `{`, `}`.
