# Stage 3: Customer FAQ

The devil's advocate stage. You ARE the most skeptical customer. Ask 6-10 hard questions that stand between interest and adoption — not softballs, not onboarding FAQs.

Load this file when prfaq.md `stage` is `customer-faq-pending`. At the transition gate at the end of this file, write `stage: customer-faq-complete` when the FAQ is confirmed, then write `stage: internal-faq-pending` when the user agrees to move to Stage 4. Both writes happen sequentially at the gate; resume-from-stage reads whichever landed last.

## Approach

1. **Read the Press Release out loud.** Identify the claims and omissions a skeptical customer would probe. Mark the soft spots.
2. **Generate 6-10 hard questions.** Draft them in a batch, then walk through them one at a time with the user. Every question must be something a real skeptical customer would ask.
3. **Draft honest answers.** For each question, draft what the honest answer would be. Then challenge the answer:
   - Vague? Demand specificity.
   - Handwavy? Demand a concrete mechanism.
   - *"We don't do that yet"*? Fine — but make it explicit and force a trade-off decision.
4. **Force trade-off decisions when gaps surface.** For every gap the question exposes, the user commits to one of three: **launch blocker**, **fast follow**, **accepted limitation**. That commit goes in the FAQ answer AND in the Reasoning block.

## What counts as a hard question

Hard customer questions target:

- **Trust.** *"Why should I believe you can deliver this?"*
- **Risk.** *"What happens to my data / workflow / team if this breaks?"*
- **Switching cost.** *"I'm already using `<X>` — what does moving cost me?"*
- **Edge cases.** *"What about `<non-standard scenario>`?"*
- **Comparison.** *"How is this different from `<incumbent or adjacent tool>`?"*
- **The hard question they're afraid of.** The objection the user most wants to avoid — that's the one that matters most.

At least one question should come from the research report (`research/report.md` Findings or Gaps & Limitations). The research exists to sharpen customer objections, not to decorate the press release.

## What doesn't count

- **Onboarding-as-FAQ.** *"How do I get started?"* is a CTA, not a FAQ.
- **Softballs.** *"Does this integrate with everything?"* — too easy; real customers don't ask this.
- **Handwavy positioning.** *"What's your moat?"* — real customers don't talk like that; they ask about specific alternatives.

## Coaching on answers

| User's answer | Coach response |
|---|---|
| *"We have enterprise-grade security."* | *"Name the specific certifications, or say 'not yet.' Which one?"* |
| *"It just works."* | *"Walk me through the path when it doesn't. What's the recovery?"* |
| *"We'll figure it out."* | *"This is Stage 3, not Stage 1. What's the concrete plan, or is this launch-blocker / fast-follow / accepted?"* |
| *"We don't do that yet."* | Fine. Commit: launch-blocker, fast-follow, or accepted. Don't hedge. |
| *"Our competitors can't do this."* | *"Which competitors? What specifically can't they do? Is that true in their current release or just historically?"* |

## Concept-type calibration

The categories of skepticism shift by concept type. Keep the Q&A in the customer's vocabulary.

| Question category | Commercial | Internal | OSS |
|---|---|---|---|
| Trust | track record, SLAs, customer references | who owns it when it breaks at 2am | who maintains it, bus factor, release cadence |
| Risk | data exfil, vendor lock-in, price escalation | operational dependency on one team | project abandonment, fork risk, license change |
| Switching cost | migration off incumbent, retraining | retraining, workflow disruption | adoption effort, integration with existing stack |
| Comparison | named commercial competitors | existing internal tools, buy-vs-build | named upstream or alternative OSS projects |
| Edge cases | scale, compliance, specific customer segments | non-standard workflows, edge teams | non-standard environments, less-common use cases |

## Coaching-notes capture

After Customer FAQ is drafted and confirmed, write the Reasoning block in prfaq.md:

- **Gaps revealed.** What the questions surfaced that the Press Release glossed over. Be specific — which question, which claim.
- **Trade-offs decided.** For each gap: launch-blocker / fast-follow / accepted — and a one-sentence rationale.
- **Competitive intelligence.** Comparisons that came up, with pointers to `research/report.md` sections where relevant.
- **Scope signals.** MVP-in and MVP-out claims made during the Q&A. These feed the brief on pass and `brainstorm-beagle`'s scope discipline downstream.

## Transition gate

Read the full FAQ back. Ask:

> "If I handed this to the most skeptical customer you know, would any of these answers make them close the tab? If yes, we fix those now. If not, Internal FAQ is next — the drill moves inside."

Move to Stage 4. Update `stage: internal-faq-pending` in prfaq.md and load `references/internal-faq.md`.

## When the user is stuck

- **Offer three draft questions, different angles.** *"Here are three questions I'd ask if I were your skeptic — cost, risk, switching. Which feels hardest to answer honestly?"*
- **Pose the question you think they're avoiding.** *"The question I'd expect from your skeptic is `<X>`. Do you have an answer, or is this a gap?"*
- **Return to research.** *"`research/report.md` Findings flagged `<gap>`. What's the customer question that gap implies?"*
- **Invoke the research comparison.** *"The research surfaced these alternatives: `<A>`, `<B>`, `<C>`. Which one does your skeptic already use, and why are they considering switching?"*
