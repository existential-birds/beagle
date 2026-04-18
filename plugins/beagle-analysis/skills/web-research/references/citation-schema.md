# Citation Schema

Every claim in a findings file and in `report.md` carries a citation. The shape is small on purpose — enough metadata to verify without clicking, not so much that subagents start fabricating fields.

## Required fields

- **`url`** — the exact page the claim was drawn from. No redirectors, no homepage-in-place-of-article substitutions.
- **`title`** — the page's own title, as rendered (not the domain, not a paraphrase).
- **`excerpt`** — a verbatim quoted string from the page that supports the claim. Keep it short enough to read at a glance (typically 1-3 sentences), long enough to stand on its own.

If any required field is missing or would have to be fabricated, do not include the citation. Drop the claim or mark it as unverified in `Gaps & Limitations`.

## Optional fields

Include only when the subagent naturally has them. Never synthesize.

- **`retrieved_at`** — ISO date (`YYYY-MM-DD`) the page was fetched. Useful for time-sensitive claims (pricing, availability, current events).
- **`source_type`** — one of:
  - `official-docs` — vendor/project documentation.
  - `vendor` — vendor marketing, press, or blog under the vendor's own domain.
  - `blog` — third-party blog or personal site.
  - `forum` — discussion board, Q&A site, mailing list archive.
  - `news` — press coverage from a recognized news outlet.
  - `other` — anything that doesn't fit (academic paper, standards body, regulator filing).

Omit fields you do not have. An incomplete citation with three real fields beats a five-field citation with two guessed values.

## Footnote convention

In findings and in `report.md`, claims use `[^n]` inline footnote markers:

```markdown
Pricing for the enterprise tier starts at $20k/year with a 25-seat minimum[^3].
```

The numbered `Sources` section at the bottom of `report.md` lists each citation in order, matching the footnote number. Numbering is global across the report, not per-section.

## Example — well-formed citation block

In `report.md`, the `Sources` section entries look like this:

```markdown
[^1]: **Title**: Enterprise Pricing — Acme Docs
      **URL**: https://docs.acme.example/pricing/enterprise
      **Excerpt**: "Enterprise plans start at $20,000 per year and require a 25-seat minimum commitment."
      **Retrieved**: 2026-04-18
      **Source type**: official-docs

[^2]: **Title**: Acme raises Series C at $2B valuation
      **URL**: https://news.example/acme-series-c
      **Excerpt**: "The round, led by Example Partners, brings total funding to $340M."
      **Source type**: news
```

Citation `[^2]` omits `Retrieved` because the subagent did not record a retrieval date. That is correct behavior — omit rather than guess.

## Incomplete-metadata policy

If a claim is genuinely load-bearing but the source lacks one of the optional fields (e.g. a news article without a clear publication date), keep the citation with what exists. If a claim depends on freshness and no retrieval date is available, note the uncertainty in `Gaps & Limitations` rather than citing confidently.
