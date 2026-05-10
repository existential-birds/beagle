---
name: latex-document
description: Creates, edits, and compiles single-file LaTeX documents — resumes, articles, reports, beamer presentations, IEEE journal papers, and standalone books. Auto-detects engine (pdflatex/xelatex/lualatex), runs bibtex/biber/makeindex/makeglossaries automatically, and ships templates that compile clean. Use when the user asks to write a CV, draft a paper, build a slide deck, generate a report, or compile a `.tex` file. For multi-chapter book projects driven from Markdown/`.qmd`, use `beagle-latex:quarto-book` instead.
---

# LaTeX Document

Single-file `.tex` workflow. For multi-chapter books with chapter-per-file source, defer to `beagle-latex:quarto-book`.

## Workflow

1. **Identify document type.** Ask the user if not stated. Map to a template from `assets/templates/` (article, report, resume-ats, beamer, ieee-twocolumn, book-academic). For "elegant textbook" or anything Tufte-flavored, hand off to `beagle-latex:textbook-typography` for class selection first.
2. **Copy or scaffold.** Copy the closest template into the project, rename to the target file, and customize content. Do not retain placeholder names ("FULL NAME", "[Industry/Field]") in the final output.
3. **Pick the right engine.** Auto-detection in the compile script handles this for you — `fontspec`/`xeCJK`/`polyglossia` triggers xelatex; `luacode`/`directlua` triggers lualatex; everything else uses pdflatex. Override with `--engine` only when you have a specific reason.
4. **Add citations / index / glossary if needed.** For citations, hand off to `beagle-latex:latex-bibliography`. The compile script auto-detects `\bibliography{...}` (bibtex), `\addbibresource{...}` (biber), `\makeindex`/`\printindex`, and `\makeglossaries`/`\newacronym`, and runs the right pass.
5. **Compile.** Use the bundled script. For a clean dependency-driven build, prefer `--use-latexmk` once you've confirmed the document compiles end-to-end.
6. **Audit before delivering.** For documents 5+ pages, run `beagle-latex:latex-code-review` to catch the long-form anti-patterns. For shorter docs (resume, single-page article), skip the review.

## Compile

```bash
bash <skill_path>/scripts/compile_latex.sh document.tex            # default
bash <skill_path>/scripts/compile_latex.sh report.tex --preview    # + PNG preview per page
bash <skill_path>/scripts/compile_latex.sh thesis.tex --use-latexmk
bash <skill_path>/scripts/compile_latex.sh paper.tex --auto-fix    # naked floats + microtype
bash <skill_path>/scripts/compile_latex.sh thesis.tex --pdfa       # PDF/A-2b output
bash <skill_path>/scripts/compile_latex.sh document.tex --clean    # remove .aux/.log/etc.
```

The script does not install dependencies. If `pdflatex`, `pdftoppm`, `latexmk`, or `biber` is missing it prints a one-line install hint per-OS. See the plugin README for full setup commands.

## Templates

Bundled in `assets/templates/`:

| Template | Class | Engine | When to use |
|---|---|---|---|
| `article.tex` | `article` | pdflatex | General single-author articles, short essays |
| `report.tex` | `article` | pdflatex | Multi-section business or research reports with charts and tables |
| `resume-ats.tex` | `article` | pdflatex | ATS-safe résumé — no graphics, no hyperref, single column, plain fonts |
| `beamer.tex` | `beamer` | pdflatex | Slide decks |
| `ieee-twocolumn.tex` | `IEEEtran` | pdflatex | IEEE journal/conference submission |
| `book-academic.tex` | `book` | pdflatex | Standalone book or thesis with theorems, drop caps, frontmatter/mainmatter/backmatter |

Copy a template, then customize `\title`, `\author`, body content, and any package selections. Strip placeholder text completely — leftover lorem ipsum or `[Industry/Field]` brackets in delivered work is the most common visible LLM artifact.

## Gates

These are sequenced — do not skip ahead with claimed verification.

1. **Template fit** — Before copying. **Pass:** You can name the document type in one phrase ("two-column IEEE conference paper", "ATS-safe one-page CV") and explain why the chosen template matches.
2. **Compile to PDF** — Before reporting work complete. **Pass:** `compile_latex.sh` exits 0 and the `.pdf` exists at the expected path. Re-run with `--verbose` if there are warnings you can't account for.
3. **Long-form audit** — When the rendered PDF is 5+ pages. **Pass:** `beagle-latex:latex-code-review` has been run and findings either fixed or explicitly accepted.
4. **No placeholder leakage** — Before delivery. **Pass:** `grep` for `FULL NAME`, `\[Industry`, `Lorem ipsum`, `placeholder`, `TODO` in the source returns nothing relevant. Search every template-derived file you generated.

## Common pitfalls

- **`<` and `>` in text mode** render as inverted Spanish punctuation. Use `$<$` / `$>$` or `\textless` / `\textgreater`. The compile script does not catch this — `latex-code-review` does.
- **Naked floats** (`\begin{figure}` with no placement specifier) default to `[tbp]` and float around in unpredictable ways. Add `[htbp]` or use `--auto-fix`.
- **`\newpage` before every `\section`** wastes pages. See anti-pattern #2 in `beagle-latex:latex-code-review`.
- **Image widths at `0.95\textwidth`** consume the page and push surrounding text. Default to `0.75–0.85`.
- **First-time bibliography compile** typically needs at least 3 LaTeX passes (or one `latexmk` run). The bundled script handles this when it detects `\bibliography{}` or `\addbibresource{}`.

## Output format

The user gets:
- The cleaned `.tex` source at the chosen path
- The compiled `.pdf` alongside it
- (If `--preview`) one PNG per page
- A one-line summary stating engine used, passes run, page count, any unresolved warnings

State explicitly which compile flags you used and whether you ran `latex-code-review`. Don't claim "done" with errors outstanding.
