# Spec: artifact-analysis

## Core Value

A reusable document-scanning primitive that turns a set of paths (or a beagle project's conventional knowledge locations) into a cited, structured extraction of insights, context, decisions, and raw detail.

## Problem Statement

Beagle's analysis skills keep needing the same capability: scan a folder of user-provided documents and project knowledge, pull out what's relevant to the work at hand, and hand back a structured summary the caller can act on. Today each skill that wants this either (a) reads files inline and bloats its own SKILL.md + context window, (b) asks the user to paraphrase the artifacts back in chat, or (c) skips grounding entirely and produces ungrounded output.

**Who:** other beagle-analysis skills first (`prfaq-beagle` during Ignition, `brainstorm-beagle` and `strategy-interview` for grounding their discovery), plus direct user invocation for standalone artifact reads ("go read everything in `docs/` and tell me what's there").

**Today:** `prfaq-beagle`'s spec explicitly declares `artifact-analysis` as a required companion for scanning user-provided docs and project knowledge during Ignition. Without it, PRFAQ's Ignition either reads files inline (polluting the coaching context) or asks the user to summarize their own docs.

**Why now:** the `prfaq-beagle` + `web-research` pair is the first beagle workflow where document-scanning and web-research are treated as symmetric primitives. Extracting artifact-analysis now — rather than embedding BMAD's subagent pattern inside PRFAQ — prevents the capability from being re-implemented separately in every analysis skill that follows.

## Requirements

**Must have:**
- Accepts optional `intent` string (what the caller is looking for / why) and optional `paths` list (directories and/or explicit files) as primary inputs; optional parameter: `output_dir` (absolute path for all artifacts).
- When `paths` is absent, auto-discover by scanning beagle's conventional knowledge locations: `.beagle/concepts/`, `.planning/`, `docs/`, and top-level README / brief / overview files. The default set is documented in SKILL.md and is tunable per invocation via the `paths` parameter.
- When `intent` is absent, the skill operates in generic-salient-extraction mode — subagents extract anything that looks structurally important (insights, decisions, technical constraints, user/market context) without an interpretive filter. When `intent` is present, extraction is targeted to what's relevant to that intent.
- Produces a written scan plan (`plan.md`) documenting: resolved paths (with any auto-discovery applied), per-subagent briefs, intent summary (if given), skipped patterns (sensitive/binary), and how subagent findings will be synthesized. Written for auditability; the skill does **not** pause for user confirmation before spawning subagents.
- Delegates extraction to 1-3 parallel subagents, each scanning a non-overlapping slice of the resolved paths; each subagent writes findings to `findings/<slice-slug>.md` under the output directory. Findings never return inline.
- Subagent briefs instruct: (a) for sharded documents (folder with `index.md` + multiple files) — read index first, then only relevant parts; (b) for very large documents (>50 pages) — read TOC / executive summary / section headings first and only pull full content from relevant sections, noting in findings what was skimmed vs read fully; (c) skip sensitive patterns (`.env*`, `.git/`, `node_modules/`, `*.pem`, `*.key`, binary files) without the caller needing to specify them.
- Every extracted claim in findings and in the final synthesis carries a citation: source path (relative to the scanned root when possible), and a verbatim quoted excerpt from the document. Line numbers are included when the subagent naturally has them; never synthesized or guessed.
- Final synthesis written to `report.md` with fixed top-level sections in this order: `Documents Found` (path + one-line relevance), `Key Insights` (bullets grouped by theme), `User / Market Context` (users, competition, market data surfaced from docs), `Technical Context` (platforms, constraints, integrations), `Ideas & Decisions` (each tagged `accepted` / `rejected` / `open` with rationale — rejected ideas preserved so future work doesn't re-propose them), `Raw Detail Worth Preserving` (specific quotes / data points / metrics), `Gaps & Limitations` (what the corpus could not establish; which paths were empty or unreadable).
- Output location resolves as: caller-provided `output_dir` if present; otherwise default to `.beagle/analysis/<slug>/` where slug is derived from the intent (or first-scanned-path name when intent is absent) and date-prefixed for uniqueness.
- Partial-success behavior: if a subagent fails, the skill continues with the remaining findings and records the failure explicitly under `Gaps & Limitations`. Does not abort the whole run.
- Empty-corpus behavior: if path resolution (auto-discovery + explicit paths) yields zero readable documents, the skill writes a `report.md` with an explicit "no documents found" entry under `Gaps & Limitations` and returns to the caller without spawning subagents. Callers decide how to proceed.
- Dual-mode exposure: directly invocable by end users ("analyze these docs for me") and programmatically invocable by other beagle skills via the same documented contract.
- SKILL.md documents the companion-invocation contract explicitly so `prfaq-beagle`, `brainstorm-beagle`, and `strategy-interview` can reference it without reinventing the call shape.

**Should have:**
- `Gaps & Limitations` section is required output even when the scan looks complete — forces honest accounting of which paths were empty, skimmed, or unreadable.
- Subagent briefs are derived mechanically from the plan (no interpretation drift) so a caller reading `plan.md` can predict what each subagent was told.
- Resolved-paths list in `plan.md` surfaces any auto-discovery transparently — a caller can tell at a glance which files were actually included vs. skipped.

**Out of scope:**
- Scanning paywalled or authentication-gated remote sources. **Reason:** this is a local-filesystem primitive; `web-research` handles the open web and doesn't chase auth-gated content either.
- LLM-as-judge evaluation of document quality or claim credibility. **Reason:** `llm-judge` already exists for comparative evaluation; artifact-analysis's job is extraction with citations, not adjudication.
- Coaching, challenge, or opinionated framing of the findings. **Reason:** artifact-analysis is a tone-neutral primitive; coaching posture is the caller's job (e.g. PRFAQ's hardcore coach shapes the surrounding conversation).
- Rewriting or editing the scanned documents. **Reason:** read-only by design; `humanize-beagle` and similar skills handle doc editing.
- Binary / image OCR, PDF text extraction, or format conversion. **Reason:** first version reads plain text and markdown; `beagle-core:docling` is the path for richer parsing when needed.
- Multi-language analysis. **Reason:** beagle is English-only today.
- Caching or re-use of prior findings across invocations. **Reason:** each invocation is self-contained and auditable; cross-run caching adds complexity the first version doesn't need.
- Long-running or scheduled scans. **Reason:** synchronous primitive invoked inside a conversation; durable job orchestration is a different skill's concern.

## Constraints

- Lives in `plugins/beagle-analysis/skills/artifact-analysis/` following beagle's skill conventions (SKILL.md under 500 lines, subagent briefs and templates in `references/`, proper frontmatter).
- Dual-mode exposure means frontmatter does **not** set `disable-model-invocation: true`. The skill must be safely triggerable on user chatter ("analyze these docs", "scan my project for context") without breaking the companion contract.
- Depends on the Claude Code environment providing subagent-spawning (the `Task` tool or equivalent) and filesystem tooling (Read, Glob, Grep). Absence of subagent-spawning is a hard requirement; filesystem tooling is assumed present.
- All artifacts (plan, findings, report) must be on-disk and human-readable so a caller weeks later can re-read them without re-running the skill.
- Reusable — no PRFAQ-specific assumptions bleed into the contract. The `intent` parameter is string-typed and tone-neutral; the output structure works for any beagle-analysis caller.

## Key Decisions

1. **Plan → parallel → synthesis shape**, sibling to `web-research`. *Rejected alternatives:* single-subagent direct port of BMAD's artifact-analyzer (cleaner but doesn't scale to large corpora and breaks pattern parity with web-research); hybrid runtime heuristic (unpredictable for callers).
2. **Fixed BMAD-style categories** for the synthesis report (Documents Found, Key Insights, User/Market Context, Technical Context, Ideas & Decisions, Raw Detail, Gaps & Limitations). *Rejected alternatives:* flexible caller-shaped themes (loses rejected-ideas discipline and breaks programmatic consumers); core-plus-optional (ambiguous which sections are always present).
3. **Auto-discovery of conventional beagle knowledge locations** when no paths are passed. *Rejected alternatives:* require explicit paths (forces every caller to re-build the default list); hybrid defaults-only-for-users (two contracts under one skill).
4. **Dual-mode exposure** (user-invocable + companion). *Rejected alternatives:* companion-only (loses the standalone "read my docs" use case that parallels web-research's standalone mode).
5. **Optional `intent` parameter** with generic-salient-extraction fallback. *Rejected alternatives:* required intent (BMAD's approach — stricter but rules out exploratory standalone scans); required-but-auto-derived from a passed brief (implicit behavior harder to document).
6. **No plan review gate by default.** Scanning local documents is cheap; the `plan.md` is written for auditability but the skill does not pause. *Rejected alternatives:* plan gate on by default (correct for web-research where subagents burn searches; overkill here); conditional gate on auto-discovery (adds branching without clear payoff now — see Open Questions).
7. **Caller-parameterized `output_dir` with `.beagle/analysis/<slug>/` default.** Preserves concept-folder convention (PRFAQ passes `.beagle/concepts/<slug>/analysis/`) while giving standalone users a clean home. *Rejected alternatives:* always-flat `.beagle/analysis/<slug>/` (breaks concept-folder convention); inline return (loses auditability).
8. **Citations require source path + verbatim excerpt**, with line numbers when naturally available. *Rejected alternatives:* path-only (weak grounding, can't verify without re-reading); path-plus-line-required (blocks citations when line granularity is ambiguous, e.g., PDFs).
9. **Tone-neutral primitive, no coaching posture.** *Rejected alternatives:* inherit PRFAQ's hardcore tone (over-fits to one caller; breaks reuse).
10. **Partial-success on subagent failure, empty-corpus returns cleanly rather than erroring.** Mirrors web-research's partial-success discipline; diverges from its fail-fast-on-missing-tools rule because filesystem tooling is assumed present in the Claude Code environment. *Rejected alternatives:* abort-on-first-failure (wastes other subagents' work); error-on-empty-corpus (inconvenient — callers can handle "no documents found" gracefully).

## Reference Points

- **BMAD's `artifact-analyzer.md` subagent** (`/Users/ka/github/BMAD-METHOD/src/bmm-skills/1-analysis/bmad-prfaq/agents/artifact-analyzer.md`) — original extraction pattern. Adopts: structured categories (documents found / key insights / user & market context / technical context / ideas & decisions / raw detail worth preserving), sharded-doc handling, large-doc TOC-first strategy, intent-driven relevance filtering, rejected-ideas preservation. Diverges on: standalone skill wrapping 1-3 subagents rather than embedded single-subagent; file-based findings + synthesis report rather than inline JSON return; optional intent rather than required; dual-mode exposure.
- **`web-research` spec** (`.beagle/concepts/web-research/spec.md`) — sibling primitive; same plan → parallel → synthesis shape, same dual-mode exposure, same `.beagle/<kind>/<slug>/` output convention. Diverges on: no plan review gate (local scanning is cheap), optional intent (web-research requires a research question), different fixed sections in the synthesis, no fail-fast rule (filesystem tooling is assumed).
- **`prfaq-beagle` spec** (`.beagle/concepts/prfaq-beagle/spec.md`) — primary caller; establishes the `.beagle/concepts/<slug>/` convention this skill's default output location mirrors (PRFAQ passes `.beagle/concepts/<slug>/analysis/`).
- **Existing beagle-analysis skills** (`plugins/beagle-analysis/skills/brainstorm-beagle/`, `plugins/beagle-analysis/skills/strategy-interview/`, `plugins/beagle-analysis/skills/web-research/` once shipped) — SKILL.md structure, frontmatter conventions, `references/` folder patterns.
- **Claude Code `Task` tool** — subagent-spawning mechanism the skill builds on (exact invocation is a planning-stage concern, not spec'd here).
- **`beagle-core:docling` skill** — referenced as the future path for richer document parsing (PDFs, DOCX) if artifact-analysis later wants to extend beyond plain text and markdown.

## Open Questions

- Slug derivation rule for standalone mode — when intent is present, derive from intent; when absent, derive from the first path's basename. Exact shape (e.g. `YYYY-MM-DD-<topic-kebab>`) TBD during planning; needs to be stable so re-running on the same input reuses the folder.
- Exact denylist / skip-pattern set for auto-discovery — the spec fixes the direction (skip sensitive and binary patterns) but the concrete glob list (`.env*`, `.git/`, `node_modules/`, `*.pem`, `*.key`, `*.png`, etc.) should be finalized in `references/` during planning.
- Subagent failure observability — when a subagent fails silently (context exhaustion, tool error), how does the orchestrator detect it vs. a legitimately empty slice? Same open question web-research flagged; resolve during planning with a shared approach.
- Re-run / refresh behavior when the target `output_dir` already contains a prior run — overwrite, append, or refuse? Not spec'd; pick a default during planning, ideally aligned with web-research's answer.
- Exact frontmatter shape for the user-invocable side (trigger keywords that fire on "analyze these docs", "scan my project", etc.) — needs calibration during planning to avoid false positives against casual chat and to avoid overlapping web-research's triggers.
- Do we need a `plan_gate` boolean parameter now (defaulting to false) for future parity with web-research, or add it only when a real caller asks for it? Lean: add only when needed.

## Future Considerations

- Integration with `web-research` so a single caller (e.g. PRFAQ) can interleave web findings with local-document extraction into one combined synthesis.
- A structured-query mode where the caller can request specific output fields (e.g. "for each document, return title / owner / status") — useful for comparative-analysis callers; currently out of scope.
- Extension of the citation schema to support line-range excerpts for code files, so artifact-analysis can scan a codebase's docs + source comments in one pass.
- A `review-analysis` companion skill that critiques an existing `report.md` for thin extraction, missed documents, or mis-categorized ideas.
- Richer parsing via `beagle-core:docling` for PDF / DOCX / PPTX corpora once a caller needs it.
- Caching / de-duplication across runs within the same `.beagle/concepts/<slug>/` folder so a PRFAQ re-run doesn't redo identical scans when inputs haven't changed.
