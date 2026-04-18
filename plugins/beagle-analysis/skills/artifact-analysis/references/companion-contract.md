# Companion Invocation Contract

Other beagle skills invoke `artifact-analysis` via this contract. It is small on purpose — no required inputs (!), three optional parameters for scoping and one for overwrite control, two return shapes.

Callers are expected to honor the contract verbatim rather than invent parallel invocation styles. If a new caller needs behavior that the contract does not support, extend the contract here first, not in the calling skill.

## Minimal call

```yaml
# No parameters at all — auto-discover every beagle knowledge location, generic-salient-extraction mode.
```

With no inputs, the skill scans `.beagle/concepts/`, `.planning/`, `docs/`, and top-level README/brief/overview files, applies the default skip denylist, and extracts anything structurally important. Output lands at `.beagle/analysis/<YYYY-MM-DD>-<first-path-basename>/`.

## Full call

```yaml
intent: "competitive and technical grounding for PRFAQ on AI coding-assistant pricing"
paths:
  - .beagle/concepts/ai-coding-pricing/
  - docs/
output_dir: "/abs/path/.beagle/concepts/ai-coding-pricing/analysis/"
refresh: false
```

## Input semantics

- **`intent`** — one string describing what the caller wants. When present, extraction is weighted toward relevance to the intent. When absent, the skill runs in generic-salient-extraction mode. Tone-neutral; the skill does not reshape the intent.
- **`paths`** — directories and/or explicit files. When absent or empty, the skill auto-discovers beagle's conventional knowledge locations (see SKILL.md §Auto-discovery). When present, only the listed paths are scanned — auto-discovery does not run.
- **`output_dir`** — absolute path. Callers embedding artifact-analysis in their own concept folder (e.g. `prfaq-beagle`) pass this explicitly so the analysis sits next to its consumer.
- **`refresh`** — when `true`, a prior run in `output_dir` is archived to `<output_dir>/.archive-<timestamp>/` before the new run starts. See `failure-modes.md` for the archive rule.

## Return shapes

This skill returns one of two shapes. Callers that invoke multiple beagle companions should handle the union of error codes across all companions they call — sibling companions (e.g. `web-research`) may return different error codes (notably `web-tools-unavailable`).

- **success** — artifacts written. An empty-corpus run still returns this shape with a minimal `report.md`; the caller detects empty-corpus by reading the report, not by catching an error.
- **error: `prior-run-present`** — `output_dir` already holds a prior run and `refresh` is false; nothing written.

### Success

```yaml
plan: "<output_dir>/plan.md"
report: "<output_dir>/report.md"
findings_dir: "<output_dir>/findings/"
```

The caller receives absolute paths. All evidence lives on disk — nothing returns inline.

### Success with empty corpus

Empty-corpus is **not** an error. When path resolution yields zero readable documents, the skill still returns the Success shape above: `plan.md` exists (with an empty `Resolved paths` list), `report.md` exists (with every section present plus a `Gaps & Limitations` entry explaining no readable documents were found), and `findings_dir` exists (empty). Callers detect empty-corpus by reading `report.md`, not by catching an error.

### Refused (prior run present, no refresh)

```yaml
error: "prior-run-present"
detail: "<output_dir> already contains plan.md or report.md. Pass refresh: true to archive and overwrite."
```

The caller decides whether to retry with `refresh: true`, pick a different `output_dir`, or surface the refusal to its user.

## Worked examples

### `prfaq-beagle` — Ignition grounding

The PRFAQ's Ignition phase needs competitive and technical grounding from the user's own documents (PRDs, briefs, prior decisions). PRFAQ passes:

```yaml
intent: "competitive and technical grounding for PRFAQ on AI coding-assistant pricing"
paths: []  # empty → auto-discover .beagle/concepts/, .planning/, docs/
output_dir: "/abs/path/.beagle/concepts/ai-coding-pricing/analysis/"
refresh: false
```

Empty `paths` triggers auto-discovery so PRFAQ does not have to know where the user keeps briefs. `output_dir` lands inside the PRFAQ concept folder so the audit trail travels with the concept.

### `brainstorm-beagle` — reference-point grounding

Mid-brainstorm, the user says "go read the docs folder and tell me what we already decided." Brainstorm calls:

```yaml
intent: "prior decisions and reference points relevant to the current idea"
paths:
  - docs/
  - .beagle/concepts/
output_dir: "/abs/path/.beagle/concepts/task-sub-tasks/analysis/"
refresh: false
```

Explicit `paths` keeps the scan narrow. `output_dir` lands inside the brainstorm concept folder so the reference points can link straight to `report.md`.

### `strategy-interview` — context grounding

During strategy interview Phase 1 discovery, the user needs a structured read of prior strategy artifacts. Strategy-interview calls:

```yaml
intent: "background context for platform-team H1 2026 strategy discovery"
paths:
  - .beagle/strategy/
  - docs/
output_dir: "/abs/path/.beagle/strategy/platform-team-h1-2026/analysis/"
refresh: false
```

`output_dir` lands inside the strategy interview's working-state folder so the analysis sits alongside `state.md`, `evidence.md`, and `composition.md`.

### Standalone user — "analyze these docs"

A user types "read everything in docs/ and tell me what's there" with no prior context. The skill is triggered directly and runs:

```yaml
# Triggered by user chatter. No intent passed → generic-salient-extraction mode.
paths:
  - docs/
# output_dir defaults to .beagle/analysis/<YYYY-MM-DD>-docs/
```

The user gets a `report.md` they can open immediately — no caller-specific wrapping.

## Non-obligations

The contract is explicit about what this skill does **not** do:

- **No intent reshaping.** The caller hands in an intent (or nothing). The skill does not argue with it, sharpen it, or reframe it.
- **No coaching posture.** `artifact-analysis` is tone-neutral. Callers that need a coaching tone (`prfaq-beagle`'s hardcore coach, `brainstorm-beagle`'s thinking partner) apply that tone before and after, not inside.
- **No inline findings.** Every deliverable is a file. Callers that want inline prose should summarize from `report.md` themselves.
- **No cross-run caching.** Each invocation stands alone. Callers that need caching build it themselves at the call site.
- **No doc editing or rewriting.** Read-only by design.

## Extending the contract

If a new caller needs behavior not covered here, add a field to the input table in SKILL.md first, document it in this file with a worked example, then update caller skills to use it. Parallel-invocation styles fragment the contract and re-introduce the reason this skill exists.
