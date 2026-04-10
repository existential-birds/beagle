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

## What success looks like in [timeframe]

[3-5 observable indicators. Not metrics for their own sake — leading signals that the guiding policy is working.]
```

---

## `strategy-notes.md` — the reasoning companion (not for sharing)

The messy, honest file. For the user's own use — shared thinking, not a polished deliverable.

```markdown
# Strategy Notes — [subject]

_Companion to strategy-draft.md. Internal thinking, open questions, things that were pushed back on. Not for circulation._

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

## What I'd sharpen next

[Candid take on the one or two parts of the kernel that still feel weakest, and what evidence or thinking would strengthen them. Don't skip this to be polite — it's the most useful paragraph in the file.]
```

---

## Notes on producing the files

- Write both files in the user's current working directory unless they've specified another location.
- Use the user's language where possible; don't over-polish into management-speak.
- If the kernel is genuinely incomplete — e.g., the diagnosis is still fuzzy — **say so in the draft itself.** Mark the weak section as `[DRAFT — diagnosis still under development, see notes]` rather than papering over it. An honest placeholder is better than fake confidence.
- The "At a glance" section is for upward communication — a busy stakeholder should be able to read just this block and understand the strategy. Write it last, after the full document is done.
- After writing, give a short chat summary: diagnosis in one sentence, guiding policy in one sentence, top open question. Then stop.
