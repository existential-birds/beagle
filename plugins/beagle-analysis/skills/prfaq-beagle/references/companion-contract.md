# Companion Invocation Contract (PRFAQ side)

How `prfaq-beagle` calls `web-research` and `artifact-analysis` during Ignition. Those skills are standalone with their own contracts — PRFAQ honors them verbatim. This file is the PRFAQ-side cheat sheet: exact shapes, serial-order rationale, error-handling matrix, resume rules.

Authoritative sources:

- `plugins/beagle-analysis/skills/web-research/references/companion-contract.md`
- `plugins/beagle-analysis/skills/artifact-analysis/references/companion-contract.md`

Both files include worked examples that name `prfaq-beagle` as a caller. The shapes in this document mirror those examples verbatim — if a drift appears, the companion contracts win.

## Serial order, not parallel

Run `artifact-analysis` first, read its `report.md`, then sharpen the `research_question` using its findings, then run `web-research`.

Why serial:

- `artifact-analysis` is local scanning — fast, no external cost.
- Its findings (prior decisions, technical context, user/market context) let PRFAQ ask `web-research` a sharper question.
- Sharper research question = less wasted web search, tighter synthesis.
- The one-step serialization is cheap insurance against burning web searches on questions the user's own docs already answer.

Parallel invocation is tempting for latency but fragments the critical path and re-introduces the problem this sequencing avoids.

## artifact-analysis call

```yaml
intent: "<one string PRFAQ derives from the concept and stakes>"
paths: []  # empty → auto-discover .beagle/concepts/, .planning/, docs/, root briefs
output_dir: "/abs/path/.beagle/concepts/<slug>/analysis/"
refresh: false
```

**Intent distillation — good vs bad:**

| Concept | Good intent | Bad intent |
|---|---|---|
| AI coding-assistant pricing | "competitive and technical grounding for PRFAQ on AI coding-assistant pricing" | "analyze my docs" |
| Internal on-call tool | "prior decisions and pain points around on-call handoffs" | "find anything about oncall" |
| OSS ADR CLI | "existing ADR tooling referenced in briefs and docs; competing formats" | "check the docs folder" |

The `intent` string is tone-neutral. PRFAQ's hardcore posture lives *before* distilling the intent (when you're figuring out what to scan for) and *after* receiving the report (when you pressure-test claims against the findings) — never inside the string handed to the companion.

**Empty `paths` is intentional.** Auto-discovery is the right default for Ignition because PRFAQ shouldn't need to know where the user keeps briefs. Only override with explicit paths if the user tells you "don't scan `<X>`" or "only look at `<Y>`."

## web-research call

```yaml
research_question: "<one sharp question PRFAQ distilled, informed by artifact-analysis findings>"
output_dir: "/abs/path/.beagle/concepts/<slug>/research/"
auto_proceed: false  # user sees subtopic plan before subagents burn searches
refresh: false
```

**Sharpening the research question — good vs bad:**

| Good (specific) | Bad (categorical) |
|---|---|
| "What AI coding-assistant pricing tiers exist for enterprise teams in 2026, and what features differentiate them?" | "What does the AI tools market look like?" |
| "How do task-tracking tools handle sub-tasks that span multiple top-level projects?" | "What do task trackers do?" |
| "Which open-source ADR tools support per-project templates and which don't?" | "Are there ADR tools?" |

If the user's own docs (from artifact-analysis) already answered a dimension, do not re-ask the web. Aim the research question at the *gap* — the thing no local doc speaks to.

**`auto_proceed: false` is intentional.** The plan-review gate forces the user to see the subtopic plan before subagents burn. PRFAQ's hardcore posture applies here: bad subtopic framing is one way a PRFAQ goes wrong quietly; the plan-gate is cheap insurance.

The one exception: if the user explicitly says "just run it" or "don't stop me for review" during Ignition, you can pass `auto_proceed: true`. Surface the choice — don't silently skip gates.

## Error-handling matrix

Handle every combination explicitly. PRFAQ does not silently drop grounding.

| Companion returns | PRFAQ response |
|---|---|
| `artifact-analysis` success (normal corpus) | Read `report.md`. Use Key Insights, Ideas & Decisions, and User/Market Context to sharpen the `research_question`. Point user at the file path. |
| `artifact-analysis` success (empty corpus) | Not an error. Note in Ignition Reasoning: *"no local context found — <reason, e.g. fresh repo>."* Proceed to web-research with the concept-level question; no fallback needed. |
| `artifact-analysis` error `prior-run-present` | **Resume default: reuse.** Surface: *"reusing prior analysis from `<output_dir>`."* If the user explicitly asks for a fresh pass, retry with `refresh: true`. |
| `web-research` success | Read `report.md`. Use Findings and Gaps & Limitations to pressure-test Press Release and FAQ stages. Point user at the file path. |
| `web-research` error `web-tools-unavailable` | Surface to user: *"web research unavailable — proceeding without web grounding."* Flag any claim the coach would have verified as *"unverified — tools unavailable"* in prfaq.md Ignition Reasoning. Continue the gauntlet. Do NOT abort. |
| `web-research` error `prior-run-present` | Same resume default as artifact-analysis. Reuse prior `report.md`; retry with `refresh: true` only on explicit user request. |

**What PRFAQ never does:**

- Silently retry without telling the user.
- Silently reuse a stale report when the user intended a fresh pass.
- Treat `web-tools-unavailable` as a concept-level failure. It is a tooling limitation; the concept is unrelated.
- Copy findings inline into the coaching stream. Cite ("the research shows X") and point at the file path; the user opens the report if they need drill-down.

## Resume rules

Prior companion runs are **reused by default**. This is consistent with PRFAQ's own resume-from-stage semantics — re-running PRFAQ on an existing concept slug picks up where the user left off, including `research/` and `analysis/` outputs.

To force a fresh pass:

1. The user explicitly says so (*"re-research that", "refresh the analysis", "run it fresh"*).
2. PRFAQ re-invokes the companion with `refresh: true`.
3. The companion archives the prior run to `<output_dir>/.archive-<timestamp>/` and runs fresh.

Do NOT silently overwrite. Do NOT silently reuse stale findings when the user intended a refresh. If unsure, ask.

## Non-obligations

The standalone contracts already enumerate these — repeating the ones that bite PRFAQ specifically:

- **No question reshaping.** `web-research` and `artifact-analysis` do not reshape `research_question` or `intent`. Whatever PRFAQ hands in is what runs. Sharpen before you call.
- **No coaching posture inside the companions.** They are tone-neutral by design. Do not try to sneak hardcore coaching into the strings you hand them.
- **No inline findings.** The companions write to disk. PRFAQ summarizes and cites; it does not dump report.md content into the conversation.
- **No cross-run caching beyond the output_dir.** Each invocation is self-contained. PRFAQ's caching strategy is reuse-by-default on the concept's own `research/` and `analysis/` folders — nothing more.

## Extending the contract

If PRFAQ needs behavior not covered by the standalone contracts (new parameter, new error code), extend the companion's `companion-contract.md` first — not this file. Parallel invocation styles fragment the contract and re-introduce the reason these skills were extracted as standalone primitives.
