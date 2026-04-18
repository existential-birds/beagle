# Citation Schema

Every claim in a findings file and in `report.md` carries a citation. The shape is small on purpose — enough metadata to verify without re-reading the full document, not so much that subagents start fabricating fields.

## Required fields

- **`path`** — the document the claim was drawn from. Relative to the scanned root when possible (e.g. `docs/architecture.md`); absolute only when the path lives outside the scanned tree.
- **`excerpt`** — a verbatim quoted string from the document that supports the claim. Keep it short enough to read at a glance (typically 1-3 sentences), long enough to stand on its own.

If either required field is missing or would have to be fabricated, do not include the citation. Drop the claim or mark it as unverified in `Gaps & Limitations`.

## Optional fields

Include only when the subagent naturally has them. Never synthesize.

- **`lines`** — line range (`L42-L58`) or single line (`L42`) where the excerpt appears. Include when reading a text/markdown file with stable line numbers. Omit for documents where line granularity is ambiguous (prose documents without visible line numbers, transcluded markdown, rendered output). Never guess.
- **`heading`** — the nearest enclosing heading, copied verbatim. Useful for anchoring the reader in long documents.
- **`document_type`** — one of:
  - `spec` — specification, requirements doc, or formal brief.
  - `adr` — architecture decision record.
  - `readme` — README, overview, or project-root context doc.
  - `planning` — roadmap, state, phase, or plan artifact.
  - `concept` — beagle concept spec or analysis.
  - `transcript` — meeting notes, interview transcript, or chat log.
  - `other` — anything that does not fit.

Omit fields you do not have. An incomplete citation with two real fields beats a five-field citation with three guessed values.

## Footnote convention

In findings and in `report.md`, claims use `[^n]` inline footnote markers:

```markdown
The skill must not pause for user confirmation before spawning subagents[^3].
```

The numbered `Sources` section at the bottom of `report.md` lists each citation in order, matching the footnote number. Numbering is global across the report, not per-section.

## Example — well-formed citation block

In `report.md`, the `Sources` section entries look like this:

```markdown
[^1]: **Path**: .beagle/concepts/artifact-analysis/spec.md
      **Excerpt**: "Partial-success behavior: if a subagent fails, the skill continues with the remaining findings and records the failure explicitly under Gaps & Limitations."
      **Lines**: L29
      **Heading**: Requirements
      **Document type**: spec

[^2]: **Path**: docs/architecture.md
      **Excerpt**: "All long-running jobs run on the worker queue, never the request thread."
      **Heading**: Background Processing
      **Document type**: readme
```

Citation `[^2]` omits `Lines` because the subagent did not have a stable line-number anchor. That is correct behavior — omit rather than guess.

## Incomplete-metadata policy

If a claim is genuinely load-bearing but the document lacks a clear line number or heading, keep the citation with the required fields (`path` + `excerpt`) only. Do not invent a line number to satisfy a schema slot. If the absence makes the claim hard to verify, note the uncertainty in `Gaps & Limitations` rather than citing confidently.
