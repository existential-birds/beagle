# Failure Modes

Four failure cases the skill handles explicitly. Silent failures are the worst kind — every rule below exists to make a failure visible to the caller and preserve what succeeded.

## Partial success

One or more subagents fail; others return valid findings.

**Behavior:** continue with the successful findings. Do not abort the run.

In the synthesis file, under `Gaps & Limitations`, enumerate every failed subtopic:

- Name the subtopic.
- Include the subagent's last-known brief (or a one-line summary of what it was asked to establish).
- Include the `reason` line from the stub findings file (see "Silent-failure detection" below).

Example:

```markdown
## Gaps & Limitations

- **Subtopic "Enterprise pricing history"** (status: failed) — subagent returned "WebFetch timeout after 3 retries on docs.acme.example/pricing". Caller may retry this subtopic alone, or re-run with `refresh: true` after the outage clears.
```

## Fail-fast on missing web tools

`WebSearch` is the core tool for this skill. If `WebSearch` (or equivalent) is not available in the environment, the skill aborts **before** spawning any subagent. It also does not write `plan.md` — nothing lands on disk.

`WebFetch` is desirable for subagents that want full-page content beyond search snippets, but not required. Environments with `WebSearch` only can still produce useful findings; each subagent notes in its findings file any claim it would have strengthened with full-page access.

Return shape (structured so parent skills can detect and branch):

```json
{
  "error": "web-tools-unavailable",
  "detail": "missing: WebSearch"
}
```

Parent skills (`prfaq-beagle`, `brainstorm-beagle`, `strategy-interview`) catch this and trigger their own graceful-degradation path — typically asking the user to paste research findings instead.

Verification runs at the very start of the skill, before slug derivation and before any file I/O.

## Silent-failure detection (stub-file rule)

Context exhaustion and tool errors can cause a subagent to return without producing any output file. The orchestrator has no way to distinguish that from "the subagent finished but the file is missing for some other reason" — so the contract requires every subagent to write at least a stub file before returning.

**Contract (enforced by `subagent-brief.md`):**

- Every subagent writes `findings/<subtopic-slug>.md` with a `status:` frontmatter field: `ok`, `empty`, or `failed`.
- On `empty` or `failed`, the file includes a one-line `reason:` field.
- On `ok`, `reason` is omitted.

**Orchestrator check, post-dispatch:**

For every expected subtopic, test that the findings file exists. For any missing file, record a silent-failure entry under `Gaps & Limitations`:

```markdown
- **Subtopic "<name>"** — subagent returned without producing a findings file (likely context exhaustion or tool error). Last known brief: "<brief summary>".
```

This is why "legitimately empty" results must use `status: empty` with a reason rather than writing nothing — so empty-but-ok is never confused with silent context loss.

## Re-run protection

Each run is supposed to be self-contained and auditable. Silently overwriting a prior run destroys the audit trail; silently appending produces incoherent findings.

**Rule:** before writing anything to `output_dir`, check whether it already contains `plan.md` or `report.md`.

- **If it does and `refresh` is not `true`:** refuse with a message naming the existing folder.

  ```
  Refusing to write: <output_dir> already contains a prior research run. Pass `refresh: true` to archive and overwrite, or choose a different output_dir.
  ```

- **If it does and `refresh: true`:** move the existing contents to `<output_dir>/.archive-<YYYYMMDD-HHMMSS>/` first, then proceed with a fresh run. The archive preserves the audit trail.

- **If it does not:** proceed normally.

This rule applies even when the default slug matches a prior run on the same day — stable slugs are a feature (callers can re-derive the folder), but the user must explicitly opt in to overwriting.

## Verification checklist (orchestrator runs at end)

Before returning success to the caller, verify:

- [ ] `plan.md` exists at `<output_dir>/plan.md`.
- [ ] `findings/<slug>.md` exists for every subtopic in `plan.md`.
- [ ] Every findings file has `status:` frontmatter.
- [ ] Every `status: empty` or `status: failed` file has a `reason:` line.
- [ ] `report.md` exists at `<output_dir>/report.md`.
- [ ] `report.md` has all four top-level sections in order: `TL;DR`, `Findings`, `Gaps & Limitations`, `Sources`.
- [ ] Every `[^n]` footnote in `report.md` has a matching entry in `Sources`.

Any check that fails becomes an entry in `Gaps & Limitations` — the run does not silently produce a broken deliverable.
