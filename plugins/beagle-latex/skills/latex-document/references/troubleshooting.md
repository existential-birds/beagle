# LaTeX Compilation Troubleshooting

Reference for engine selection, latexmk usage, multi-chapter incremental builds, and parsing log errors when compilation goes sideways.

## Engine choice

Auto-detection lives in the compile script and works for the common cases. When you have to override:

| Engine | When | Cost |
|---|---|---|
| **pdflatex** | Default. ASCII or UTF-8 with `inputenc{utf8}`. Most packages. | Fastest. |
| **xelatex** | `fontspec`, `xeCJK`, `polyglossia` — system fonts, multilingual, RTL. | Slower than pdflatex. |
| **lualatex** | `luacode`, programmatic typesetting, very large documents. | Slowest, but flexible. |

Documents already targeting a non-default engine declare it via package imports — the compile script reads them. Override with `--engine xelatex` only when something specific (a `.ttf` system font, a non-Latin script) demands it.

## Build engine: latexmk

`latexmk` runs the right number of passes for cross-references, bibliography, index, and glossary — automatically. Prefer it for any document beyond a quick one-pass test.

```bash
bash <skill_path>/scripts/compile_latex.sh document.tex --use-latexmk
```

Direct invocation:

```bash
latexmk -pdf -interaction=nonstopmode document.tex          # pdflatex
latexmk -xelatex -interaction=nonstopmode document.tex      # xelatex
latexmk -lualatex -interaction=nonstopmode document.tex     # lualatex
latexmk -c document.tex                                      # clean aux files
```

Project-level config goes in `.latexmkrc`:

```perl
$pdf_mode = 1;                # use pdflatex
$pdflatex = 'pdflatex -interaction=nonstopmode -synctex=1 %O %S';
$bibtex_use = 2;              # always run bibtex if a .bib is referenced
$clean_ext = 'synctex.gz run.xml bbl';   # extra files for -c
```

## Multi-chapter projects: `\include` + `\includeonly`

For book-length documents, split chapters into separate files and `\include` them from a root `.tex`:

```latex
% root.tex
\documentclass{book}
% ... preamble ...
\begin{document}
\frontmatter
\include{front/preface}
\mainmatter
\include{chapters/01-intro}
\include{chapters/02-foundations}
\include{chapters/03-applications}
\backmatter
\include{back/bibliography}
\end{document}
```

Each `\include{name}` reads `name.tex` and starts it on a new page. `\includeonly{...}` in the preamble compiles only the listed chapters while preserving cross-references and page numbers from the last full build:

```latex
\includeonly{chapters/02-foundations}    % only this chapter rebuilds
```

Workflow: do a full build first, then iterate on one chapter with `\includeonly`. The chapter rebuilds in seconds; cross-references to other chapters keep working because LaTeX reads the cached `.aux` files.

For multi-chapter projects, use the Quarto book pattern — see project-specific tooling in your repo.

## Auto-compile on edit

The plugin README ships a `PostToolUse` hook recipe that recompiles the touched chapter on every Edit/Write. Pair with `\includeonly` and per-edit feedback is sub-second on most chapters.

For pre-commit gating, see [jonasbb/pre-commit-latex-hooks](https://github.com/jonasbb/pre-commit-latex-hooks).

## Log parsing — common errors

The compile script in `latex-document` surfaces these automatically. When debugging by hand, scan the `.log` file for:

| Symptom | Cause | Fix |
|---|---|---|
| `! LaTeX Error: File '...sty' not found.` | Missing package | `tlmgr install <pkg>` (or `apt install texlive-latex-extra`) |
| `! Undefined control sequence. l.42 \foo` | Unknown command | Check spelling; add the providing `\usepackage{...}` |
| `! Missing $ inserted.` | Math symbol in text mode | Wrap in `$...$` or use `\textless` / `\textgreater` |
| `! LaTeX Error: Environment X undefined.` | Package not loaded | Find which package provides `X` and add `\usepackage{...}` |
| `! Too many }'s.` / `Runaway argument?` | Unbalanced braces | Search for orphan `{` or `}` near the cited line |
| `Overfull \hbox (12.3pt too wide)` | Text overflows margin | Add `\usepackage{microtype}`; rephrase paragraph; check long URLs |
| `Underfull \hbox (badness 10000)` | Stretched line on a forced break | Usually safe to ignore; rephrase if visible |
| `Citation '...' undefined` | Bibtex/biber didn't run, or key typo | Re-run with multi-pass; check `.bib` |
| `LaTeX Warning: There were undefined references` | Forward `\ref` not yet resolved | Compile again — references resolve on second pass |
| `! pdfTeX error: ... PDF inclusion: required version too high` | PDF figure version mismatch | Re-export figure or use `pdftk` to downgrade |
| `! TeX capacity exceeded` | Genuine resource limit | Split into smaller files; increase memory in `texmf.cnf`; check for infinite recursion |

## Performance tips for long documents

1. **Use `\includeonly`.** A 300-page thesis goes from 30s full builds to 2s chapter builds.
2. **Use `\includegraphics[draft]{...}`** during writing — skips image rendering, ships placeholders.
3. **Use `nofonts` option for `tikz`** during drafting if compile time is dominated by figures.
4. **Preload a format file** for repeated identical preambles (`pdflatex -ini`). Niche; only worth it for batch generation.
5. **Run latexmk in continuous mode** while writing: `latexmk -pvc -pdf root.tex` — recompiles on every save and reloads the viewer.
