# beagle-latex

LaTeX document creation, code review, and bibliography hygiene skills for [Claude Code](https://claude.ai/code). Part of the [beagle](https://github.com/existential-birds/beagle) plugin marketplace.

Covers single-file LaTeX documents (resumes, articles, reports, beamer slides, IEEE submissions, single-volume books) with auto-detected engine selection, BibTeX/biblatex/biber citation hygiene, and a code-review skill that catches the long-form anti-patterns LLM-generated LaTeX usually ships with.

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

## External tooling

These skills wrap, but do not install, standard LaTeX tooling. Install once:

```bash
# macOS
brew install --cask mactex                   # full TeX Live
brew install poppler pandoc latexmk          # PNG previews, conversions, multi-pass

# Debian / Ubuntu
sudo apt-get install texlive-full poppler-utils pandoc latexmk
```

The scripts check for missing binaries and print install instructions rather than running `apt-get` or `brew install` themselves.

## PostToolUse hook recipe — auto-compile on `.tex` edit

Drop this into your project's `.claude/settings.json` to recompile on every Edit/Write to a `.tex` file. Pair with `\includeonly{<chapter>}` in your root `.tex` so the loop stays fast on long documents.

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "if [[ \"$CLAUDE_TOOL_INPUT_file_path\" =~ \\.tex$ ]]; then cd \"$(dirname \"$CLAUDE_TOOL_INPUT_file_path\")\" && latexmk -pdf -interaction=nonstopmode -silent \"$(basename \"$CLAUDE_TOOL_INPUT_file_path\")\" 2>&1 | tail -20 || true; fi"
          }
        ]
      }
    ]
  }
}
```

For pre-commit mirroring, see [jonasbb/pre-commit-latex-hooks](https://github.com/jonasbb/pre-commit-latex-hooks).

Hook docs: <https://docs.claude.com/en/docs/claude-code/hooks>.

## See Also

- [beagle-core](../beagle-core) — verification protocol that `latex-code-review` hooks into
- [beagle-docs](../beagle-docs) — Markdown/prose documentation skills (Diataxis-aligned, complement rather than overlap)
- [beagle marketplace](https://github.com/existential-birds/beagle) — full plugin catalog
