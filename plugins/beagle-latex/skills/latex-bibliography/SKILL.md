---
name: latex-bibliography
description: Manages BibTeX, biblatex, and biber bibliographies in LaTeX documents — fetches entries from DOIs and arXiv IDs, picks the right backend (`natbib` + bibtex vs `biblatex` + biber), audits for undefined citations and key collisions, and enforces style consistency. Use when adding citations to a paper, building a `.bib` file, debugging "Citation 'X' undefined" warnings, or hardening reference hygiene before submission.
---

# LaTeX Bibliography

Citations have two layers: the bibliography backend (bibtex / biber) and the citation package on the LaTeX side (`natbib` / `biblatex`). Pick once, stay consistent.

## Decision: bibtex + natbib vs biber + biblatex

**Use `biber` + `biblatex`** for new work. UTF-8 native, robust against complex name patterns, supports `\cite[prenote][postnote]` and per-entry overrides.

```latex
\usepackage[backend=biber, style=authoryear, natbib=true]{biblatex}
\addbibresource{references.bib}
% ...
\printbibliography
```

**Use `bibtex` + `natbib`** when targeting a journal style (`plainnat`, `apalike`, `ieeetr`) that expects bibtex, or when working in a long-running project that already does. Faster than biber for small bibliographies.

```latex
\usepackage{natbib}
\bibliographystyle{plainnat}
% ...
\bibliography{references}
```

The compile script (`beagle-latex:latex-document`) auto-detects which backend a document uses by looking for `\bibliography{...}` (bibtex) vs `\addbibresource{...}` (biber).

## Fetching entries

Use the bundled script to pull BibTeX from doi.org or arXiv:

```bash
bash <skill_path>/scripts/fetch_bibtex.sh 10.1038/nature12373
bash <skill_path>/scripts/fetch_bibtex.sh 2301.07041 --output references.bib
bash <skill_path>/scripts/fetch_bibtex.sh 10.1145/3290605.3300608 1906.08237 --append --output refs.bib
```

The DOI path uses `https://doi.org/<id>` with `Accept: application/x-bibtex`. The arXiv path uses `https://arxiv.org/bibtex/<id>`. Both validate the response contains `@` before writing. Failed fetches do not corrupt the output file.

After fetching, normalize the keys to a consistent style — most projects use `<lastname><year>` (`smith2024`) or `<lastname><year><kwd>` (`smith2024agents`). Don't keep the upstream key (`Anders_2023_unique_id`) if it doesn't match your house style.

## Citation hygiene checklist

Before submission, verify:

1. **Every `\cite{key}` has a matching entry.** Run a compile pass and check the log for `Citation 'X' undefined`. The compile script surfaces these explicitly. Common cause: typo in the key, or the entry exists in a `.bib` file that wasn't `\addbibresource{}`'d.
2. **No orphan entries.** Entries in your `.bib` that nothing cites bloat the file but won't appear in the bibliography (with default styles). Track them down with `bibcheck` or grep:
   ```bash
   for key in $(grep -oE '@\w+\{[^,]+' refs.bib | sed 's/^@\w*{//'); do
     grep -q "\\\\cite[a-z]*{[^}]*\\b${key}\\b" *.tex || echo "Orphan: $key"
   done
   ```
3. **DOI / URL on every entry that has one.** Modern journals require it; reviewers check. The fetch script populates DOIs automatically; arXiv entries get `eprint` and `archivePrefix`.
4. **Author name consistency.** "J. Smith" vs "John Smith" vs "Smith, J." all appear differently in the rendered bibliography depending on style. Standardize at ingestion time, not at render time.
5. **Capitalization of titles.** BibTeX styles often lowercase titles unless braces protect proper nouns. `title={A Survey of {NLP} Methods}` keeps `NLP` uppercase; `title={A Survey of NLP Methods}` may render `nlp`.
6. **No duplicate entries with different keys.** Two `@article` entries for the same paper produce a confused bibliography. The fetch script does not dedupe — check by hand on first ingest.

## Common errors and fixes

| Symptom | Cause | Fix |
|---|---|---|
| `Citation 'foo' undefined` | Key typo, or `.bib` not loaded | Verify key spelling; ensure `\addbibresource` or `\bibliography` is present |
| `Empty thebibliography environment` | Bibtex/biber didn't run, or no `\cite` calls | Re-run with multi-pass; confirm `\printbibliography` is in the document |
| `Package biblatex Warning: '...' in 'name'` | Special characters (umlauts, accents) | Use UTF-8 in the `.bib` file with `biber`, or escape: `J\"urgen` |
| `Repeated entry 'foo'` | Same key in two entries | Rename one or remove duplicate |
| Author renders as "Smith, J. and J. Doe" mid-sentence | Wrong style | Use `\citeauthor{}` or `\citet{}` (natbib) / `\textcite{}` (biblatex) |
| Title appears all-lowercase | BibTeX style lowercased it | Wrap proper nouns in braces: `title={... {GPU} ...}` |

## Style picker (when to use which)

| Document type | Style |
|---|---|
| Computer science (general) | `plainnat` (bibtex) or `numeric-comp` (biblatex) |
| ACM / SIGCHI | `acm`, `acmart` |
| IEEE | `ieeetr` (bibtex) — use the `IEEEtran` template in `latex-document` |
| Sciences (Nature, Science) | `unsrtnat` (numbered, in citation order) |
| Humanities, social sciences | `apa` (biblatex-apa) or `apalike` (bibtex) |
| Bibliographies with footnotes | `chicago-authordate-trad` (biblatex-chicago) |

When the user names a target venue, set the style accordingly. When they don't, ask — the choice is hard to reverse once entries are tuned to a particular style's expected fields.

## Gates

1. **Backend chosen** — Before adding any bibliography code. **Pass:** You stated whether the document uses `bibtex+natbib` or `biber+biblatex` and confirmed by reading the existing preamble or asking the user.
2. **All cites resolve** — Before reporting bibliography work complete. **Pass:** Compile log contains no `Citation '...' undefined`. Run via `beagle-latex:latex-document`'s compile script which surfaces these warnings.
3. **Style fits the venue** — Before submission. **Pass:** The bibliographystyle (or `\usepackage[style=...]{biblatex}`) matches the target venue's published guidelines. If no venue, ask the user.
