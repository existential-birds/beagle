# Output Templates

Produce two files at the end of the interview. Keep both concise — good strategy is short because it has genuinely decided what matters. A strategy document that sprawls is usually hiding unfinished thinking.

---

## `strategy-draft.md` — the shareable strategy document

Use this exact structure. Fill with the user's own words where possible; paraphrase only when the original was fluffy.

```markdown
# Strategy: [short, concrete subject — e.g., "Platform team H1 2026"]

_Draft produced via interview on [date]. Author: [user]. Status: draft for review._

## At a glance

> **Challenge:** [One sentence — the diagnosis in plain language.]
> **Approach:** [One sentence — the guiding policy.]
> **Key moves:** [Top 3 actions, comma-separated, no detail.]

## Diagnosis

[2-5 sentences. What is actually going on? What is the core challenge — the one or two things that matter most? Be specific enough to be wrong. If there's a useful analogy or metaphor, use it.]

## Guiding Policy

[1-3 sentences. The overall approach chosen to address the diagnosis. State what this approach does — and, crucially, what it rules out. This should be a directional choice, not a goal.]

**What this explicitly does not do:** [1-3 bullets naming the reasonable alternatives being declined, so the choice is visible.]

## Coherent Actions

[3-6 concrete actions that carry out the guiding policy. For each, one or two sentences. No sub-bullets — if something needs that much structure it belongs in a separate planning doc.]

1. **[Action name]** — [what it is, who owns it, what changes as a result. Note which other action(s) it reinforces.]
2. **[Action name]** — ...
3. **[Action name]** — ...

## How these actions reinforce each other

[One short paragraph tracing the coherence: how action 1 makes action 2 easier, how action 3 protects action 1, etc. If you can't write this paragraph, the actions aren't coherent — go back.]

## Decisions required

_Include this section when the strategy depends on approvals, budget reallocation, or organizational changes that someone other than the author must greenlight._

- **[Decision]** — [who needs to decide, by when, what happens if delayed]

## Required capabilities

_Include this section only when the strategic choice cascade was used during the interview._

[3-5 capabilities the organization must have to execute this strategy. For each: whether the org has it today, and what it takes to build if not. Flag any capability the strategy assumes but hasn't resourced — these are the most common silent points of failure.]

1. **[Capability]** — [status: have it / building / gap]. [One sentence on why it's load-bearing.]
2. ...

## What success looks like in [timeframe]

[3-5 observable indicators. Not metrics for their own sake — leading signals that the guiding policy is working.]
```

---

## `strategy-notes.md` — the reasoning companion (not for sharing)

The messy, honest file. For the user's own use — shared thinking, not a polished deliverable.

```markdown
# Strategy Notes — [subject]

_Companion to strategy-draft.md. Internal thinking, open questions, things that were pushed back on. Not for circulation._

## Interview state

- **Subject:** [what the strategy is for]
- **Last completed phase:** [Phase 1 / 2 / 3 / 4]
- **Confirmed diagnosis:** [yes/no — if yes, one-sentence summary]
- **Confirmed guiding policy:** [yes/no — if yes, one-sentence summary]
- **Confirmed coherent actions:** [yes/no — if yes, count]
- **Lenses used:** [landscape mapping / value innovation / choice cascade / none]
- **Next question to ask:** [the question that would resume the interview]

## What I heard in the interview

[A short narrative of the situation as the user described it. Use their phrasing where it was vivid. This is the raw material the kernel was built from.]

## How the thinking evolved

[Trace the arc from where the user started to where they ended up. What was their initial framing? Where did it shift? What question or pushback caused the biggest change in thinking? This section is often the most valuable part of the notes — it captures the reasoning journey, not just the destination.]

## Bad-strategy patterns caught during the interview

[For each: what the pattern was, how it showed up, how it was resolved or whether it's still unresolved. Be honest — if the user resisted a pushback and you let it go, say so here.]

- **[Pattern, e.g., "Mistaking goal for strategy"]**: [what was said, how it was redirected, final state.]
- ...

## Assumptions this strategy depends on

[Every strategy rests on claims about the world that could be wrong. List the load-bearing ones so they can be tested. Flag assumptions the user didn't state but the strategy implicitly requires.]

- ...

## Open questions

[Things the user couldn't answer yet, or that deserve follow-up before the draft becomes real. Phrase each as a question.]

- ...

## Alternatives considered and rejected

[Capture the paths the guiding policy rules out, so future-them can see why — and revisit if circumstances change.]

- ...

## Landscape analysis

_Include this section only when landscape mapping was used during the interview._

[Summary of the value chain as understood: which components the user controls, which they depend on, and where key components sit on the evolution curve. Note any structural findings — commodity components being built custom, genesis-stage problems treated as procurement decisions, competitors further along the evolution curve, impending disruptions. These findings should already be reflected in the diagnosis; this section preserves the reasoning behind them.]

## Cascade pressure-test

_Include this section only when the strategic choice cascade was used during the interview._

[Findings from the five cascade choices — where to play, how to win, capabilities, management systems. Focus on gaps: which choices were explicit and strong, which were implicit or missing. Especially note capability gaps (things the strategy assumes the org can do but hasn't verified) and management system gaps (nothing in the org's operating rhythm that would keep this strategy alive).]

## Value innovation findings

_Include this section only when the value innovation lens was used during the interview._

[What the competitive convergence analysis revealed: the factors everyone competes on, where offerings converge, the four-actions assessment (eliminate/reduce/raise/create), and any noncustomer tiers explored. Note whether the user accepted the reframe or resisted it, and whether the diagnosis was reshaped as a result.]

## What I'd sharpen next

[Candid take on the one or two parts of the kernel that still feel weakest, and what evidence or thinking would strengthen them. Don't skip this to be polite — it's the most useful paragraph in the file.]
```

---

## Notes on producing the files

- Write both files in the user's current working directory unless they've specified another location.
- Use the user's language where possible; don't over-polish into management-speak.
- If the kernel is genuinely incomplete — e.g., the diagnosis is still fuzzy — **do not write `strategy-draft.md` unless the user explicitly requests a provisional draft.** Instead, capture the current state in `strategy-notes.md` only. If the user does request a provisional draft, prefix the title with `[PROVISIONAL]` and mark each unconfirmed kernel element: `[UNCONFIRMED — diagnosis still under development, see notes]`. This prevents incomplete thinking from masquerading as a finished strategy. An honest `strategy-notes.md` is better than a `strategy-draft.md` with fake confidence.
- The "At a glance" section is for upward communication — a busy stakeholder should be able to read just this block and understand the strategy. Write it last, after the full document is done.
- **Composing from durable state**: When `.beagle/strategy/<subject-slug>/` files exist (`state.md`, `evidence.md`, `lens-notes.md`, `composition.md`), compose both `strategy-draft.md` and `strategy-notes.md` from those artifacts rather than reconstructing from the chat transcript. For `strategy-notes.md`, the "Interview state" section maps from `state.md`, "What I heard" and "Assumptions" draw from `evidence.md`, lens-specific sections pull from `lens-notes.md`, and the overall structure follows `composition.md`. For `strategy-draft.md`, the confirmed kernel, exclusions, and success signals come from `composition.md`, with supporting evidence from `evidence.md`. This prevents context-decay drift in long interviews.
- After writing, give a short chat summary: diagnosis in one sentence, guiding policy in one sentence, top open question. Then stop.
