# The Kernel of Good Strategy

A strategy's kernel contains three elements — **diagnosis**, **guiding policy**, and **coherent action**. Everything else (vision, mission, values, goals, OKRs) is scaffolding around this or, more often, a distraction from it.

## 1. Diagnosis

**What it is:** A judgment about the nature of the situation. It names the challenge and simplifies an overwhelming reality into something the decision-maker can grip and act on.

**What makes it good:**
- Specific enough that you could imagine being wrong about it.
- Often uses a metaphor, analogy, or reference to a previously understood situation ("this is a classic commoditization problem," "we're in the position IBM was in around 1990").
- Reduces complexity by identifying the *one or two* things that matter most, not by listing everything.
- Uncomfortable. A diagnosis that makes everyone nod happily is probably not a real diagnosis — it's a restatement of the ambition.

**What makes it bad:**
- "We need to grow faster." (Goal, not diagnosis.)
- "The market is changing." (Vague. Changing *how*, and *why does that matter for us specifically*?)
- "We have execution problems." (Where? On what? Caused by what?)
- Long lists of challenges with no weighting. A good diagnosis picks.

**Interview prompts to sharpen a diagnosis:**
- "If you had to describe this situation to a smart outsider in three sentences, what would you say?"
- "What is the *one* thing that, if it were different, would change everything?"
- "What are people inside the org afraid to say out loud about this?"
- "Is there an analogy — another company, another industry, a historical moment — that this reminds you of?"

## 2. Guiding Policy

**What it is:** The overall approach chosen to cope with or overcome the obstacles identified in the diagnosis. A directional choice — a way of channeling action — not a specific plan and not a goal.

A useful test: a guiding policy **rules things out**. If it doesn't exclude any reasonable option, it isn't doing work.

**What makes it good:**
- Creates advantage by anticipating actions and reactions, reducing ambiguity, exploiting asymmetries, or creating coherent policies.
- Short. One or two sentences.
- A *choice* — there was a plausible alternative that was rejected.
- Focuses force on a pivot point where concentrated effort can break something loose.

**What makes it bad:**
- "Be the best in class." (Best at what? Via what mechanism?)
- "Focus on the customer." (Who isn't claiming this?)
- Anything a direct competitor could adopt verbatim without contradiction.

**Examples of real guiding policies:**
- "Compete on service depth in the segment the incumbents find unprofitable to serve well, and refuse work outside it."
- "Rebuild the platform around a single primary workflow before adding any new feature surface."
- "Trade near-term margin for distribution lock-in in the two geographies where the competitor is weakest."

**Interview prompts:**
- "What does this approach explicitly *not* do?"
- "If a competitor copied this word-for-word tomorrow, would it still be a good plan for us?"
- "What's the asymmetry we're exploiting? What do we have, or know, or can tolerate, that they can't?"

## 3. Coherent Action

**What it is:** The concrete, resourced, mutually reinforcing steps that carry out the guiding policy.

The operative word is **coherent**. Individual actions can be fine; a set of actions that pull in different directions is not a strategy, it's a to-do list with ambitions.

**What makes it good:**
- Each action is concrete enough to tell next quarter whether it happened.
- Actions reinforce each other: doing A makes B easier, B makes C cheaper, C protects A.
- The set has focus — usually 3 to 6 things, not 15.
- Resources (money, people, attention) are actually redirected to match. If the action list doesn't change how the budget or calendar looks, it isn't real.

**What makes it bad:**
- The "dog's dinner" — a long undifferentiated list of everything everyone wants.
- Actions that quietly contradict each other (e.g., "move upmarket" and "cut prices to win SMB deals").
- Actions with no owner, no resourcing, and no way to tell if they happened.
- Things that would have happened anyway, relabeled as strategic.

**Interview prompts:**
- "Of these actions, which one is load-bearing? If that one fails, does the rest still work?"
- "Does action B make action A easier or harder? Walk me through it."
- "What are we going to stop doing to make room for these?"
- "Who owns each of these, and what changes on their calendar on Monday?"

## The kernel as a whole

The three parts have to fit. A sharp diagnosis with a vague guiding policy is useless. A clever guiding policy with incoherent actions dies in execution. Coherent actions in service of no diagnosis is a well-run busywork factory.

When reviewing a draft kernel, ask: **does the guiding policy actually address the diagnosis, and do the actions actually carry out the guiding policy?** If you can't trace the line from action back to diagnosis, something is broken — go back and fix it before writing the document.

## Worked example: a complete kernel

**Company:** Fieldkit — a 90-person B2B SaaS company selling inspection-management software to mid-size commercial property firms. $14M ARR, growing 30% YoY until last year, when growth dropped to 11%.

**Diagnosis:** Fieldkit's growth stalled because its two largest competitors (BuildOps, FacilityIQ) launched mobile-first products while Fieldkit remained desktop-oriented. 68% of inspections happen on-site with a phone, but Fieldkit's mobile experience is a responsive web wrapper that drops offline and loses data. The company has been treating mobile as a feature request rather than the core delivery surface. Meanwhile, the sales team is compensating by moving upmarket to enterprise accounts where desktop workflows still dominate — but Fieldkit lacks SOC 2 certification, SSO, and audit trails that enterprise buyers require. The company is drifting into a segment it cannot win while abandoning the mid-market segment where its domain expertise is strongest.

**Guiding policy:** Dominate mobile-first inspection workflows for mid-market commercial property firms (50–500 properties) and stop pursuing enterprise deals until the core product is defensible. Fieldkit will not build enterprise compliance features this year. It will not try to match BuildOps on breadth of facility management. It will win on reliability and speed of the on-site inspection experience specifically.

**Coherent actions:**
1. Ship a native mobile app with full offline sync by Q3 — this is the load-bearing action; everything else depends on it.
2. Kill the enterprise sales motion: reassign the two enterprise AEs to mid-market and cancel the SOC 2 engagement ($180K saved, redirected to mobile engineering).
3. Build an integration with HappyCo and Yardi (the two property-management systems 70% of mid-market customers already use) to make Fieldkit's inspection data flow automatically into existing workflows.
4. Launch a "reliability guarantee" — if an inspection is lost due to sync failure, Fieldkit credits the account. This forces engineering accountability and becomes a sales differentiator.

**Why this holds together:** The diagnosis identifies a specific structural mistake — chasing enterprise to escape a mobile gap — not a generic "we need to grow." The guiding policy makes a painful cut (enterprise) to concentrate resources where the company actually has an edge (deep inspection-workflow knowledge in mid-market). Each action reinforces the others: the native app (1) makes the reliability guarantee (4) credible; killing enterprise (2) frees the budget and headcount for the app; the integrations (3) raise switching costs once customers adopt mobile, protecting the position the app creates. A competitor reading this strategy could not copy it without also abandoning their enterprise pipeline, which is exactly the kind of commitment that makes a strategy real.
