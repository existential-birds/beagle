# beagle-latex

LaTeX document creation, code review, and book authoring skills for [Claude Code](https://claude.ai/code). Part of the [beagle](https://github.com/existential-birds/beagle) plugin marketplace.

Covers single-file documents (resumes, articles, reports), book-length multi-chapter projects via Quarto, elegant textbook typography with kaobook, citation hygiene, and a code-review skill that catches the long-form anti-patterns LLM-generated LaTeX usually ships with.

## Installation

```bash
# Add the marketplace (if not already added)
claude plugin marketplace add https://github.com/existential-birds/beagle

# Install the plugin
claude plugin install beagle-latex@existential-birds
```

## Skills

| Skill | Purpose |
|-------|---------|
| **latex-document** | Create, edit, and compile single-file LaTeX documents (article, report, resume, beamer, IEEE, book). Bundles `compile_latex.sh` and 6 cleaned templates. |
| **latex-code-review** | Audit `.tex` sources for the 9 long-form anti-patterns, encoding bugs, missing packages, float misuse, and hardcoded dimensions. `[FILE:LINE] ISSUE_TITLE` format. |
| **latex-bibliography** | BibTeX/biblatex/biber patterns plus citation hygiene: DOI/arXiv fetch, undefined-cite detection, style consistency. |
| **latex-compilation** | latexmk, `\include`/`\includeonly` for fast incremental builds, log parsing, error recovery. |
| **quarto-book** | Quarto book project workflow — `_quarto.yml`, chapter-per-`.qmd`, render orchestration, kaobook bridge template. |
| **textbook-typography** | Class selection: kaobook (recommended), Eisvogel + scrbook (fallback), tufte-book. Sidenotes, margin design, `pandoc-sidenote` filter. |

## External tooling

These skills wrap, but do not install, standard LaTeX tooling. Install once:

```bash
# macOS
brew install --cask mactex                   # full TeX Live
brew install poppler pandoc latexmk          # PNG previews, conversions, multi-pass
brew install quarto                          # for quarto-book skill

# Debian / Ubuntu
sudo apt-get install texlive-full poppler-utils pandoc latexmk
# Quarto: download .deb from https://quarto.org/docs/get-started/
```

The scripts check for missing binaries and print install instructions rather than running `apt-get` or `brew install` themselves.

## PostToolUse hook recipe — auto-compile on `.tex` / `.qmd` edit

Drop this into your project's `.claude/settings.json` to recompile the touched chapter on every Edit/Write. Pair with `\includeonly{<chapter>}` in your root `.tex` (or per-chapter `quarto render <file>`) so the loop stays fast on book-length projects.

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "if [[ \"$CLAUDE_TOOL_INPUT_file_path\" =~ \\.(tex|qmd)$ ]]; then cd \"$(dirname \"$CLAUDE_TOOL_INPUT_file_path\")\" && latexmk -pdf -interaction=nonstopmode -silent \"$(basename \"$CLAUDE_TOOL_INPUT_file_path\" .qmd).tex\" 2>&1 | tail -20 || true; fi"
          }
        ]
      }
    ]
  }
}
```

For Quarto book projects, swap `latexmk` for `quarto render <file>`. For pre-commit mirroring, see [jonasbb/pre-commit-latex-hooks](https://github.com/jonasbb/pre-commit-latex-hooks).

Hook docs: <https://docs.claude.com/en/docs/claude-code/hooks>.

## See Also

- [beagle-core](../beagle-core) — verification protocol that `latex-code-review` hooks into
- [beagle-docs](../beagle-docs) — Markdown/prose documentation skills (Diataxis-aligned, complement rather than overlap)
- [beagle marketplace](https://github.com/existential-birds/beagle) — full plugin catalog
