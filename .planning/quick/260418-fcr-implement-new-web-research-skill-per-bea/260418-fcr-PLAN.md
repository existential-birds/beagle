---
phase: 260418-fcr
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - plugins/beagle-analysis/skills/web-research/SKILL.md
  - plugins/beagle-analysis/skills/web-research/references/subagent-brief.md
  - plugins/beagle-analysis/skills/web-research/references/citation-schema.md
  - plugins/beagle-analysis/skills/web-research/references/report-template.md
  - plugins/beagle-analysis/skills/web-research/references/failure-modes.md
  - plugins/beagle-analysis/skills/web-research/references/companion-contract.md
  - CHANGELOG.md
  - CLAUDE.md
autonomous: true
requirements:
  - WR-01-input-contract
  - WR-02-plan-gate
  - WR-03-parallel-subagents
  - WR-04-file-based-findings
  - WR-05-citation-shape
  - WR-06-synthesis-report
  - WR-07-output-path-default
  - WR-08-partial-success
  - WR-09-fail-fast
  - WR-10-dual-mode
  - WR-11-companion-contract
  - WR-12-tone-neutral

must_haves:
  truths:
    - "SKILL.md exists at plugins/beagle-analysis/skills/web-research/SKILL.md with frontmatter that does NOT set disable-model-invocation: true"
    - "SKILL.md is under 500 lines"
    - "SKILL.md documents the companion-invocation contract (research-question string + optional output_dir + optional auto_proceed)"
    - "SKILL.md describes the three-step flow: plan.md → parallel subagent findings → report.md synthesis"
    - "SKILL.md names the four fixed report sections in order: TL;DR, Findings, Gaps & Limitations, Sources"
    - "SKILL.md documents default output path `.beagle/research/<slug>/` and the caller override via `output_dir`"
    - "SKILL.md documents partial-success on subagent failure and fail-fast on missing web tools"
    - "SKILL.md is tone-neutral — no coaching posture language"
    - "references/ folder contains subagent-brief, citation-schema, report-template, failure-modes, and companion-contract files"
    - "CHANGELOG.md [Unreleased] section lists the new skill under beagle-analysis"
    - "CLAUDE.md Key Skills table lists the new web-research skill under beagle-analysis"
  artifacts:
    - path: "plugins/beagle-analysis/skills/web-research/SKILL.md"
      provides: "Skill entry point with frontmatter, workflow, contract, and references"
      contains: "name: web-research"
    - path: "plugins/beagle-analysis/skills/web-research/references/subagent-brief.md"
      provides: "Template the orchestrator uses to build each parallel subagent's brief"
    - path: "plugins/beagle-analysis/skills/web-research/references/citation-schema.md"
      provides: "Citation shape (URL + title + excerpt; optional date + source type)"
    - path: "plugins/beagle-analysis/skills/web-research/references/report-template.md"
      provides: "Fixed report.md layout: TL;DR / Findings / Gaps & Limitations / Sources"
    - path: "plugins/beagle-analysis/skills/web-research/references/failure-modes.md"
      provides: "Partial-success behavior + fail-fast-on-missing-web-tools behavior"
    - path: "plugins/beagle-analysis/skills/web-research/references/companion-contract.md"
      provides: "Call shape other beagle skills use to invoke web-research"
  key_links:
    - from: "plugins/beagle-analysis/skills/web-research/SKILL.md"
      to: "references/subagent-brief.md"
      via: "`@references/subagent-brief.md` link in the Dispatch section"
      pattern: "references/subagent-brief"
    - from: "plugins/beagle-analysis/skills/web-research/SKILL.md"
      to: "references/citation-schema.md"
      via: "link in the Citations section"
      pattern: "references/citation-schema"
    - from: "plugins/beagle-analysis/skills/web-research/SKILL.md"
      to: "references/report-template.md"
      via: "link in the Synthesis section"
      pattern: "references/report-template"
    - from: "CHANGELOG.md"
      to: "new skill"
      via: "[Unreleased] Added entry naming beagle-analysis:web-research"
      pattern: "web-research"
    - from: "CLAUDE.md"
      to: "new skill"
      via: "Key Skills table row under beagle-analysis"
      pattern: "web-research"
---

<objective>
Implement the `web-research` skill for `beagle-analysis` per `.beagle/concepts/web-research/spec.md`. Create the skill tree (SKILL.md + five reference files), add an `[Unreleased]` CHANGELOG entry, and register the skill in CLAUDE.md's Key Skills table. No version bump — that belongs to the release flow per CLAUDE.md §Release Process.

Purpose: Give beagle-analysis a reusable, tone-neutral research primitive that can be invoked directly by users and programmatically by companion skills (`prfaq-beagle`, `brainstorm-beagle`, `strategy-interview`) without each caller re-implementing parallel web research.

Output: a complete, on-disk, human-readable skill under `plugins/beagle-analysis/skills/web-research/` plus two small metadata touches.
</objective>

<planning_decisions>

The spec §Open Questions says these four items should be resolved during planning. Decisions made here — executor implements them as-written, no second-guessing.

**OQ-1. Slug derivation rule for standalone mode.**
Decision: `YYYY-MM-DD-<topic-kebab>` where `<topic-kebab>` is the research question lowercased, punctuation stripped, whitespace collapsed to single hyphens, truncated to 60 chars on a word boundary. Stable re-derivation means re-running the same question on the same day reuses the same folder (see OQ-3 for what happens then). Date-prefixing keeps sibling runs sorted chronologically. Rule lives in SKILL.md under "Output location".

**OQ-2. Subagent failure observability.**
Decision: **every subagent must write at least a stub findings file before returning.** The stub contains a `status:` frontmatter field (`ok`, `empty`, `failed`) and a one-line reason. Absence of the file after the subagent finishes = silent failure; the orchestrator records it under `Gaps & Limitations` with the subtopic name and the last known brief. "Legitimately empty" results have `status: empty` with a reason, so they never get confused with silent context-exhaustion failures. Rule lives in `references/failure-modes.md`.

**OQ-3. Re-run behavior when `output_dir` already contains a prior run.**
Decision: **refuse by default; require an explicit `refresh: true` parameter to overwrite.** Rationale: each run is supposed to be self-contained and auditable (spec Constraint); silently overwriting destroys the audit trail, silently appending produces incoherent reports. The caller explicitly opting in via `refresh: true` preserves auditability intent while unblocking obvious re-run cases. On refuse, the skill returns a clear message naming the existing folder so the caller can choose. Rule lives in SKILL.md under "Output location" and in the companion-contract reference.

**OQ-4. Trigger keyword calibration for the user-invocable side.**
Decision: frontmatter `description` triggers on strong research-intent phrases only — "research X", "do web research on", "look up sources for", "find citations for", "gather evidence on", "what does the web say about". Does NOT trigger on casual chat like "look up this function" (codebase, not web) or "search for the file" (Glob, not web). Explicit negative examples are called out in the description to bias against false positives. `disable-model-invocation` is NOT set, per spec §Constraints. Full description string is drafted in Task 1.

</planning_decisions>

<execution_context>
Quick-mode execution. No multi-agent orchestration needed — one focused agent does all three tasks in one pass. Target ~30% context. No tests exist for this skill (it's a markdown skill, not code); verification is structural (files exist, line counts, required headings).
</execution_context>

<context>
@.beagle/concepts/web-research/spec.md
@plugins/beagle-analysis/skills/resolve-beagle/SKILL.md
@plugins/beagle-analysis/skills/resolve-beagle/references/subagent-prompts.md
@plugins/beagle-analysis/skills/brainstorm-beagle/SKILL.md
@plugins/beagle-analysis/skills/strategy-interview/SKILL.md
@CLAUDE.md
@CHANGELOG.md
@.claude-plugin/marketplace.json

<environment_notes>
- There are NO per-plugin `plugin.json` files in this repo (CLAUDE.md's architecture description overstates this). Versioning is centralized in `.claude-plugin/marketplace.json`. Do NOT create a `plugins/beagle-analysis/plugin.json`.
- The deepagents reference (`/Users/ka/github/deepagents/libs/cli/examples/skills/web-research/SKILL.md`) does not exist on this machine; spec §Reference Points is informational only, do not try to mirror a file you can't read.
- Marketplace version bump belongs to the release PR (CLAUDE.md §Release Process), not this task. Leave `marketplace.json` untouched.
</environment_notes>

<interfaces>
<!-- Key patterns the executor should match, extracted from sibling skills. -->

Frontmatter shape (from resolve-beagle, brainstorm-beagle — no `disable-model-invocation` key, no `user-invocable: false`):
```yaml
---
name: web-research
description: "Use when <trigger>. Triggers on: <phrase list>. Does NOT <anti-triggers>."
---
```

Reference-file link style used by sibling skills: plain relative markdown — `See \`references/subagent-brief.md\`.`

Subagent-brief pattern (from resolve-beagle/references/subagent-prompts.md): each template has `## Recommended answer / ## Alternatives / ## Evidence / ## Open sub-questions` return shape, capped ~300 words. Our subagent-brief pattern differs: findings files are *evidence dumps*, not decision proposals — but the "cap the return / structured frontmatter / cite sources" discipline transfers.
</interfaces>

</context>

<tasks>

<task type="auto">
  <name>Task 1: Create the web-research skill tree (SKILL.md + 5 references)</name>
  <files>
    plugins/beagle-analysis/skills/web-research/SKILL.md
    plugins/beagle-analysis/skills/web-research/references/subagent-brief.md
    plugins/beagle-analysis/skills/web-research/references/citation-schema.md
    plugins/beagle-analysis/skills/web-research/references/report-template.md
    plugins/beagle-analysis/skills/web-research/references/failure-modes.md
    plugins/beagle-analysis/skills/web-research/references/companion-contract.md
  </files>
  <action>
Create the directory and all six files. Do NOT create a `plugin.json` — this repo doesn't use per-plugin manifests.

**SKILL.md** (target 250-400 lines, hard ceiling 500 per spec §Constraints):

Frontmatter:
```yaml
---
name: web-research
description: "Use when the user wants web research: gathering cited, multi-angle evidence on a specific question. Triggers on: \"research X for me\", \"do web research on\", \"look up sources for\", \"find citations for\", \"gather evidence on\", \"what does the web say about X\". Also invoked programmatically by other beagle skills (prfaq-beagle Ignition, brainstorm-beagle reference points, strategy-interview context grounding) via the companion contract. Does NOT trigger on codebase lookups (\"find this function\", \"search the repo\"), local file search, LLM-as-judge evaluation, or paywalled/auth-gated scraping. Produces a written plan, parallel-subagent findings, and a cited synthesis report on disk — never inline prose, never unsourced claims."
---
```

Then sections, in this order (match sibling skills' heading style):

1. **One-line purpose** — tone-neutral. Something like "Turn a sharp research question into cited, gap-flagged findings by delegating to parallel web-search subagents."
2. **When to use / when NOT to use** — mirror the frontmatter anti-triggers.
3. **Workflow** — the three-step flow: (a) write `plan.md`, (b) show to user for review unless `auto_proceed: true`, (c) spawn up to 3 parallel subagents (one per subtopic, 1-5 subtopics total), (d) synthesize `report.md`. Include a small ASCII flow diagram like resolve-beagle has.
4. **Inputs** — the contract: `research_question` (string, required); `output_dir` (absolute path, optional); `auto_proceed` (bool, default false); `refresh` (bool, default false — documented per OQ-3).
5. **Output location** — caller `output_dir` wins; otherwise default `.beagle/research/<slug>/` with slug rule per OQ-1: `YYYY-MM-DD-<topic-kebab>`, topic lowercased, punctuation stripped, whitespace → single hyphens, truncated to 60 chars on word boundary. Refuse if folder exists and has prior run unless `refresh: true` — reference `references/companion-contract.md`.
6. **The research plan (`plan.md`)** — what it contains: main question verbatim, 1-5 non-overlapping subtopics, expected information per subtopic, synthesis approach. Plan review gate is ON by default; `auto_proceed: true` suppresses the pause.
7. **Subagent dispatch** — up to 3 concurrent; each gets a mechanically-derived brief (no interpretation drift). Every subagent writes `findings/<subtopic-slug>.md` and returns only a terse status line. See `references/subagent-brief.md`.
8. **Citations** — URL + page title + verbatim excerpt are always required. Retrieval date + source type (official docs / vendor / blog / forum / news) included when naturally available; never synthesized. See `references/citation-schema.md`.
9. **Synthesis (`report.md`)** — fixed section order: `TL;DR` (3-5 bullets), `Findings` (organized by subtopic/theme, every claim carrying `[^n]` footnotes), `Gaps & Limitations` (non-negotiable — honest accounting of what couldn't be established), `Sources` (numbered bibliography matching footnotes). See `references/report-template.md`.
10. **Failure modes** — partial-success on subagent failure (record in Gaps & Limitations with subtopic name and last-known brief); fail-fast if web tools are entirely unavailable (abort before spawning subagents, return structured error). Silent-failure detection rule per OQ-2: subagents must write at least a stub findings file with `status:` frontmatter before returning; absence = failure. See `references/failure-modes.md`.
11. **Budget defaults** (tunable, not hard-coded): 1-5 subtopics total, up to 3 parallel subagents, 3-5 web searches per subagent.
12. **Companion invocation contract** — the exact call shape other beagle skills use. See `references/companion-contract.md`.
13. **Tone** — tone-neutral primitive. Explicitly: no coaching posture, no challenge framing, no opinionated reshaping of the research question (that's the caller's job).
14. **Out of scope** — short list mirroring spec §Requirements/Out of scope (long-running/scheduled, credibility adjudication, paywalled scraping, coaching posture, multi-language, cross-run caching, non-web sources).

**references/subagent-brief.md** (~80-120 lines):
Template the orchestrator mechanically fills in from `plan.md`. Shape:
- `Subtopic:` (one line)
- `Research question:` (main question verbatim)
- `What to establish:` (bullet list from plan.md)
- `Budget:` (N web searches; one findings file)
- `Output path:` (`<output_dir>/findings/<subtopic-slug>.md`)
- `Required frontmatter on output file:` `status: ok | empty | failed`, `subtopic:`, `brief_hash:`, `started_at:`, `finished_at:`
- `Citation rules:` (link to citation-schema.md; each claim carries a `[^n]` footnote)
- `Partial-failure protocol:` always write the file, even on failure, with `status: failed` and a one-line reason
- `Return:` a single terse status line back to the orchestrator (path to file + status), never inline findings

**references/citation-schema.md** (~50-80 lines):
- Required fields per citation: `url`, `title`, `excerpt` (verbatim quoted)
- Optional fields: `retrieved_at` (ISO date), `source_type` (one of: official-docs, vendor, blog, forum, news, other)
- Never synthesize missing metadata; omit optional fields rather than guess
- Footnote format in findings and report: `[^n]` inline, numbered bibliography in `Sources`
- Example of a well-formed citation block (matching report-template.md's Sources section)

**references/report-template.md** (~60-100 lines):
The literal skeleton of `report.md` — a fenced markdown block the executor can copy. Sections in fixed order:
1. Title: `# Research: <research question>`
2. `## TL;DR` — 3-5 bullets
3. `## Findings` — subsections by subtopic or theme; every claim carries `[^n]`
4. `## Gaps & Limitations` — required even when complete; explicit items for failed subagents (per failure-modes.md)
5. `## Sources` — numbered bibliography matching footnote numbers; citation fields per citation-schema.md

**references/failure-modes.md** (~60-90 lines):
- **Partial success** (one or more subagents failed): continue with what succeeded; enumerate each failed subtopic in Gaps & Limitations with the subagent's last-known brief and the `status: failed` reason from its stub file. Do NOT abort the whole run.
- **Fail-fast** (web tools entirely unavailable): verify `WebSearch` / `WebFetch` availability BEFORE spawning any subagent. If absent, abort, do not create `plan.md`, return a structured error the caller can recognize: `{error: "web-tools-unavailable", detail: "<tool names missing>"}`. Parent skills can detect this and trigger graceful-degradation (e.g. prfaq-beagle asks the user to paste research instead).
- **Silent-failure detection (OQ-2 rule)**: every subagent is required to write at least a stub `findings/<slug>.md` with `status:` frontmatter before returning. Orchestrator checks every expected file post-dispatch; any missing file = silent failure, recorded in Gaps & Limitations with the subtopic name and the text "subagent returned without producing a findings file (likely context exhaustion or tool error)".
- **Re-run protection (OQ-3 rule)**: before writing anything, check whether `output_dir` already contains `plan.md` or `report.md`. If yes and `refresh` is not `true`, refuse with a message naming the existing folder. If `refresh: true`, move the prior contents to `<output_dir>/.archive-<timestamp>/` and start fresh (preserves audit trail).

**references/companion-contract.md** (~60-90 lines):
The programmatic invocation shape. Document it as the contract other beagle skills are expected to honor verbatim. Include:
- Minimal call: research question only; output lands in default `.beagle/research/<slug>/`.
- Full call: `research_question`, `output_dir`, `auto_proceed`, `refresh`.
- Worked examples for the three known callers:
  - **prfaq-beagle** (Ignition): passes `output_dir: .beagle/concepts/<slug>/research/`, `auto_proceed: false` (user is in the PRFAQ loop, wants plan review).
  - **brainstorm-beagle** (reference points): passes `output_dir: docs/specs/research/<slug>/`, `auto_proceed: true` when the user has explicitly asked for background research mid-brainstorm.
  - **strategy-interview** (context grounding): passes `output_dir: .beagle/strategy/<subject-slug>/research/`, `auto_proceed: false`.
- Return contract: on success, the caller gets absolute paths to `plan.md` and `report.md`. On fail-fast, the structured error object from failure-modes.md.
- Explicit note: this skill does NOT reshape or coach the research question — callers distill their brief into a sharp question themselves before invoking.

Write all files. Do not use heredocs — use the Write tool directly.
  </action>
  <verify>
    <automated>
test -f plugins/beagle-analysis/skills/web-research/SKILL.md \
  && test -f plugins/beagle-analysis/skills/web-research/references/subagent-brief.md \
  && test -f plugins/beagle-analysis/skills/web-research/references/citation-schema.md \
  && test -f plugins/beagle-analysis/skills/web-research/references/report-template.md \
  && test -f plugins/beagle-analysis/skills/web-research/references/failure-modes.md \
  && test -f plugins/beagle-analysis/skills/web-research/references/companion-contract.md \
  && awk 'END{exit !(NR<500)}' plugins/beagle-analysis/skills/web-research/SKILL.md \
  && grep -q '^name: web-research' plugins/beagle-analysis/skills/web-research/SKILL.md \
  && ! grep -q 'disable-model-invocation: true' plugins/beagle-analysis/skills/web-research/SKILL.md \
  && grep -q 'TL;DR' plugins/beagle-analysis/skills/web-research/references/report-template.md \
  && grep -q 'Gaps &amp; Limitations\|Gaps & Limitations' plugins/beagle-analysis/skills/web-research/references/report-template.md \
  && grep -qi 'auto_proceed' plugins/beagle-analysis/skills/web-research/SKILL.md \
  && grep -qi 'output_dir' plugins/beagle-analysis/skills/web-research/SKILL.md \
  && grep -qi 'refresh' plugins/beagle-analysis/skills/web-research/references/failure-modes.md \
  && echo OK
    </automated>
  </verify>
  <done>All six files exist. SKILL.md is under 500 lines, has the required frontmatter `name: web-research`, does NOT set `disable-model-invocation: true`, and mentions `output_dir` and `auto_proceed`. `report-template.md` names both `TL;DR` and `Gaps & Limitations`. `failure-modes.md` documents the `refresh` behavior.</done>
</task>

<task type="auto">
  <name>Task 2: Register the skill in CHANGELOG and CLAUDE.md</name>
  <files>
    CHANGELOG.md
    CLAUDE.md
  </files>
  <action>
**CHANGELOG.md** — under the existing `## [Unreleased]` heading (line 7 as of plan-time; read the file first), add a new `### Added` block (create the subheading if the Unreleased section is currently empty) with one bullet:

```
### Added
- **beagle-analysis:** Add `web-research` skill — reusable research primitive that turns a sharp research question into a written plan, parallel-subagent findings, and a cited synthesis report (`TL;DR` / `Findings` / `Gaps & Limitations` / `Sources`) on disk. Dual-mode: directly invocable by users and programmatically invocable by companion skills (`prfaq-beagle`, `brainstorm-beagle`, `strategy-interview`) via a documented contract.
```

Do NOT add a PR link — this is pre-release; the release PR will add it.
Do NOT bump version in `marketplace.json` — version bumps belong to the release flow (CLAUDE.md §Release Process).
Do NOT touch the footer compare links.

**CLAUDE.md** — in the "Key Skills" table, add one row under the `beagle-analysis` rows (place after the existing `beagle-analysis | llm-judge` and `beagle-analysis | write-adr` entries, before the `beagle-docs` rows):

```
| beagle-analysis | `web-research` | Parallel web-search research with cited, gap-flagged synthesis report |
```

Also update the plugin count line in the "What This Is" section: today it reads `"11 focused plugins with 127 skills."` — increment the skill count to 128. Re-grep to confirm no other hardcoded "127" exists.
  </action>
  <verify>
    <automated>
grep -q '^### Added' CHANGELOG.md \
  && awk '/^## \[Unreleased\]/{flag=1; next} /^## \[/{flag=0} flag' CHANGELOG.md | grep -q 'web-research' \
  && grep -q '| beagle-analysis | `web-research` |' CLAUDE.md \
  && grep -q '128 skills' CLAUDE.md \
  && ! grep -q '127 skills' CLAUDE.md \
  && echo OK
    </automated>
  </verify>
  <done>CHANGELOG.md `[Unreleased]` section has an `### Added` bullet naming `beagle-analysis:web-research`. CLAUDE.md Key Skills table has a `web-research` row. Skill count updated from 127 → 128. `marketplace.json` untouched.</done>
</task>

</tasks>

<verification>
After both tasks:

1. Skill tree exists and is structurally complete (verified by Task 1 automated check).
2. Frontmatter respects dual-mode exposure (no `disable-model-invocation: true`) and SKILL.md is under 500 lines.
3. Open-question decisions (OQ-1..OQ-4) are documented in SKILL.md + `references/failure-modes.md` + `references/companion-contract.md`.
4. CHANGELOG and CLAUDE.md register the new skill; no version bump leaks into `marketplace.json`.
5. Manual line-count sanity: `wc -l plugins/beagle-analysis/skills/web-research/SKILL.md` returns a number &lt; 500.
</verification>

<success_criteria>
- [ ] `plugins/beagle-analysis/skills/web-research/SKILL.md` exists, under 500 lines, has frontmatter with `name: web-research` and a trigger-calibrated description (OQ-4).
- [ ] SKILL.md does NOT set `disable-model-invocation: true`.
- [ ] SKILL.md documents the input contract (`research_question`, `output_dir`, `auto_proceed`, `refresh`), the three-step flow, default output path `.beagle/research/<slug>/` with the OQ-1 slug rule, the fixed report section order, partial-success + fail-fast behavior, and tone neutrality.
- [ ] Five reference files exist and cover: subagent brief template (with stub-file rule per OQ-2), citation schema, report template (with all four sections in order), failure modes (including OQ-3 refresh rule), companion contract (with worked examples for prfaq-beagle / brainstorm-beagle / strategy-interview).
- [ ] CHANGELOG.md `[Unreleased]` has an Added bullet for `beagle-analysis:web-research`.
- [ ] CLAUDE.md Key Skills table has a `web-research` row under `beagle-analysis`; skill count updated 127 → 128.
- [ ] `.claude-plugin/marketplace.json` is NOT modified in this task.
</success_criteria>

<output>
No summary file required (quick mode). Executor confirms completion by running the verify commands and reporting pass/fail.
</output>
