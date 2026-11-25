# Stage 4: Internal FAQ

The stakeholder panel. You speak in rotation as engineer, finance/ROI, legal/compliance, ops, and CEO-analog — each brings a different attack surface. 6-10 questions total covering feasibility, economics, risk, and strategic fit.

Load this file when prfaq.md `stage` is `internal-faq-pending`. At the transition gate at the end of this file, write `stage: internal-faq-complete` when the FAQ is confirmed, then write `stage: verdict-pending` when the user agrees to move to Stage 5. Both writes happen sequentially at the gate; resume-from-stage reads whichever landed last.

## The panel

Rotate stakeholder voices across the 6-10 questions. At least one question per role (adapt per concept type — OSS may drop finance; internal may drop legal if not applicable).

- **Engineer.** *"Can we actually build this? What's the hardest technical problem, and do we know how to solve it?"*
- **Finance / ROI / Sustainability.** *"What does this cost, and when does it pay back?"* — Concept-type-dependent (see calibration).
- **Legal / Compliance.** *"What regulatory, privacy, or licensing exposure does this create?"*
- **Ops.** *"Who runs this at 2am? What's the support cost?"*
- **CEO-analog.** *"Why this, and why this instead of `<alternative use of the same resources>`?"*

## Approach

Same as Customer FAQ — generate 6-10 questions, draft honest answers, challenge vagueness. Key difference: stakeholder questions attack the *builder's* side of the equation, not the customer's.

1. **Draft the panel.** 6-10 questions covering the roles above. Rotate voices.
2. **Draft honest answers.** Challenge them line by line.
3. **Force action on unknowns.** Every *"we don't know yet"* gets a follow-up: *"What would it take to find out, and when do you need to know by?"* Unexamined unknowns are not acceptable; honest unknowns with an action plan are fine.
4. **Watch for over-optimism.** Resources and timeline are the two most commonly hand-waved answers. Demand breakdowns.

## What counts as a hard question

- **Feasibility.** *"What's the hardest technical problem, and do we know how to solve it?"*
- **Unit economics / ROI / sustainability.** Calibrated by concept type. See table below.
- **Resource reality.** *"Who builds this? Over how many weeks? At what cost to other work?"*
- **Risk.** *"What's the worst-case failure mode? How do we detect it before customers do?"*
- **Strategic fit.** *"Why us? Why now? What specific bet does this support?"*
- **The question that keeps them up at night.** The thing that hasn't been said out loud. Name it.

At least one question should come from the research report — either a feasibility finding or a competitive risk the web-research surfaced.

## Watch for

- **Hand-waving on resources.** *"A couple of weeks"* is not a timeline. Break it down: discovery, build, test, rollout. Which is longest?
- **Hand-waving on strategic fit.** *"It aligns with our direction"* means nothing. Which specific direction? Measured how?
- **Unexamined unknowns.** *"We'll figure out pricing later"* → *"launch-blocker or fast-follow? What research decides?"*
- **Legal assumed.** *"Legal is fine"* → *"Did you ask, or are you assuming? What changes if they say no?"*

## Concept-type calibration

Economics, moat, success metric, and failure mode all shift by concept type. Keep the panel questions in the right vocabulary.

| Question | Commercial | Internal | OSS |
|---|---|---|---|
| Economics | unit economics, CAC / LTV, first 100 customers | operational ROI, hours saved, cost avoided | maintenance burden, contributor pipeline, sustainability funding |
| Moat | differentiators, defensibility, network effects | build-vs-buy vs existing internal tools | differentiation from upstream / alternatives, ecosystem fit |
| Success metric | revenue, retention, NPS | adoption rate, outcome metric, time saved | stars, downloads, contributor count, downstream usage |
| Failure mode | customers churn | employees revert to old tools | project abandonment, fork, license dispute |
| Resources | team hire plan, vendor budget | engineering time, team reallocation | maintainer time, contributor onboarding effort |

## Coaching on answers

| User's answer | Coach response |
|---|---|
| *"A couple of weeks."* | *"Break it down: discovery, build, test, rollout. Which phase is longest, and why?"* |
| *"We'll figure out the pricing later."* | *"Launch-blocker or fast-follow? What's the research you'd do to decide?"* |
| *"Legal is fine."* | *"Did you ask legal, or are you assuming? If assuming, what changes if they say no?"* |
| *"It strategically aligns with `<X>`."* | *"Name the specific strategic bet. What does that bet lose if we don't do this?"* |
| *"Engineering can handle it."* | *"Who on engineering, at what opportunity cost to what other work?"* |
| *"Customers will love this."* | *"Stage 3 covered that. This is the builder panel — who on OUR side has to deliver it, and what are they not doing instead?"* |

## Coaching-notes capture

After Internal FAQ is drafted and confirmed, write the Reasoning block in prfaq.md:

- **Feasibility risks.** What survived scrutiny, what didn't.
- **Resource and timeline estimates.** With honesty markers: *guessed / based on similar work / costed in detail.*
- **Unknowns flagged with action.** For each: what it would take to find out, by when.
- **Strategic positioning decisions.** Named bets, named alternatives rejected.
- **Constraints surfaced.** Technical dependencies, legal/compliance boundaries, team availability.

## Transition gate

Read the full FAQ back. Ask:

> "If you walked this into a skeptical steering committee tomorrow, what would they reject it for? If that's already addressed, we move to Verdict. If not, we fix it — the verdict is not the place to find out."

Move to Stage 5. Update `stage: verdict-pending` in prfaq.md and load `references/verdict.md`.

## When the user is stuck

- **Role-play the panel.** *"Speaking as the engineer on call: here's the question I'd ask — `<X>`. What's your answer?"*
- **Apply the research.** *"`research/report.md` Gaps flagged `<X>`. What does the stakeholder panel do with that?"*
- **Force the timeline.** *"If you had to ship this in 4 weeks, what cuts first? In 16 weeks, what do you add?"*
- **Invoke the opportunity cost.** *"If we pour engineering into this, what's the other thing we're not doing? Is that trade worth it?"*
