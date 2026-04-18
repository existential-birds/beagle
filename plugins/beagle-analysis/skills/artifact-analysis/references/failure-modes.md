# Failure Modes

Four failure cases the skill handles explicitly. Silent failures are the worst kind — every rule below exists to make a failure visible to the caller and preserve what succeeded.

Unlike `web-research`, artifact-analysis does **not** fail-fast on missing tools. Filesystem tooling (Read, Glob, Grep) is assumed present in the Claude Code environment. If it is somehow absent, that surfaces as a per-subagent failure under partial-success rather than aborting the whole run.

## Partial success

One or more subagents fail; others return valid findings.

**Behavior:** continue with the successful findings. Do not abort the run.

In `report.md`, under `Gaps & Limitations`, enumerate every failed slice:

- Name the slice.
- Include the subagent's last-known brief (or a one-line summary of what it was asked to scan).
- Include the `reason` line from the stub findings file (see "Silent-failure detection" below).

Example:

```markdown
## Gaps & Limitations

- **Slice "planning-folder"** (status: failed) — subagent returned "Read timeout on .planning/phase-3/PLAN.md after 3 retries". Caller may retry this slice alone, or re-run with `refresh: true` after investigating the file.
```

## Empty corpus

Path resolution (auto-discovery + explicit paths) yields zero readable documents after the skip denylist is applied.

**Behavior:** do not spawn subagents. Return cleanly.

The skill writes:

- `plan.md` with an empty `Resolved paths` list and a note that no readable documents were found.
- `report.md` with every section present but containing a single bullet each, plus a `Gaps & Limitations` entry:

```markdown
## Gaps & Limitations

- No readable documents found under the resolved paths. The caller passed <paths> and auto-discovery surfaced <auto-discovered paths>; every entry was either absent, empty, or matched the skip denylist. Pass a broader `paths` list, or point at a different folder.
```

Returning cleanly lets callers handle "no documents found" gracefully (e.g. fall back to asking the user to paste content) rather than crashing on an expected-but-uncommon state.

## Silent-failure detection (stub-file rule)

Context exhaustion and tool errors can cause a subagent to return without producing any output file. The orchestrator has no way to distinguish that from "the subagent finished but the file is missing for some other reason" — so the contract requires every subagent to write at least a stub file before returning.

**Contract (enforced by `subagent-brief.md`):**

- Every subagent writes `findings/<slice-slug>.md` with a `status:` frontmatter field: `ok`, `empty`, or `failed`.
- On `empty` or `failed`, the file includes a one-line `reason:` field.
- On `ok`, `reason` is omitted.

**Orchestrator check, post-dispatch:**

For every expected slice, test that the findings file exists. For any missing file, record a silent-failure entry under `Gaps & Limitations`:

```markdown
- **Slice "<name>"** — subagent returned without producing a findings file (likely context exhaustion or tool error). Last known brief: "<brief summary>".
```

This is why "legitimately empty" results must use `status: empty` with a reason rather than writing nothing — so empty-but-ok is never confused with silent context loss.

## Re-run protection

Each run is supposed to be self-contained and auditable. Silently overwriting a prior run destroys the audit trail; silently appending produces incoherent findings.

**Rule:** before writing anything to `output_dir`, check whether it already contains `plan.md` or `report.md`.

- **If it does and `refresh` is not `true`:** refuse with a message naming the existing folder.

  ```
  Refusing to write: <output_dir> already contains a prior analysis run. Pass `refresh: true` to archive and overwrite, or choose a different output_dir.
  ```

- **If it does and `refresh: true`:** move the existing contents to `<output_dir>/.archive-<YYYYMMDD-HHMMSS>/` first, then proceed with a fresh run. The archive preserves the audit trail.

- **If it does not:** proceed normally.

This rule applies even when the default slug matches a prior run on the same day — stable slugs are a feature (callers can re-derive the folder), but the user must explicitly opt in to overwriting.

## Verification checklist (orchestrator runs at end)

Before returning success to the caller, verify:

- [ ] `plan.md` exists at `<output_dir>/plan.md`.
- [ ] `findings/<slice-slug>.md` exists for every slice in `plan.md` (unless the empty-corpus path was taken).
- [ ] Every findings file has `status:` frontmatter.
- [ ] Every `status: empty` or `status: failed` file has a `reason:` line.
- [ ] `report.md` exists at `<output_dir>/report.md`.
- [ ] `report.md` has all seven top-level sections in order: `Documents Found`, `Key Insights`, `User / Market Context`, `Technical Context`, `Ideas & Decisions`, `Raw Detail Worth Preserving`, `Gaps & Limitations`.
- [ ] `report.md` has a `Sources` section and every `[^n]` footnote in the body has a matching entry.

Any check that fails becomes an entry in `Gaps & Limitations` — the run does not silently produce a broken deliverable.
