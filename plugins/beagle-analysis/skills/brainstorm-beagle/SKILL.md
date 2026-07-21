---
name: brainstorm-beagle
description: "Use when the user has a fuzzy idea and wants to shape it into a concrete project spec before planning or building. Triggers on: \"brainstorm this\", \"I have an idea for...\", \"help me think through this project\", \"what should I build\", \"spec this out\". Also catches vague feature descriptions needing structured questioning to clarify scope. Does NOT write code, plan implementation, review strategy docs, or run strategy interviews \u2014 produces a WHAT/WHY spec through dialogue, not a HOW plan."
---

# Brainstorm: Ideas Into Specs

Turn a fuzzy idea into a comprehensive, implementation-free project spec through collaborative dialogue.

The output is a standalone spec document — structured enough for any agentic system to consume, clear enough for a human to act on. It captures WHAT and WHY, never HOW.

<hard_gate>
Do NOT write any code, create implementation plans, scaffold projects, or take any implementation action. This skill produces a SPEC DOCUMENT only.
</hard_gate>

**Proportionate process.** The nine steps below are the full path. For a genuinely simple concept — one subsystem, requirements the user can already state concretely, greenfield or an unambiguous brownfield gap — compress the dialogue: fewer questions, skip Scope Assessment, skip the 2-3 direction proposal when only one direction is actually live. Say which steps you are compressing and why, so the user can push back.

What never compresses is the **output contract**: the spec still lands at `.beagle/concepts/<slug>/spec.md`, still carries all eight sections, still gets one self-review pass, still gets explicit user approval before it is written. Compressing the conversation is proportionate; compressing the artifact is not.

## Workflow

Complete these steps in order:

1. **Check for a concept brief** — if `.beagle/concepts/<slug>/brief.md` exists for this idea, ingest it and skip most of steps 2-4 (see *Concept brief ingestion* below)
2. **Explore context** — read project files, docs, git history, existing specs (lighter pass if a brief is present)
   - **Prior art check (brownfield only):** before specing a feature onto an existing codebase, run a neutral capability sweep to confirm the thing doesn't already exist (see *Prior Art Check* below). Runs regardless of whether a brief is present.
3. **Assess scope** — is this one spec or does it need decomposition?
4. **Ask clarifying questions** — one at a time, follow the thread (few to none if a brief is present)
5. **Propose 2-3 directions** — high-level product approaches with tradeoffs
6. **Draft spec** — write the structured spec document
7. **Self-review** — check for completeness, contradictions, implementation leakage (see `references/spec-reviewer.md`)
8. **User review** — present for approval, iterate if needed
9. **Write to disk** — save to `.beagle/concepts/<slug>/spec.md`

```
Brief present? ──→ Yes → Ingest brief (skip most discovery) ──┐
                ──→ No  → Explore context → Assess scope       │
                                            ├─ Too large? → Decompose → Brainstorm first sub-project
                                            └─ Right size? → Clarifying questions ─┘
                                                                                   │
Brownfield? ──→ Yes → Prior art check (neutral capability sweep) ─→ Already exists? ─→ surface, reshape/kill spec
            ──→ No  → skip ─────────────────────────────────────────────────────────────────────┐
                                                                                                  │
Both paths converge → Propose directions → Draft spec → Self-review (fix inline) → User review
                                                                                        ├─ Changes? → Revise
                                                                                        └─ Approved? → Write to concept folder
```

**The terminal state is a written spec.** This skill does not transition to implementation, planning, or any other skill. The user decides what to do with the spec.

## Concept brief ingestion

If the user invokes brainstorm-beagle on a concept that already has `.beagle/concepts/<slug>/brief.md` (produced by `prfaq-beagle` on pass), ingest the brief at step 1 and skip most discovery:

1. **Read the brief.** Customer, problem, solution concept, stakes, forged decisions, and research pointers are already codified. Do not re-interview the user on these.
2. **Skim the PRFAQ reference.** Open `.beagle/concepts/<slug>/prfaq.md` for the Reasoning blocks — they explain what was challenged and why earlier decisions were made. This is context, not content to re-litigate.
3. **Open questions become your starting point.** The brief's *Open Questions* section lists what PRFAQ surfaced but did not close. These are what you ask the user about — not customer, problem, or motivation, which are already decided.
4. **Proceed to Exploring Directions.** Skip Clarifying Questions and Scope Assessment unless the brief is ambiguous about scope itself.

The brief is a context handoff, not a gate. Run your own Self-Review on the spec you produce — brainstorm-beagle remains responsible for implementation-leakage detection, requirement testability, and scope discipline regardless of how much discovery was pre-done upstream.

**When there is no brief:** proceed through steps 2-9 normally. Not every idea comes from PRFAQ.

**The brief does not exempt you from the prior art check.** A brief (or the issue behind it) frames the feature as something to build — that framing is exactly the bias the *Prior Art Check* exists to neutralize. Run the sweep even when ingesting a brief.

## Prior Art Check

This step exists because of a specific, expensive failure: drafting a spec that reinvents a capability the codebase already has. It applies whenever the idea is a feature being added to an **existing codebase** (brownfield). For greenfield ideas with no existing code, skip it.

**This section is the only place the sweep is mandated.** It runs **once per concept**, here at step 2. `references/spec-reviewer.md` §7 is a backstop that checks the sweep *happened* and that its findings landed in the spec — it does not re-run the grep. If you already swept this session, record the result and move on; a second sweep over the same workspace produces the same hits at twice the cost.

**The failure mode it prevents:** An issue or brief frames a feature as new ("we removed the old truncation, design fresh") or simply omits that prior work exists. You — or a subagent you delegate exploration to — inherit that framing, look only where the framing points, confirm the framing, and spec a feature that duplicates code already shipped and tested. The spec then teaches the downstream planner and executor to rebuild something that exists.

**The discipline: search neutrally, independent of framing.**

1. **Run a capability-keyword sweep across the WHOLE workspace** — every crate/package/module, not just the directory the issue points at. Search for the *capability* by its likely names, synonyms, and abbreviations, not the issue's vocabulary. For a truncation feature: `grep -riE 'truncat|spill|cap|max_bytes|head_bytes|limit|trim|elide'` across all source roots. Cast wide; one matching file kills the assumption.
2. **Do not trust "this doesn't exist" claims.** Issues and briefs go stale relative to the code — someone may have built the thing after the issue was filed. The issue's "we removed X / X doesn't exist yet" is a hypothesis to disprove with grep, not a fact to inherit.
3. **If you delegate exploration to a subagent, give it the neutral sweep, not the narrative scope.** Brief it as "grep the entire workspace for these capability keywords and report every hit," not "look in `module/foo` for where X is written." A scoped brief reproduces the framing bias inside the subagent. Pass the keyword list; do not pass the issue's theory of where the code lives.
4. **Surface what you find.** If the capability (or a large part of it) already exists:
   - Say so plainly, citing the file(s) — "`agent/src/spill.rs` already implements head-tail capping with a sidecar, and it's tested."
   - Reframe the spec around the gap, not the whole feature: extend/fix/wire-up what exists rather than rebuild it. Often this shrinks the spec dramatically or dissolves the need for one.
   - Record the discovery as a Key Decision ("Build on existing `spill.rs` rather than a fresh truncation module") so the downstream planner doesn't re-litigate.
5. **Composition check.** For each existing mechanism the sweep surfaced, ask: does it sit **upstream or downstream in the same data pipeline** as the feature, and does it transform (truncate, filter, buffer, reorder, dedupe) the data this feature depends on? If yes, "the mechanism exists" is not the end of the inquiry — its *composition* with the new feature is the load-bearing question. Record the interaction as a Key Decision ("bash already caps output to 50 KiB upstream; the spill must capture before that cap or it cannot deliver full output") AND tag that decision `needs-spike-before-planning`, adding to its Rationale: `**Spike required:** before plan-lock, verify the upstream/downstream data shape (what it truncates/filters/buffers/reorders/dedupes and whether this feature captures before or after) against this repo and revise this decision if the result diverges from the assumption.` A new mechanism that composes wrongly with an existing one in the same pipeline ships broken even though neither piece was reinvented.

This is distinct from *Explore context* (step 2), which reads to understand the project. The prior art check is adversarial: its job is to disprove the assumption that the feature is new, before that assumption hardens into a spec.

## Questioning

You are a thinking partner, not an interviewer. The user has a fuzzy idea — your job is to help them sharpen it.

**How to question:**

- **Start open.** Let them dump their mental model. Don't interrupt with structure.
- **Follow energy.** Whatever they emphasized, dig into that. What excited them? What problem sparked this?
- **Challenge vagueness.** Never accept fuzzy answers. "Good" means what? "Users" means who? "Simple" means how?
- **Make the abstract concrete.** "Walk me through using this." "What does that actually look like?"
- **Clarify ambiguity.** "When you say Z, do you mean A or B?"
- **Know when to stop.** When you understand what, why, who, and what done looks like — offer to proceed.

**Question budget** (`beagle-core:verification-budget` budget syntax):

- **Max passes:** 8 clarifying questions before drafting — 3 when a concept brief was ingested, since customer, problem, and motivation are already decided.
- **Stop condition:** all four items on the *Background checklist* below are answered, or the cap is reached — whichever comes first. This is observable: you can point at the answer for each of the four.
- **Tie-break:** at the cap, **stop asking and draft.** Anything still unknown becomes an entry in the spec's *Open Questions* section, which is exactly what that section is for and what `resolve-beagle` exists to close. Never spend a ninth question instead of writing an Open Question.

The user can always ask for more exploration, and you should keep going if they do — the budget bounds *your* initiative, not theirs. A spec with three honest Open Questions beats an interrogation that never converges.

**Question mechanics:**

- One question per message. If a topic needs more, break it into multiple messages.
- Prefer multiple choice when possible — easier to react to concrete options than open-ended prompts.
- When the user selects "other" or wants to explain freely, switch to plain text. Don't force them back into structured choices.
- 2-4 options is ideal. Never use generic categories ("Technical", "Business", "Other").

**What to ask about:**

| Ask about | Examples |
|-----------|----------|
| Motivation | "What prompted this?" "What are you doing today that this replaces?" |
| Concreteness | "Walk me through using this" "Give me an example" |
| Clarification | "When you say X, do you mean A or B?" |
| Success | "How will you know this is working?" "What does done look like?" |
| Boundaries | "What is this explicitly NOT?" |

**What NOT to ask about:**

- Technical implementation details (that's for planning)
- Architecture patterns (that's for planning)
- User's technical skill level (irrelevant — the system builds)
- Success metrics (inferred from the work)
- Canned questions regardless of context ("What's your core value?", "Who are your stakeholders?")

**Background checklist** (check mentally, not out loud):

- [ ] What they're building (concrete enough to explain to a stranger)
- [ ] Why it needs to exist (the problem or desire driving it)
- [ ] Who it's for (even if just themselves)
- [ ] What "done" looks like (observable outcomes)

When all four are clear, offer to proceed. If the user wants to keep exploring, keep going.

## Scope Assessment

Before diving into questions, assess whether the idea is one project or several.

**Signs it needs decomposition:**
- Multiple independent subsystems ("build a platform with chat, file storage, billing, and analytics")
- No clear ordering dependency between parts
- Would take multiple months of work

**When decomposition is needed:**
1. Help the user identify the independent pieces and their relationships
2. Establish what order they should be built
3. Brainstorm the first sub-project through the normal flow
4. Each sub-project gets its own spec

**For right-sized projects**, proceed directly to clarifying questions.

## Exploring Directions

After understanding the idea, propose 2-3 high-level directions. These are product directions, not technical architectures.

**Good directions:**
- "A CLI tool that operates on single files vs. a daemon that watches directories"
- "A focused MVP with just the core loop vs. a broader first version with supporting features"
- "Optimized for speed of use (power users) vs. optimized for discoverability (new users)"

**Bad directions (implementation leaking in):**
- "React with a REST API vs. HTMX with server-side rendering"
- "PostgreSQL vs. SQLite for storage"
- "Monorepo vs. polyrepo"

Lead with your recommendation and explain why. Present tradeoffs conversationally.

## Scope Discipline

Brainstorming naturally generates ideas beyond the current scope. Handle this gracefully:

**When the user expands scope mid-brainstorm:**
> "That's a great idea but it's its own project/phase. I'll capture it in Future Considerations so it's not lost. For now, let's focus on [current scope]."

**The heuristic:** Does this clarify what we're building, or does it add a new capability that could stand on its own?

Capture deferred ideas in the spec's "Future Considerations" section. Don't lose them, don't act on them.

## Implementation Leakage

The spec must never prescribe implementation. This is the hardest discipline.

| Allowed (WHAT) | Not allowed (HOW) |
|-----------------|-------------------|
| "Users can filter results by date and category" | "Add a /api/filter endpoint that accepts query params" |
| "Must support 10k concurrent users" | "Use Redis for session caching" |
| "Data must persist across sessions" | "Store in PostgreSQL with a users table" |
| "Must work offline" | "Use a service worker with IndexedDB" |
| "Search must feel instant" | "Use Elasticsearch with debounced queries" |

**Exception — constraints:** When the user has genuine constraints ("must use PostgreSQL because that's what our infra runs"), those go in the Constraints section with rationale. A constraint is a boundary condition, not a design choice made during brainstorming.

## Key Decisions That Rest on Tool Behavior

Some Key Decisions in a spec take the form "we will use feature X of tool Y to achieve Z" (e.g. "compile-time-checked SQL on both backends via sqlx's offline cache", "dual-platform builds via the framework's single-binary target"). These decisions look settled but encode an unverified assumption: that the tool actually behaves the way the docs imply when applied to *this* codebase.

When recording a Key Decision of this shape, do one of the following — never neither:

1. **Cite a worked example.** Point at a file in the repo (or a comparable repo on disk) where the tool already does the thing the decision depends on. `core/.sqlx/` with N existing query files is a citation; "sqlx supports compile-time checking" from memory is not.
2. **Tag the decision `needs-spike-before-planning`.** Add an explicit marker to the Rationale: `**Spike required:** before plan-lock, verify <specific command/behavior> against this repo and revise this decision if the result diverges from the assumption.`

A decision without either is a decision the downstream planner will encode as a fact and the executor will try to build against — and "the docs said it worked" is how a 5-line plan task balloons into a 400-line bash workaround. The spike tag tells the planner to add a Task 0 spike; the citation tells the planner the spike is already implicit in the existing code.

This rule is narrower than implementation leakage. The decision can still be at the WHAT level (e.g. "data must be type-checked at compile time" is WHAT). The rule applies only when the decision's *rationale* depends on specific tool behavior the user is asserting without evidence.

## Spec Format

Use the template in `references/spec-template.md`. The spec has these sections:

1. **Core Value** — ONE sentence, the most important thing
2. **Problem Statement** — what problem, who has it, why now
3. **Requirements** — must have, should have, out of scope (with reasons)
4. **Constraints** — hard limits with rationale
5. **Key Decisions** — decisions made during brainstorming with alternatives considered
6. **Reference Points** — "I want it like X" moments, external docs, inspiration
7. **Open Questions** — unresolved items needing future research
8. **Future Considerations** — ideas that emerged but belong in later phases

Requirements must be concrete and testable:

| Good requirement | Bad requirement |
|-----------------|-----------------|
| "User can undo the last 10 actions" | "Good undo support" |
| "Page loads in under 2 seconds on 3G" | "Fast performance" |
| "Works with screen readers" | "Accessible" |
| "Export to CSV and JSON" | "Multiple export formats" |

## Self-Review

**One pass over the draft, then present.** This is a review, not a gate loop.

`references/spec-reviewer.md` is the **single source** for the review criteria — nine dimensions plus the calibration bar for what counts as a real issue. Read it, apply it once, fix what it surfaces inline. Do not restate its checks here, and do not build a second parallel checklist alongside it.

**Budget** (`beagle-core:verification-budget` budget syntax):

- **Max passes:** 1 over the drafted spec. A second pass is legitimate only when the first pass rewrote a requirement's *meaning* and neighbouring sections need reconciling against the new wording. Never a third.
- **Stop condition:** every dimension in `references/spec-reviewer.md` has been considered once, and the issues it surfaced are fixed in the draft text. Observable — the fixes are visible in the prose.
- **Tie-break:** anything you could not resolve within the pass becomes an entry in *Open Questions* with a one-line note on what is unresolved, and you proceed to user review. Proceed and flag; never re-review instead.

Three delivery rules for that pass:

- **Fix inline, don't flag.** A surfaced issue gets edited in the draft, not listed for the user to adjudicate.
- **Placeholders live in Open Questions.** Unresolved TBDs and TODOs belong there explicitly — never smuggled into must-haves as if they were settled.
- **Present concrete prose.** The draft text exists in the conversation (or one attached buffer) and follows the section structure in `references/spec-template.md`, so the user reviews the actual spec rather than a summary of it. Note any deliberate section omission and why.

Then present to the user for review.

## Writing the Spec

**Pass before creating or overwriting `spec.md`:** Do not write until both are true.

1. **User gate:** The user explicitly approved the draft **or** directed you to save/write the file (vague enthusiasm alone is not approval — confirm if unclear).
2. **Path gate:** Target path is finalized — default `.beagle/concepts/<slug>/spec.md`, slug resolved (from brief frontmatter or agreed headline).

- **Default path:** `.beagle/concepts/<slug>/spec.md`
- **Slug source:** inherit from `brief.md` frontmatter if a brief was ingested; otherwise derive a kebab-case slug from the concept headline (≤40 chars, no dates). User preferences override the default path.
- **Companion outputs in-session:** if brainstorm-beagle invokes `web-research` or `artifact-analysis` mid-session, pass `output_dir: /abs/path/.beagle/concepts/<slug>/research/` or `/abs/path/.beagle/concepts/<slug>/analysis/` so findings share the concept folder with anything PRFAQ produced upstream. This keeps the whole concept-forging audit trail in one place.
- Commit to git with message: `docs: add <slug> project spec`
- After writing, tell the user:
  > "Spec written to `<path>`. Review it and let me know if you want changes."
- Wait for approval before considering the brainstorm complete.

## Key Principles

- **One question at a time** — don't overwhelm
- **Converge, don't interrogate** — the question budget has a cap; unknowns become Open Questions
- **Follow the thread** — don't walk a checklist
- **YAGNI ruthlessly** — remove anything that isn't clearly needed
- **Concrete decisions only** — "card-based layout" not "modern and clean"
- **No implementation** — WHAT and WHY, never HOW
- **Capture everything** — ideas outside scope go to Future Considerations, never lost
- **Incremental validation** — confirm understanding before moving on
- **Every capability has a consumer** — a must-have that introduces externally-facing surface names who/what consumes it, or it moves to Future Considerations; unconsumed surface is speculation
- **The spec stands alone** — anyone should be able to read it and understand the project
