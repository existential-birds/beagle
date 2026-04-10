# Review Output Template

For formal or file-output reviews, produce one file: `strategy-review.md`. Write it in the user's working directory unless they specify otherwise. If the user asked for quick feedback or a chat-only take, deliver findings inline instead — see the chat-only branch in SKILL.md Step 5. This template applies only when file output is confirmed.

The tone is direct and specific. Every finding must point to evidence in the document. Every recommendation must be concrete enough that the author can act on it without asking "but what specifically should I do?"

---

```markdown
# Strategy Review: [subject from the strategy document]

_Review of [document name(s)]. Reviewed on [date]._

## Review Summary

[3-4 sentences. What this strategy is trying to do, the overall assessment of its structural integrity, and the single most important thing that needs attention. Don't bury the lede — if the strategy has a critical structural flaw, say it here.]

## What Works

[Specific strengths. Name what the author should protect and build on. This isn't a politeness section — genuinely good elements help anchor what "good" looks like for the rest of the review. 2-4 bullet points, each with a specific citation from the document.]

- **[Strength]**: [Why it works, with reference to the specific passage.]

## Critical Findings

_The 2-4 issues that most undermine the strategy's integrity. These should be addressed before the strategy is shared or acted on. Ordered by severity — most critical first. Lead with these because they are the highest-value part of the review._

### Finding 1: [Title — short, specific]

**Severity:** [Critical / Serious / Moderate]

**What's wrong:** [Specific description of the gap, risk, or failure path.]

**Why it matters:** [What goes wrong in execution if this isn't addressed.]

**Evidence:** [Passage from the document that demonstrates the issue.]

**Recommended fix:** [Concrete action to address it.]

### Finding 2: [Title]
...

## Dimension Ratings

_Supporting detail behind the critical findings. Each dimension evaluates one aspect of the strategy's structural integrity._

### 1. Diagnosis Quality — [Strong / Adequate / Weak / Missing]

**Assessment:** [2-3 sentences on what the diagnosis does well or poorly.]

**Evidence:** [Quote or cite the relevant passage.]

**Recommendation:** [If Adequate or below — specific guidance on what to change. Skip for Strong.]

### 2. Guiding Policy Strength — [Strong / Adequate / Weak / Missing]

**Assessment:** [2-3 sentences.]

**Evidence:** [Quote or cite.]

**Recommendation:** [If needed.]

### 3. Action Coherence — [Strong / Adequate / Weak / Missing]

**Assessment:** [2-3 sentences.]

**Evidence:** [Quote or cite. Name specific action pairs that reinforce or conflict.]

**Recommendation:** [If needed.]

### 4. Kernel Chain Integrity — [Strong / Adequate / Weak / Missing]

**Assessment:** [Read the strategy as "[Diagnosis]. Therefore, [policy]. Which means [actions]." Does it hold?]

**The chain:** [Write it out as a single paragraph. This makes gaps visible.]

**Recommendation:** [If needed. Name the weakest link.]

### 5. Bad-Strategy Patterns — [Strong / Adequate / Weak / Missing]

**Assessment:** [Which patterns, if any, are present.]

**Evidence:** [Quote specific passages for each pattern found. Name the hallmark.]

**Recommendation:** [For each pattern found — how to fix it.]

### 6. Assumption Exposure — [Strong / Adequate / Weak / Missing]

**Assessment:** [Are load-bearing assumptions identified?]

**Unstated assumptions found:** [List assumptions the reviewer identified that the document doesn't state.]

**Recommendation:** [If needed.]

### 7. Specificity and Falsifiability — [Strong / Adequate / Weak / Missing]

**Assessment:** [Could you evaluate this strategy in 12 months?]

**Evidence:** [Point to specific vague or unfalsifiable claims.]

**Recommendation:** [If needed.]

## Failure Path Analysis

_How this strategy could fail — not through dramatic crisis, but through the predictable patterns that kill most strategies. These are the risks the author may not have fully accounted for._

### [Failure path name — e.g., "Capability gap stalls the load-bearing action"]

**The scenario:** [Describe the failure path in concrete terms. What happens, in what order?]

**Likelihood:** [High / Medium / Low — and why.]

**Current mitigation:** [What, if anything, does the strategy do to prevent this? "None" is a valid answer.]

**Suggested mitigation:** [What would reduce the risk.]

### [Next failure path]
...

## Assumption Risk Map

_Load-bearing assumptions ranked by (impact if wrong) x (uncertainty). Focus on the assumptions that could break the strategy, not background assumptions._

| Assumption | Stated in doc? | Impact if wrong | Uncertainty | Risk |
|-----------|----------------|----------------|------------|------|
| [assumption] | Yes / No | High / Medium / Low | High / Medium / Low | [H x H = Critical, etc.] |
| ... | | | | |

[For the top 2-3 highest-risk assumptions, add a paragraph: what happens if this assumption is wrong, and what could the author do now to test it or reduce exposure.]

## Lens Findings

_Include this section when complementary review lenses (7S, Scorecard, Five Forces, Hoshin Kanri) were applied during the review, OR when interview lenses (landscape mapping, choice cascade, value innovation) appear in the strategy document or notes. Omit entirely if neither applies._

**Review lenses applied:** [List which review lenses were activated and why — the trigger condition observed in the document.]

**What the review lenses revealed:**

[For each applied review lens, describe what it found that the core seven dimensions alone would likely have missed. Focus on systemic gaps — the kind that span multiple dimensions or create failure paths the standard review might not catch. 2-4 findings total across all applied lenses.]

- **[Lens name] — [Finding title]**: [What the lens revealed. Point to the specific gap, unstated assumption, or misalignment. Reference the dimension where the finding was also recorded.]

**Interview lens audit:** [Include this subsection only when the strategy document or notes show that Wardley mapping, Playing to Win cascade, or Blue Ocean value innovation analysis was done during the interview.]

[For each interview lens that was applied, assess whether its findings survived into the draft. Did landscape mapping insights sharpen the diagnosis? Did cascade capability gaps appear in assumptions? Did ERRC moves shape the coherent actions? Flag interview lens findings that were dropped or softened — these often represent the sharpest strategic thinking that got polished away.]

- **[Interview lens] — [Assessment]**: [Whether the lens findings are reflected in the draft, partially reflected, or missing. If missing, what was lost.]

## Notes Cross-Reference

_Include this section only when strategy-notes.md or equivalent reasoning notes were available for review._

- **Open questions still open:** [Which questions from the notes remain unresolved in the draft? Are any of them show-stoppers?]
- **Patterns that crept back:** [Bad-strategy patterns caught during the interview that reappeared in the draft, possibly in softer language.]
- **Thinking that was sharpened then softened:** [Places where the notes show a sharper version of the diagnosis or policy than the draft contains.]
- **Lens findings not reflected:** [Landscape mapping, cascade, or value innovation findings from the notes that didn't make it into the draft.]

## Recommended Next Steps

_Ordered by impact. What should the author do with this review?_

1. **[Action]** — [Why this is the highest priority, what it addresses.]
2. **[Action]** — ...
3. **[Action]** — ...
```

---

## Notes on producing the review

- Write the review file in the user's working directory unless they specify another location.
- Quote the document. Don't make assertions about what it says — point to the passages. "The diagnosis states: '[quoted text]'" is credible. "The diagnosis is vague" without evidence is not.
- Keep the review proportional to the document. A short strategy memo doesn't need a 2000-word review. Match depth to depth.
- Critical Findings come before Dimension Ratings because they are the highest-value section. A reader who stops after Critical Findings should still walk away with the most important feedback. Dimension Ratings provide the supporting evidence and complete picture.
- The Failure Path Analysis section is where the most unique value lives. Most reviewers tell you what's wrong with the document; this section tells you what could go wrong in the *real world* because of what's in (or missing from) the document. Invest thought here.
- If the notes cross-reference reveals that the interview produced better thinking than the draft contains, say so directly. Drafts often smooth away the edges that made the thinking sharp.
- After writing, summarize in chat: overall assessment in one sentence, the single most important finding, and the recommended next action. Then stop.
