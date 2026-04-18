# Companion Invocation Contract

Other beagle skills invoke `web-research` via this contract. It is small on purpose — one required input, three optional parameters, three return shapes.

Callers are expected to honor the contract verbatim rather than invent parallel invocation styles. If a new caller needs behavior that the contract does not support, extend the contract here first, not in the calling skill.

## Minimal call

```yaml
research_question: "How do enterprise observability vendors price their logs tier in 2026?"
```

The skill derives `output_dir` as `.beagle/research/<YYYY-MM-DD>-<topic-kebab>/` per the slug rule in SKILL.md, runs the plan review gate (default `auto_proceed: false`), and refuses if a prior run exists in the same folder (default `refresh: false`).

## Full call

```yaml
research_question: "How do enterprise observability vendors price their logs tier in 2026?"
output_dir: "/abs/path/to/output"
auto_proceed: false
refresh: false
```

## Input semantics

- **`research_question`** — one sharp question, already distilled by the caller. The skill does not reshape it. If the caller has a multi-part question, pick the single most important one; the skill's subtopics will break it down.
- **`output_dir`** — absolute path. If the caller wants artifacts next to its own work (e.g. under `.beagle/concepts/<slug>/research/`), it sets this explicitly.
- **`auto_proceed`** — when `true`, the plan review gate is skipped and dispatch happens immediately. Use this in programmatic-companion paths where the caller has its own review loop.
- **`refresh`** — when `true`, a prior run in `output_dir` is archived to `<output_dir>/.archive-<timestamp>/` before the new run starts. See `failure-modes.md` for the archive rule.

## Return shapes

This skill returns one of three shapes. Callers that invoke multiple beagle companions should handle the union of error codes across all companions they call — sibling companions (e.g. `artifact-analysis`) may return different error codes.

- **success** — all artifacts written.
- **error: `web-tools-unavailable`** — missing `WebSearch`; nothing written.
- **error: `prior-run-present`** — `output_dir` already holds a prior run and `refresh` is false; nothing written.

### Success

```yaml
plan: "<output_dir>/plan.md"
report: "<output_dir>/report.md"
findings_dir: "<output_dir>/findings/"
```

The caller receives absolute paths. All evidence lives on disk — nothing returns inline.

### Fail-fast (web tools unavailable)

```yaml
error: "web-tools-unavailable"
detail: "missing: WebSearch, WebFetch"
```

The caller catches this and triggers its own graceful-degradation path. No files are written in this case — not even `plan.md`.

### Refused (prior run present, no refresh)

```yaml
error: "prior-run-present"
detail: "<output_dir> already contains plan.md or report.md. Pass refresh: true to archive and overwrite."
```

The caller decides whether to retry with `refresh: true`, pick a different `output_dir`, or surface the refusal to its user.

## Worked examples

### `prfaq-beagle` — Ignition grounding

The PRFAQ's Ignition phase needs competitive and market grounding. PRFAQ distills the ambiguity into one research question, then calls `web-research`:

```yaml
research_question: "What AI coding-assistant pricing tiers exist for enterprise teams in 2026, and what features differentiate them?"
output_dir: "/abs/path/.beagle/concepts/ai-coding-pricing/research/"
auto_proceed: false
refresh: false
```

`auto_proceed: false` because the user is in the PRFAQ loop and wants to see the research plan before subagents run. `output_dir` lands inside the PRFAQ concept folder so the audit trail travels with the concept.

### `brainstorm-beagle` — reference-point research

Mid-brainstorm, the user says "go look up how other tools handle this." Brainstorm calls `web-research` with the user's question distilled:

```yaml
research_question: "How do task-tracking tools handle sub-tasks that span multiple top-level projects?"
output_dir: "/abs/path/.beagle/concepts/task-sub-tasks/research/"
auto_proceed: true
refresh: false
```

`auto_proceed: true` because the user explicitly asked for background research mid-brainstorm — they want findings, not another review gate. `output_dir` lands inside the brainstorm concept folder so the spec's reference points can link straight to `report.md`.

### `strategy-interview` — context grounding

During strategy interview Phase 1 discovery, the user needs competitive landscape data. Strategy-interview calls `web-research`:

```yaml
research_question: "Which incumbents dominate the developer-tools observability market, and what is their defensibility story?"
output_dir: "/abs/path/.beagle/strategy/platform-team-h1-2026/research/"
auto_proceed: false
refresh: false
```

`auto_proceed: false` because the strategy interview benefits from the user catching bad subtopic framing before searches burn. `output_dir` lands inside the strategy interview's working-state folder so the research sits alongside `state.md`, `evidence.md`, and `composition.md`.

## Non-obligations

The contract is explicit about what this skill does **not** do:

- **No question reshaping.** The caller hands in a sharp question. If the caller has a fuzzy question, the caller sharpens it before invoking.
- **No coaching posture.** `web-research` is tone-neutral. Callers that need a coaching tone (`prfaq-beagle`'s hardcore coach, `brainstorm-beagle`'s thinking partner) apply that tone before and after, not inside.
- **No inline findings.** Every deliverable is a file. Callers that want inline prose should summarize from `report.md` themselves.
- **No cross-run caching.** Each invocation stands alone. Callers that need caching build it themselves at the call site.

## Extending the contract

If a new caller needs behavior not covered here, add a field to the input table in SKILL.md first, document it in this file with a worked example, then update caller skills to use it. Parallel-invocation styles fragment the contract and re-introduce the reason this skill exists.
