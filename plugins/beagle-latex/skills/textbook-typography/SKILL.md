---
name: textbook-typography
description: Picks the right LaTeX class and design for an "elegant textbook" — kaobook (KOMA + Tufte hybrid, sidenotes and mini-TOC at chapter starts), Eisvogel + scrbook (lower-friction Pandoc default), or tufte-book (canonical Tufte layout). Covers class trade-offs, sidenote setup, margin design, and the `pandoc-sidenote` filter for tufte workflows. Use when the user wants a book, thesis, or technical manual with marginalia / asides / margin figures, or when choosing between Pandoc/Quarto LaTeX templates for book output.
---

# Textbook Typography

Three serious stacks survive the "elegant textbook, ship-now, maintained upstream" filter. Pick once based on visual target — class is hard to switch later.

## Stack A — kaobook (recommended)

`fmarotta/kaobook` derives from Ken Arroyo Ohori's thesis class plus `tufte-latex`, sitting on KOMA-Script. The wide outer margin holds sidenotes, marginnotes, small figures, and a per-chapter mini-TOC. Two layout modes: `margin` (Tufte-flavored, default) and `wide` (full text-block for code-heavy passages).

**License:** LPPL-1.3c on the class, CC0 on examples — you can lift the example tree directly.

**Use when:**
- "Elegant textbook with sidenotes" is the target
- You want chapter-opening mini-TOCs
- You'll have asides, citations in margins, or marginal figures
- Code-heavy chapters can swap to wide layout per-chapter

**Watch out for:**
- No first-party Pandoc template — the Quarto bridge template at `beagle-latex:quarto-book/assets/starter/templates/kaobook.latex` handles this
- Multi-pass rebuilds: kaobook docs note "occasionally LaTeX can need up to four re-runs" for margin float positioning. Use latexmk.
- lualatex preferred over pdflatex (fontspec for typography control)

**Minimal preamble:**

```latex
\documentclass[
  fontsize=10pt,
  paper=a4,
  open=any,           % chapters open on any page (vs openright default)
  numbers=noenddot,
]{kaobook}

\usepackage{kaobiblio}                  % bibliography styling
\usepackage[framed=true]{kaotheorems}   % theorem environments
\usepackage{kaorefs}                    % cross-reference styling

\title{Osprey Study Plan}
\author{Kevin Anderson}
\date{\today}

\begin{document}
\maketitle
\tableofcontents
\mainmatter

\chapter{Introduction}
This is the body. \sidenote{And this is a sidenote — appears in the wide outer margin.}
% ...
\end{document}
```

**Sidenote macros:**

| Macro | Behavior |
|---|---|
| `\sidenote{text}` | Numbered sidenote; auto-positioned in the outer margin |
| `\marginnote{text}` | Unnumbered note in the margin |
| `\sidecite{key}` | Citation rendered in the margin (instead of inline) |
| `\sidefigure[width]{path}{caption}` | Figure in the margin |

**Layout modes:**

```latex
\begin{kaobox-toc}                        % chapter mini-TOC at start
\end{kaobox-toc}

\begin{margintable}                       % small table in margin
  ... 
\end{margintable}

% Switch to wide layout for code-heavy section:
\widelayout
% ... wide text content ...
\marginlayout                              % return to default
```

## Stack B — Eisvogel + KOMA `scrbook` (lower-friction fallback)

`Wandmalfarbe/pandoc-latex-template` (Eisvogel) is Pandoc's most-recommended LaTeX template. Default class is `scrartcl`; for books, flip to `scrbook` and pass `--top-level-division=chapter`. Clean modern KOMA body, framed code listings, Skylighting syntax highlighting. **No native sidenotes / margin column.**

**Use when:**
- "Looks professional" matters more than "Tufte aesthetic"
- You don't need marginalia
- You want zero custom-template work — drop two files into `~/.local/share/pandoc/templates/`, pass `--template eisvogel`, done
- Code-heavy lecture notes

**Setup:**

```bash
mkdir -p ~/.local/share/pandoc/templates
curl -L https://github.com/Wandmalfarbe/pandoc-latex-template/releases/latest/download/eisvogel.latex \
  -o ~/.local/share/pandoc/templates/eisvogel.latex
```

**One-liner invocation:**

```bash
pandoc 00_intro.md 01_method.md 02_schedule.md \
  --template eisvogel \
  --pdf-engine xelatex \
  --top-level-division=chapter \
  -V classoption=oneside \
  -V book \
  --listings \
  -o textbook.pdf
```

**For Quarto:** set `format: pdf: documentclass: scrbook` and `template: eisvogel` in `_quarto.yml`.

## Stack C — tufte-latex (`tufte-book`) + `pandoc-sidenote`

Bil Kleb's `tufte-latex` (`tufte-book` class) plus `jez/pandoc-sidenote`, a Pandoc filter that rewrites footnotes into `\sidenote{...}`.

**Use when:**
- The Tufte design is the explicit aesthetic target (the asymmetric page, the specific font, the exact typography Edward Tufte uses)
- You're modeling a book's design on Tufte's "Visual Display of Quantitative Information" or "Beautiful Evidence"

**Watch out for:**
- Pandoc by itself "omits sidenote contents completely" — you must run the filter
- Less flexible than kaobook for non-Tufte deviations
- Asymmetric layout (text + side margin) may not be what users actually want when they ask for "Tufte-style"

**Setup:**

```bash
# Install the filter
cabal install pandoc-sidenote      # Haskell route
# OR
brew install pandoc-sidenote       # macOS
```

**Invocation:**

```bash
pandoc input.md \
  --filter pandoc-sidenote \
  --template tufte-book.latex \
  --pdf-engine xelatex \
  --top-level-division=chapter \
  -o tufte-book.pdf
```

The filter converts every `[^1]` footnote into a `\sidenote{...}`.

## Decision matrix

| Need | kaobook | Eisvogel+scrbook | tufte-book |
|---|---|---|---|
| Sidenotes / marginalia | ✓ native | — | ✓ via filter |
| Mini-TOC at chapter starts | ✓ | — | — |
| Code listings | ✓ (kaocodes) | ✓ (Skylighting) | weak |
| Setup time | ~30 min (custom template) | ~5 min | ~15 min (filter install) |
| Pandoc support | DIY template | first-class | filter required |
| Tufte aesthetic | "in the spirit of" | — | exact |
| Multi-pass cost | up to 4 passes | 2-3 passes | 2-3 passes |
| Recommended for new work | **yes** | yes (when no marginalia needed) | only if Tufte is the explicit target |

## Common failure modes

- **kaobook compiled without lualatex/xelatex** — kaobook uses `fontspec`. Set `pdf-engine: lualatex` in Quarto config or `--pdf-engine=lualatex` on the command line.
- **kaobook margin floats overlap text** — Run latexmk with extra passes (`-r .latexmkrc` configured for 4 max passes). Margin float positioning needs multiple iterations to settle.
- **Eisvogel: code listings render as raw text** — Pass `--listings` to Pandoc. Quarto: `listings: true` in format-pdf block.
- **tufte-book: footnotes appear at page bottom instead of margin** — Filter not running. Verify `--filter pandoc-sidenote` is on the command line; check `pandoc-sidenote --version` works.
- **Chapter pages start on left page (verso)** — `tufte-book` defaults to `openright`. Add `\documentclass[oneside]{tufte-book}` or `openany` option.

## Body font recommendations

Books at 11pt (kaobook default) on A4 with kaobook's wide margins read best with a font with strong italics and a real text figures option:

| Font | License | Notes |
|---|---|---|
| **EB Garamond** | OFL | Free, classic, excellent for long-form reading |
| **Crimson Pro** | OFL | Free, more modern feel, paired well with Inter sans |
| **Source Serif Pro** | OFL | Free, Adobe-designed, very readable |
| **Palatino** (newpx) | LPPL | Bundled with TeX Live; default in many academic books |
| **Charter** | OFL | Free, designed for laser printers, dense text-friendly |
| **Minion** | commercial | Adobe; expensive but the standard for trade books |

Specify in Quarto:

```yaml
format:
  pdf:
    mainfont: "EB Garamond"
    sansfont: "Source Sans Pro"
    monofont: "JetBrains Mono"
```

Or in raw LaTeX with kaobook:

```latex
\usepackage{fontspec}
\setmainfont{EB Garamond}
\setsansfont{Source Sans Pro}
\setmonofont{JetBrains Mono}[Scale=0.95]
```

## Gates

1. **Class fits aesthetic** — Before scaffolding. **Pass:** You can name the class chosen and tie it to a concrete user-stated need (e.g., "user wants margin sidenotes for asides → kaobook", "user wants minimum setup, no marginalia → Eisvogel+scrbook").
2. **Engine matches class** — Before first compile. **Pass:** lualatex/xelatex specified for kaobook or any class using `fontspec`. pdflatex acceptable for Eisvogel+scrbook unless system fonts are needed.
3. **Margin elements verified** — When using kaobook or tufte-book. **Pass:** A test compile produced visible sidenotes/marginnotes in the rendered PDF. Compilation alone is not enough — these can compile clean but render empty if the macros aren't wired correctly.
