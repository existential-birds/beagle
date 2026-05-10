---
name: quarto-book
description: Builds multi-chapter book projects with Quarto (`_quarto.yml` + chapter-per-`.qmd`) compiling to elegant LaTeX/PDF, with optional kaobook bridge for textbook-style typography. Use when the user has Markdown chapters they want to publish as a textbook, thesis, or long-form book; when they ask about Quarto book projects; or when raw Pandoc would be over-structured. Drives Quarto, not raw Pandoc — the project model is the value-add.
---

# Quarto Book

Quarto is built on Pandoc but adds a project system (`_quarto.yml`) that renders groups of documents at once with shared options. For book-length work, Quarto removes a class of flag-negotiation that an agent loop would otherwise script around.

## When this skill fits

- Markdown source (`.qmd`) one-file-per-chapter
- Compiling to PDF (LaTeX backend) and optionally HTML/EPUB from the same source
- "Elegant textbook" target — pairs with `beagle-latex:textbook-typography` for class selection
- Books, theses, technical reference manuals

For single-file LaTeX (paper, resume, slide deck), use `beagle-latex:latex-document` instead. For pure prose docs in Markdown without book chrome, plain Pandoc is enough.

## Workflow

1. **Confirm the target.** "Elegant textbook with sidenotes / mini-TOC at chapter starts" → kaobook (default). "Lecture-notes style with framed code listings" → Eisvogel + scrbook. "Tufte design exactly" → tufte-book. Hand off class selection to `beagle-latex:textbook-typography`.
2. **Scaffold the project.** Copy from `assets/starter/` — `_quarto.yml`, `metadata.yaml`, `chapters/01-intro.qmd`, and (for kaobook) `templates/kaobook.latex` Pandoc bridge.
3. **Write chapters.** One `.qmd` per chapter under `chapters/`. Standard Pandoc Markdown plus Quarto extensions (cross-references, callouts, code execution).
4. **Bibliography wiring.** Add `bibliography: references.bib` to `metadata.yaml`. Cite with `[@key]`. Quarto routes through Pandoc's citeproc — no separate bibtex/biber pass.
5. **Render.** `quarto render` builds the whole book. `quarto render chapters/02-foundations.qmd` builds one chapter (Quarto's equivalent of `\includeonly`).
6. **Iterate with preview.** `quarto preview` watches for changes and reloads.
7. **Audit before delivery.** Run `beagle-latex:latex-code-review` on the rendered intermediate `.tex` if you want to catch long-form anti-patterns. (Quarto leaves intermediate `.tex` in `_book/` when `keep-tex: true` is set.)

## Project layout

```text
osprey-textbook/
├── _quarto.yml              # project + book config
├── metadata.yaml            # author, title, bibliography, mainfont
├── references.bib
├── chapters/
│   ├── 01-intro.qmd
│   ├── 02-foundations.qmd
│   └── 03-applications.qmd
├── figures/
│   └── *.png
├── templates/
│   └── kaobook.latex        # Pandoc bridge for kaobook class
└── _book/                   # build output (gitignore this)
    ├── osprey-textbook.pdf
    ├── osprey-textbook.tex  # if keep-tex: true
    └── osprey-textbook.aux
```

## `_quarto.yml` shape

```yaml
project:
  type: book
  output-dir: _book

book:
  title: "Osprey Study Plan"
  subtitle: "Schedule, method, materials, and the 150-day sequel"
  author: "Kevin Anderson"
  date: "today"
  chapters:
    - index.qmd
    - chapters/01-intro.qmd
    - chapters/02-foundations.qmd
    - chapters/03-applications.qmd
  bibliography: references.bib

format:
  pdf:
    documentclass: kaobook        # or scrbook (Eisvogel) or tufte-book
    classoption: [11pt, oneside]
    template: templates/kaobook.latex
    pdf-engine: lualatex          # kaobook prefers lualatex for fontspec
    keep-tex: true                # keep intermediate .tex for inspection
    toc: true
    toc-depth: 2
    number-sections: true
    fig-pos: htbp
    citeproc: true
    listings: true
```

The starter under `assets/starter/` ships a working version of this — copy and customize.

## Chapter `.qmd` shape

```markdown
# Foundations

This chapter establishes the baseline study method that the rest of the
book builds on. We start from first principles to avoid carrying forward
unchecked assumptions.

## Spaced repetition

The core mechanism is spaced repetition with...

::: {.callout-note}
For the empirical basis behind these intervals, see [@bjork1992].
:::

::: {.aside}
Sidenotes work natively in kaobook via the `aside` class. The Pandoc
bridge template translates `::: {.aside}` into `\sidenote{...}`.
:::

@fig-schedule shows the full sequence.

![Schedule grid](figures/schedule.png){#fig-schedule width=80%}
```

## Render commands

```bash
quarto render                                # full book → _book/<name>.pdf
quarto render chapters/02-foundations.qmd    # one chapter (still uses book context)
quarto preview                               # watch + auto-reload
quarto check                                 # validate environment + dependencies
```

For per-chapter incremental rebuilds during writing, set up the `PostToolUse` hook from the plugin README — fires `quarto render <file>` on every Edit/Write.

## Bridging to kaobook

Quarto's default LaTeX template targets `scrartcl` / `scrbook`. For kaobook, you need a custom Pandoc bridge template that:

1. Uses `\documentclass{kaobook}` (vs `\documentclass{scrbook}`)
2. Maps Pandoc's `\sidenote{...}` AST to kaobook's `\sidenote{...}` (kaobook ships native sidenote support — the mapping is a one-line variable)
3. Imports kaobook's preamble (`kaobook.cls` plus its bundled style files)
4. Handles the chapter-mini-TOC: kaobook's `\bookmarksetup` and `\setchapterimage` need correct ordering

The starter ships `templates/kaobook.latex` with these bridges in place. See `beagle-latex:textbook-typography` for full class details.

## Gates

1. **Class chosen** — Before scaffolding. **Pass:** You can name the class (kaobook / scrbook+Eisvogel / tufte-book) and explain why it matches the user's described aesthetic. Defer to `beagle-latex:textbook-typography` if uncertain.
2. **Project renders** — Before reporting work complete. **Pass:** `quarto render` exits 0 and `_book/<name>.pdf` exists. Re-run `quarto check` if it fails.
3. **Cross-references resolve** — When chapters cite each other or figures. **Pass:** No `?@fig-...` or `?@sec-...` placeholders in the rendered PDF. (Quarto silently substitutes `??` for unresolved cross-refs — visual inspection of the output is required.)
4. **Bibliography resolves** — When `references.bib` is wired up. **Pass:** The rendered PDF's bibliography contains every `[@key]` cited; no `[?]` markers in the body.

## Common failure modes

- **`Quarto rendering aborted: Could not find pandoc`** — Quarto bundles Pandoc internally; this means the bundled binary is missing. Reinstall Quarto.
- **`! LaTeX Error: File 'kaobook.cls' not found`** — kaobook isn't in `texmf`. Either install via TeX Live (`tlmgr search kaobook` shows current package name) or vendor `kaobook.cls` plus its supporting files into the project root.
- **Cross-refs render as `??`** — Quarto needs two passes for cross-refs in some setups. `quarto render` should handle this; if it doesn't, set `cite-method: citeproc` explicitly and rerun.
- **Sidenotes not appearing** — kaobook's sidenote macro must be wired in the template. Check `templates/kaobook.latex` ships the `$if(sidenote)$` block. The starter handles this.
- **`pandoc-sidenote` confusion** — That filter is for tufte-book class, not kaobook. kaobook has native sidenotes; don't add `--filter pandoc-sidenote` unless you switched class.

## Reference: Quarto 1.9+ LLM-friendly outputs

Quarto 1.9 (March 2026) added `llms.txt` output for websites — useful for HTML book outputs that AI tools should index. Add to `_quarto.yml` under `format: html:` to enable. Niche; skip for PDF-only books.
