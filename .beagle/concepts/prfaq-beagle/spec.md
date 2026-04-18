# Spec: prfaq-beagle

## Core Value

A hardcore Working Backwards PRFAQ coach that filters product concepts before they consume brainstorm-beagle cycles.

## Problem Statement

Beagle has `brainstorm-beagle` for turning fuzzy ideas into WHAT/WHY specs, but no rigorous customer-first filter to kill weak concepts before investing in a spec. Weak concepts — solutions in search of problems, vague customers, missing stakes — slip through brainstorm and waste downstream planning and implementation cycles. Amazon's Working Backwards methodology forces the hardest clarity check there is: *if you can't write a compelling press release for the finished product, the product isn't ready.*

**Who:** beagle users (developers, marketplace authors) considering new product, internal tool, or OSS concepts.
**Today:** users either go straight to brainstorm-beagle with no filter, or skip brainstorm entirely. Bad ideas get cycles they don't deserve.
**Why now:** as beagle's analysis skills mature, the gap between "I have an idea" and "this idea is worth speccing" needs a dedicated forge.

## Requirements

**Must have:**
- Interactive multi-stage coaching workflow: Ignition → Press Release → Customer FAQ → Internal FAQ → Verdict.
- Hardcore coaching posture — relentless challenge of vague claims, direct tone, offers concrete reframings when the user gets stuck (tough love, not tough silence).
- Detects concept type (commercial / internal / OSS) in Ignition and calibrates FAQ prompts accordingly.
- Enforces customer-first thinking — redirects solution-first or technology-first openers back to the customer's problem.
- Produces a PRFAQ document at `.beagle/concepts/<slug>/prfaq.md` with the 5-stage structure (press release, customer FAQ, internal FAQ, verdict, reasoning captured alongside each stage).
- Binary verdict outcome: **pass** → brief produced, brainstorm-beagle recommended; **fail** → no brief, targeted feedback on what the concept would need to survive.
- On pass, produces `.beagle/concepts/<slug>/brief.md` with: concept name, type, customer, problem, solution concept, stakes, forged decisions, open questions, research pointers, PRFAQ reference.
- **Invokes `web-research`** during Ignition to ground competitive and market claims. Call shape:
  ```yaml
  research_question: <one sharp question distilled by PRFAQ from the concept>
  output_dir: .beagle/concepts/<slug>/research/
  auto_proceed: false  # user sees the subtopic plan before searches burn
  refresh: false
  ```
  PRFAQ distills the question before invoking — `web-research` does not reshape it.
- **Invokes `artifact-analysis`** during Ignition to ground the concept in the user's own documents. Call shape:
  ```yaml
  intent: <one string PRFAQ derives from the concept and stakes>
  paths: []  # empty → auto-discover .beagle/concepts/, .planning/, docs/, top-level briefs
  output_dir: .beagle/concepts/<slug>/analysis/
  refresh: false
  ```
- Graceful degradation aligned with companion error codes:
  - `web-research` returning `web-tools-unavailable` → PRFAQ surfaces the missing-tool warning to the user, proceeds without web grounding, flags any claim the coach would have verified as "unverified — tools unavailable" in the PRFAQ doc.
  - Either companion returning `prior-run-present` → PRFAQ reuses the existing `report.md` by default (resume semantics). The user can explicitly opt into a fresh pass, which re-invokes with `refresh: true` and archives the prior run.
  - `artifact-analysis` returning success with an empty-corpus `report.md` → PRFAQ proceeds with only user-provided and web-sourced context; no fallback needed.
- Resume-from-stage when re-run on an existing concept folder — the user doesn't restart Ignition if they already passed it. Prior companion-skill outputs under `research/` and `analysis/` are reused unless the user asks for a fresh pass.
- Updates `brainstorm-beagle` to: (a) relocate output from `docs/specs/YYYY-MM-DD-<topic>.md` to `.beagle/concepts/<slug>/spec.md`; (b) auto-detect `brief.md` at startup and ingest it, skipping most discovery; (c) when brainstorm-beagle itself invokes `web-research` or `artifact-analysis`, land their outputs under the same `.beagle/concepts/<slug>/research/` and `.beagle/concepts/<slug>/analysis/` folders, sharing the space with any prior PRFAQ-produced findings.

**Should have:**
- Graceful redirect — if after 2-3 exchanges the user can't articulate a customer or problem, suggest `brainstorm-beagle` first to develop the idea, then return.
- Each stage's reasoning captured alongside the stage content (challenged assumptions, alternatives considered, research findings that shaped the framing) so the PRFAQ is readable as a decision artifact, not just a final doc.
- Surface companion-skill output paths (`research/report.md`, `analysis/report.md`) to the user as they're produced so the user can open them mid-coaching if a claim needs drill-down.

**Out of scope:**
- Headless / non-interactive drafting mode. **Reason:** the gauntlet is the filter; skipping it defeats the filter's purpose.
- Nonprofit concept type. **Reason:** outside beagle's realistic audience; commercial/internal/OSS cover the cases.
- Implementation planning, architecture, tech stack. **Reason:** belongs to brainstorm-beagle and downstream skills.
- Quality-gating the produced brief. **Reason:** brief is a context handoff, not a deliverable; brainstorm-beagle runs its own discovery on top.
- Multi-language output. **Reason:** beagle is English-only today.
- Reshaping research questions or analysis intent inside `web-research` / `artifact-analysis`. **Reason:** those skills are tone-neutral primitives by design. PRFAQ's hardcore coaching applies before distilling the question/intent and after receiving the cited findings.

## Constraints

- Depends on two already-implemented companion skills:
  - `plugins/beagle-analysis/skills/web-research/` (contract: `references/companion-contract.md`)
  - `plugins/beagle-analysis/skills/artifact-analysis/` (contract: `references/companion-contract.md`)
  PRFAQ must honor these contracts verbatim per their "Non-obligations" sections — no parallel invocation styles.
- Lives in `plugins/beagle-analysis/skills/prfaq-beagle/` following beagle's existing skill conventions (SKILL.md under 500 lines, stage-specific details in `references/`, proper frontmatter).
- Modifies `brainstorm-beagle`'s already-released contract (output location + brief ingestion + companion-skill output paths) — must be reflected in CHANGELOG.md and treated as a minor version bump per beagle's release process.
- Both companion skills are tone-neutral. PRFAQ's hardcore tone lives entirely in the Ignition question-distillation, the post-findings pressure-testing, and the 5-stage coaching loop — never inside a companion invocation.

## Key Decisions

1. **Complement + upstream filter** to brainstorm-beagle. Bad ideas die in the PRFAQ gauntlet; survivors flow into brainstorm with a concept brief. *Rejected alternatives:* alternative path, same skill with modes — coaching postures differ and layering is clearer.
2. **Binary pass/fail verdict.** No three-tier middle ground. *Rejected alternatives:* three outcomes, always-a-brief spectrum — filter framing wants a clean gate.
3. **Hardcore coaching posture** matching BMAD, not beagle's thinking-partner default. *Rejected alternatives:* thinking-partner, hybrid — filter bite depends on the tone.
4. **`web-research` and `artifact-analysis` extracted as standalone skills**, not embedded in PRFAQ. *Rejected alternatives:* embedded subagents per BMAD — those patterns will be reused by multiple beagle skills; specifying them through PRFAQ's lens alone would over-fit. *Validated by implementation:* both skills' `companion-contract.md` files model `prfaq-beagle`, `brainstorm-beagle`, and `strategy-interview` as named callers with distinct worked examples — confirming the generality case.
5. **Shared `.beagle/concepts/<slug>/` folder** for the whole concept-forging pipeline, with companion outputs nested as `research/` and `analysis/`. *Rejected alternatives:* split between `docs/prfaq/` and `docs/specs/` — co-location reflects the pipeline relationship; `.beagle/` is the right home for working artifacts.
6. **No headless mode.** *Rejected alternatives:* headless with or without post-draft gauntlet — framing consistency.
7. **Three concept types (commercial / internal / OSS).** *Rejected alternatives:* all four, generic, commercial-only — three covers beagle's realistic audience without awkward commercial-only framing for OSS.
8. **`auto_proceed: false` on web-research calls.** The user sees the subtopic plan before subagents burn searches — consistent with hardcore framing, which forces explicit choices at each step. *Rejected alternative:* `auto_proceed: true` for speed — but bad subtopic framing is one of the ways a PRFAQ goes wrong quietly, and the plan-review gate is cheap insurance.
9. **Prior-run default: reuse; explicit refresh on request.** Re-running PRFAQ on the same slug reuses existing `research/` and `analysis/` outputs (consistent with resume-from-stage semantics). The user explicitly opts into `refresh: true` when they want fresh companion runs. *Rejected alternatives:* always-refresh (wasteful), always-reuse-silently (stale findings).

## Reference Points

- **BMAD's `bmad-prfaq` skill** (`/Users/ka/github/BMAD-METHOD/src/bmm-skills/1-analysis/bmad-prfaq/`) — structural and tonal reference. Adopts: 5-stage workflow, stage-resume pattern, coaching notes capture, `{concept_type}` detection, hardcore coaching posture.
- **Amazon's Working Backwards methodology** — original source of PRFAQ discipline.
- **Existing beagle-analysis skills** — `brainstorm-beagle` and `strategy-interview` for SKILL.md structure, frontmatter, and references-folder conventions.
- **`web-research` skill (implemented)** — `plugins/beagle-analysis/skills/web-research/SKILL.md` and `references/companion-contract.md` for the exact invocation shape, error codes, and the `prfaq-beagle` worked example that this spec's Requirements section mirrors.
- **`artifact-analysis` skill (implemented)** — `plugins/beagle-analysis/skills/artifact-analysis/SKILL.md` and `references/companion-contract.md` for the exact invocation shape, error codes, and the `prfaq-beagle` worked example.
- **deepagents `web-research` skill** (`/Users/ka/github/deepagents/libs/cli/examples/skills/web-research/SKILL.md`) — original pattern reference for the plan → parallel subagent delegation → synthesis structure now implemented in beagle.
- **BMAD's `artifact-analyzer.md` subagent** (`/Users/ka/github/BMAD-METHOD/src/bmm-skills/1-analysis/bmad-prfaq/agents/artifact-analyzer.md`) — original pattern reference for the JSON-structured scan/extract pattern now implemented in beagle's `artifact-analysis`.

## Open Questions

- Slug convention — user-supplied, auto-generated from the concept headline, or date-prefixed? (Resolve during planning.) Note: companion skills internally use `YYYY-MM-DD-<topic-kebab>` for their default `output_dir`, but PRFAQ overrides `output_dir` explicitly, so the concept-folder slug is PRFAQ's choice.
- Coaching-notes capture — do those stay embedded in the final PRFAQ view, or get stripped into a sibling file? TBD during planning.
- **Reconcile companion-contract worked examples with brainstorm-beagle's new output location.** Both companion skills' `companion-contract.md` files contain worked examples for `brainstorm-beagle` using `docs/specs/research/` and `docs/specs/analysis/` as `output_dir`. This spec moves brainstorm-beagle's output to `.beagle/concepts/<slug>/` — the worked examples must be updated to match when brainstorm-beagle itself is updated. Not blocking PRFAQ, but coordinated edits during the brainstorm-beagle update PR.
- Ignition-time invocation ordering — fan out `web-research` and `artifact-analysis` in parallel (consistent with BMAD's pattern), or run `artifact-analysis` first so its findings can sharpen the `research_question` PRFAQ passes to `web-research`? The latter is more rigorous but serializes the critical path. (Resolve during planning.)

## Future Considerations

- Extending `.beagle/concepts/<slug>/` convention to strategy-interview and other beagle-analysis skills for uniform working-state layout.
- A `review-prfaq` skill paralleling `strategy-review` for critiquing existing PRFAQ docs.
- A "rework" mode for failed PRFAQs — targeted revisit of specific stages rather than restart from Ignition.
- Integration with `strategy-interview` — use its diagnosis as Ignition input when a PRFAQ follows a strategic initiative.
- Multi-language support if beagle's audience expands beyond English.
- PDF / image OCR ingestion into `artifact-analysis` via `beagle-core:docling`, enabling PRFAQ to ground against richer source material.

## Companion Specs

Both companion skills are already implemented (reviewed against this spec 2026-04-18):

- **`web-research`** — `plugins/beagle-analysis/skills/web-research/`. Fail-fast on missing `WebSearch`; `auto_proceed` gate for plan review; subagent delegation with citation-schema-backed findings; four-section `report.md` (TL;DR, Findings, Gaps & Limitations, Sources).
- **`artifact-analysis`** — `plugins/beagle-analysis/skills/artifact-analysis/`. No fail-fast (filesystem tools assumed); no user-review gate (local scanning is cheap); auto-discovery of beagle knowledge locations when `paths` empty; seven-section `report.md` (Documents Found, Key Insights, User/Market Context, Technical Context, Ideas & Decisions, Raw Detail Worth Preserving, Gaps & Limitations).

Both model `prfaq-beagle` as a named caller in their `companion-contract.md` worked examples. The invocation shapes in this spec's Requirements section mirror those examples verbatim.
