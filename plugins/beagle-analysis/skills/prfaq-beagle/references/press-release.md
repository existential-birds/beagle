# Stage 2: Press Release

The forge. The user drafts the announcement of the finished product — in the voice of the customer's world, not the builder's. If this stage feels easy, it hasn't been pressured enough.

Load this file when prfaq.md `stage` is `press-release-pending`. At the transition gate at the end of this file, write `stage: press-release-complete` when the draft is confirmed, then write `stage: customer-faq-pending` when the user agrees to move to Stage 3. Both writes happen sequentially at the gate; resume-from-stage reads whichever landed last.

## Approach — one section at a time

For each section of the press release, run the cycle:

1. **You draft first.** Write a rough version based on Ignition's customer, problem, stakes, and solution sketch. Modeling the register gives the user something to react to — faster than asking them to draft cold.
2. **Self-challenge out loud.** Identify the weakest line in your own draft. *"The headline says 'revolutionary' — what does that actually mean to the customer?"* This models the critical posture you want the user to bring to their own version.
3. **Invite the user to sharpen.** Ask for their version or their edit. Hand them the pen.
4. **Deepen one level.** If they give you a generality, demand the specific. If they give you marketing speak, demand customer language.

Cycle per section: *draft → self-challenge → invite → deepen.* Don't move to the next section until the current one clears the quality bars.

## Press release structure

1. **Headline.** `<CITY, DATELINE>` — one-line announcement. Concrete benefit, no jargon.
2. **Sub-heading.** One sentence customer benefit. *Most excited customer gets what.*
3. **Opening paragraph.** Who's announcing, what it is, who it's for, why now. Plain English.
4. **Problem paragraph.** The status quo this replaces. What the customer does today, how it fails them.
5. **Solution paragraph.** What the product does — still WHAT, not HOW. No architecture, no technology names unless they're part of the customer-visible value.
6. **Customer quote.** A real-sounding quote from a named persona. The quote should be something a skeptical friend would send without rolling their eyes.
7. **How to get started.** Concrete first action — link, install command, CTA.

## Quality bars — embodied, not listed

Challenge every draft against these. Do NOT read them aloud to the user. Catch violations as they happen.

- **Mom test.** Would a smart non-expert understand what this is and why it matters? If not, there's jargon to kill or abstraction to concretize.
- **So-what test.** For every claim, ask: *and? so what? why does the customer care?* Each line has to survive the drill.
- **No weasel words.** Ban *significantly, revolutionary, seamless, cutting-edge, leverage, enterprise-grade, best-in-class, robust.* If the user reaches for one, ask: *measured how, compared to what?*
- **No technology-for-its-own-sake.** *"Uses AI"* is not a benefit. *"Writes your status update in 10 seconds"* is. Only name technology when it's the customer-visible value.
- **Real quote.** *"This saves our team hours"* is a placeholder, not a quote. A real quote sounds like a real person complaining about a specific frustration or celebrating a specific outcome. Name the persona specifically (not "Jane, IT manager").

## Concept-type calibration

| Section | Commercial | Internal | OSS |
|---|---|---|---|
| Headline frame | *"Company X launches Y"* | *"Team X rolls out Y"* | *"Project X releases Y"* |
| Sub-heading | customer benefit, market position | operational leverage, cost avoided | adopter benefit, ecosystem fit |
| Problem | what paying customers put up with today | what employees waste hours on today | what contributors / adopters re-solve today |
| Customer quote | paying customer persona | internal user with a specific role | early adopter, maintainer, or downstream user |
| How to get started | *"Sign up at..."* | *"Available in `<internal tool>` now"* | *"`pip install X`"*, *"`git clone ...`"* |

## Coaching-notes capture

After Press Release is drafted and confirmed, write the Reasoning block in prfaq.md:

- **Rejected headlines.** Drafts considered and why dropped. One-liners — just enough to trace the decision.
- **Weasel words caught.** The phrases the coach pushed back on and what replaced them.
- **Differentiators explored.** Positioning choices made; alternatives discussed but not taken.
- **Out-of-scope that surfaced.** Technical constraints, timeline, team context that came up but don't belong in a press release.

## Transition gate

Read the full press release back to the user as a single block. Ask:

> "If I sent this to the most skeptical customer you know, would they read past the headline? If yes, we move to Customer FAQ. If you're hesitating, we fix it now — skepticism compounds in Stage 3."

Only move to Stage 3 after the user confirms. Update `stage: customer-faq-pending` in prfaq.md frontmatter and load `references/customer-faq.md`.

## When the user is stuck

Do not repeat questions harder. Offer concrete alternatives:

- **Two headline drafts, different frames.** *"Headline A leads with the benefit; headline B leads with the pain relieved. Which matches how your customer would describe it?"*
- **A counter-example.** *"Here's what the bad version sounds like: `<weasel-word-heavy draft>`. What would your customer say that version misses?"*
- **A forced constraint.** *"Write the opening paragraph in 40 words or fewer. What survives the cut is the actual value."*
- **Borrow from research.** *"The research report's Key Insights #2 said `<X>`. Does that belong in the sub-heading, the problem paragraph, or neither?"*

The goal is always to give the user something concrete to react to. A blank prompt in Stage 2 is a failure of coaching.
