# Stage 5: Verdict, Brief, Fail Feedback

Binary outcome. No three-tier middle ground — a concept that is "promising but needs work" returns **FAIL** with targeted feedback naming exactly what would need to change. That is the filter's whole job.

Load this file when prfaq.md `stage` is `verdict-pending`. Terminal states are `pass` or `fail`.

## Rubric

The concept **PASSES** when ALL of these are true after the full gauntlet:

1. **Customer is named.** A specific persona, not a category. *"Enterprise platform engineers at companies with >200 engineers and a dedicated developer-productivity team"* beats *"developers."*
2. **Problem is concrete.** Described in terms of what the customer does today and why it fails them.
3. **Stakes are clear on both sides.** What happens if this works AND what happens if it doesn't.
4. **Solution survived the Press Release drill.** No weasel words, no technology-for-its-own-sake, passes the mom test and the so-what test.
5. **Customer FAQ has no lethal gaps.** Trade-offs are committed (launch-blocker / fast-follow / accepted). Comparisons are honest.
6. **Internal FAQ has no lethal gaps.** Feasibility, economics (calibrated per concept type), and risk have honest answers. Unknowns have actions and timelines.

The concept **FAILS** when one or more of:

- Customer remained vague through all four prior stages.
- Problem is a solution-in-search-of-a-problem (the user leads with what they want to build, not what the customer needs).
- Stakes are missing on one side (*"this would be cool"* without *"and if we don't, here's what breaks"*).
- Press Release still required weasel words to sound compelling.
- Customer FAQ has a *skeptic-closes-the-tab* question with no plan for it.
- Internal FAQ has feasibility / economic / legal red flags with no mitigation.
- Research findings directly contradict a load-bearing claim and the user did not reconcile the contradiction.

## Framing: "forged in steel" vs "cracks in the foundation"

Present the verdict as specific findings, not a score.

- **Forged in steel.** Parts of the concept that are clear, compelling, and defensible — these survived pressure.
- **Cracks in the foundation.** Genuine risks or unresolved contradictions. For every crack, name what it would take to address.

Present the verdict directly. Do NOT soften it to be polite. A soft verdict defeats the filter. Constructive framing ≠ soft framing — name the cracks specifically and name what closing them looks like.

## On PASS: produce the brief

Write `.beagle/concepts/<slug>/brief.md`. The brief is a **context handoff** for `brainstorm-beagle`, not a deliverable — brief quality is not gated; `brainstorm-beagle` runs its own discovery on top. Keep it dense and factual; no coaching notes in the brief itself (those live in prfaq.md Reasoning blocks).

### brief.md template

```markdown
# <concept name> — Concept Brief

**Status:** PASSED PRFAQ on YYYY-MM-DD
**Slug:** <slug>
**Concept type:** commercial | internal | oss

## Customer
<specific persona — one paragraph, straight from prfaq.md Ignition>

## Problem
<what the customer does today and why it fails them — one paragraph>

## Solution concept
<one-paragraph distillation from the Press Release solution section — WHAT, not HOW>

## Stakes
- **If this works:** <outcome>
- **If it doesn't:** <outcome>

## Forged decisions
<bulleted list of decisions committed during the gauntlet:
- MVP-in vs MVP-out choices
- Launch-blocker vs fast-follow vs accepted-gap calls
- Concept-type-specific scope bounds
- Named alternatives rejected and why>

## Open questions
<bulleted list — things the PRFAQ surfaced but did not close. Each with a one-sentence "what it would take to answer" note so brainstorm-beagle knows whether to resolve inline or defer.>

## Research pointers
- Artifact analysis: `.beagle/concepts/<slug>/analysis/report.md`
- Web research: `.beagle/concepts/<slug>/research/report.md`

## PRFAQ reference
`.beagle/concepts/<slug>/prfaq.md` — full drill transcript including Reasoning blocks per stage.
```

### Update prfaq.md Verdict section

```markdown
## 5. Verdict

**Result:** PASS

### Forged in steel
- <finding>
- <finding>
- <finding>

### Cracks worth watching
- <minor gap> — to close: <what it would take>
- <minor gap> — to close: <what it would take>

### Handoff
Brief written to `.beagle/concepts/<slug>/brief.md`. Consumed by `brainstorm-beagle` to produce the spec.
```

Set `stage: pass` in frontmatter.

### Tell the user

> "PRFAQ passed. Brief written to `.beagle/concepts/<slug>/brief.md`. Run `brainstorm-beagle` next — it'll auto-ingest the brief and skip most of its normal discovery."

## On FAIL: targeted feedback

**No brief is produced.** The PRFAQ failed its filter; manufacturing a brief would defeat the purpose.

### Update prfaq.md Verdict section

```markdown
## 5. Verdict

**Result:** FAIL

### What broke
<one paragraph — the specific breakage. Not "it needs more work." Name which stage's question has no honest answer, or which claim doesn't survive the research findings, or which lethal gap was not closed.>

### Cracks in the foundation
- <crack> — to address: <what it would take>
- <crack> — to address: <what it would take>
- <crack> — to address: <what it would take>

### What would need to change
1. <concrete change>
2. <concrete change>
3. <concrete change>

### Where to re-enter
Stage `<N>: <stage name>`. <One sentence on why starting there. Stages earlier than N are reusable — prfaq.md, research/, and analysis/ stay in place; the user can pick up from <N> after addressing the cracks.>
```

Set `stage: fail` in frontmatter. Keep prfaq.md, `research/`, and `analysis/` in place for the re-run. Do NOT delete or archive.

### Tell the user

> "PRFAQ failed at `<stage>`. `<one-paragraph reason>`. See `.beagle/concepts/<slug>/prfaq.md` Verdict section for what to fix. When you've developed those, re-run — we'll resume from `<stage>`."

## Graceful redirect (handled at Ignition, referenced here)

Not every "fail" is a PRFAQ verdict. If during **Ignition** the user cannot articulate a customer or a problem after 2-3 exchanges, issue the *not-ready-to-filter* redirect instead:

> "This idea isn't ready for PRFAQ — it needs brainstorming first. Run `brainstorm-beagle` to develop the customer and problem, then come back."

In the redirect path, NO prfaq.md is written. No research or analysis runs. This is not a FAIL verdict — it is a pre-gauntlet hand-back. Recording it as a fail would pollute the PRFAQ file with non-verdicts.

The verdict rubric above applies only to concepts that made it through all four prior stages. If Ignition bounced the concept, the decision was already made — no Stage 5 is run.

## Why binary

A three-tier verdict ("forged / needs heat / cracked") sounds gentler but defeats the filter. The user walks away feeling graded, not filtered. PRFAQ exists to answer ONE question: *is this worth committing spec cycles to?* The answer is yes or no. Cracks worth watching go into the brief on pass; cracks worth NOT proceeding go into the fail feedback. Either way, the user leaves with a specific next action.
