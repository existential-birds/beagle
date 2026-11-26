# PRFAQ Document Template

Use this skeleton when creating `.beagle/concepts/<slug>/prfaq.md` at the end of Ignition. Fill in the Ignition section immediately; leave Stages 2-5 as empty headings to be completed as each stage transitions. Update the `stage` frontmatter field at every transition.

## The `stage` field

Valid values, in order:

- `ignition-pending` — only written if you pause mid-Ignition (rare)
- `ignition-complete` — Ignition done; Press Release not started
- `press-release-pending` — about to start Press Release
- `press-release-complete` — Press Release drafted and confirmed
- `customer-faq-pending`
- `customer-faq-complete`
- `internal-faq-pending`
- `internal-faq-complete`
- `verdict-pending`
- `pass` — terminal success
- `fail` — terminal failure

Resume-from-stage reads only the first 40 lines of prfaq.md to find this field. Keep the frontmatter at the top of the file.

## Reasoning blocks

Each stage has a visible `### <Stage> Reasoning` subsection — prose, not HTML comments. This keeps the PRFAQ readable as a decision artifact: anyone opening the file in the future sees what was challenged, which framings were rejected, and how research findings shaped the framing. The Reasoning block is part of the stage's output, not metadata.

## Skeleton

Copy everything below the horizontal rule into the new prfaq.md, then fill in.

---

```markdown
---
name: <concept headline — human-readable one line>
slug: <kebab-case slug>
concept_type: commercial | internal | oss
stage: ignition-complete
created: YYYY-MM-DD
---

# <concept name> — PRFAQ

## 1. Ignition

**Customer:** <specific persona — not "developers">

**Problem:** <what the customer does today and why it fails them>

**Stakes:** <what happens if this works; what happens if it doesn't — both sides>

**Solution sketch:** <one paragraph — high-level WHAT, never HOW>

**Concept type:** <commercial / internal / oss — one-sentence rationale>

### Ignition Reasoning

- **Challenged assumptions:** <what the coach pressure-tested during the opening exchanges>
- **Rejected framings:** <alternatives considered and why dropped>
- **Companion findings:** <pointers to `analysis/report.md` and `research/report.md`, and one sentence each on how they shaped the framing>
- **Unverified claims:** <only if web-tools-unavailable was hit — claims that would have been checked>

## 2. Press Release

**Headline:** `<CITY, DATELINE>` — <one-line announcement>

**Sub-heading:** <concrete customer benefit in one sentence>

**Opening paragraph:**
<who's announcing, what it is, who it's for, why now. Plain English.>

**Problem paragraph:**
<the status quo this replaces — what the customer does today, how it fails them>

**Solution paragraph:**
<what the product does — WHAT, not HOW. No architecture, no technology names unless part of customer value.>

**Customer quote:**
> "<real-sounding quote — a specific frustration relieved or a specific outcome achieved>"
> — <named persona, title, company/context>

**How to get started:**
<concrete first action — link, URL, install command, whatever's real>

### Press Release Reasoning

- **Rejected headlines:** <drafts considered and why dropped>
- **Weasel words caught:** <phrases the coach pushed back on>
- **Differentiators explored:** <positioning choices made; alternatives discussed but not taken>
- **Out-of-scope that surfaced:** <technical constraints, timeline, team context that came up but don't belong in the PR>

## 3. Customer FAQ

### Q1: <hard skeptic question>
<honest answer — specific, committed, no hedging>

### Q2: <hard skeptic question>
<honest answer>

### Q3: <hard skeptic question>
<honest answer>

<... 6-10 questions total. At least one should be "the hard question they're afraid of" — the objection the user most wants to avoid.>

### Customer FAQ Reasoning

- **Gaps revealed:** <what the questions surfaced that the Press Release glossed over>
- **Trade-offs decided:** <for each gap: launch blocker / fast follow / accepted limitation — and why>
- **Competitive intelligence:** <comparisons that came up, with pointers to research/report.md where relevant>
- **Scope signals:** <MVP-in and MVP-out claims made during the Q&A>

## 4. Internal FAQ

### Q1 (Engineer): <feasibility question>
<honest answer>

### Q2 (Finance / ROI / Sustainability): <economics question, calibrated by concept type>
<honest answer>

### Q3 (Legal / Compliance): <regulatory / privacy / licensing question>
<honest answer>

### Q4 (Ops): <on-call / support / maintenance question>
<honest answer>

### Q5 (CEO-analog): <strategic fit question>
<honest answer>

<... 6-10 questions total across the panel. Rotate stakeholder voices. At least one should be "the thing that keeps them up at night" — the unspoken risk.>

### Internal FAQ Reasoning

- **Feasibility risks:** <what survived scrutiny, what didn't>
- **Resource / timeline estimates:** <with honesty markers: guessed / based-on-similar-work / costed-in-detail>
- **Unknowns with action:** <for each unknown: what it would take to find out, by when>
- **Strategic positioning decisions:** <named bets, named alternatives rejected>
- **Constraints surfaced:** <technical dependencies, legal/compliance boundaries, team availability>

## 5. Verdict

**Result:** PASS | FAIL

### Forged in steel
<parts of the concept that are clear, compelling, and defensible — these survived pressure>

### Cracks in the foundation
<for PASS: minor gaps worth watching; for FAIL: the lethal cracks>
- <crack> — to address: <what it would take>
- <crack> — to address: <what it would take>

<on PASS, add:>
### Handoff
Brief written to `.beagle/concepts/<slug>/brief.md`. Consumed by `brainstorm-beagle` to produce the spec.

<on FAIL, add:>
### What would need to change
1. <concrete change>
2. <concrete change>

### Where to re-enter
Stage `<N>: <name>`. <One sentence on why starting there, not from scratch — the earlier stages that succeeded are reusable.>
```
