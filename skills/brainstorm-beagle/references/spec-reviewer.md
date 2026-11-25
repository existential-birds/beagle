# Spec Self-Review Checklist

Run this review after drafting the spec. Fix issues inline — don't flag them and move on.

## Review Dimensions

### 1. Completeness

| Check | What to look for |
|-------|-----------------|
| No placeholders | TBD, TODO, "to be determined", empty sections, ellipsis as content |
| Core Value exists | One sentence that resolves prioritization conflicts |
| Problem is concrete | Specific problem, specific people, specific pain — not abstract |
| Requirements are testable | Every requirement can be verified by observation |
| Out of Scope has reasons | Every exclusion explains WHY, not just WHAT |
| Constraints have rationale | Every constraint explains WHY it's a hard limit |

### 2. Consistency

| Check | What to look for |
|-------|-----------------|
| No contradictions | Requirements don't conflict with each other or with constraints |
| Scope alignment | Must-have requirements match the problem statement |
| Decision coherence | Key decisions don't undermine each other |
| Out of Scope respected | Nothing in requirements contradicts an explicit exclusion |

### 3. Implementation Leakage

**This is the most common failure mode.** Scan every requirement for:

| Leaked | Clean |
|--------|-------|
| "Create a REST API endpoint" | "Service exposes data to third-party integrations" |
| "Use WebSocket for real-time" | "Updates appear within 1 second without page refresh" |
| "Store in a relational database" | "Data persists across sessions and survives restarts" |
| "Build a React component" | "User sees a filterable list of results" |
| "Add a cron job" | "Report is generated daily and available by 9am" |

**Exception:** Constraints section may contain implementation-specific limits ("Must use PostgreSQL") when these are genuine external constraints with rationale.

**The test:** Could this requirement be satisfied by two completely different technical approaches? If yes, it's clean. If it implies exactly one approach, it's leaked.

### 4. Testability

Every requirement should pass the "how would you verify this?" test:

- **Good:** "User can undo the last action" — verify: perform action, press undo, confirm reversal
- **Bad:** "Intuitive undo support" — verify: ???

Rewrite any requirement where "verify" isn't obvious.

### 5. Atomicity

Each requirement should be one thing:

- **Bad:** "Users can search, filter, and sort results"
- **Good:** Three separate requirements — search, filter, sort

Compound requirements hide scope and make prioritization impossible.

### 6. Scope

Is this focused enough for a single planning cycle?

- More than 15 must-have requirements? Probably needs decomposition.
- Requirements spanning multiple independent subsystems? Decompose.
- Could you explain the core loop in 30 seconds? If not, it's too broad.

### 7. Reinvention (brownfield only)

For a feature being added to an existing codebase, the most expensive miss is specing a capability the code already has. The *Prior Art Check* step (in SKILL.md) should have run before drafting — this is the backstop.

| Check | What to look for |
|-------|-----------------|
| No duplicated capability | No must-have rebuilds something a neutral capability-keyword grep across the whole workspace would surface |
| Framing not trusted | The spec didn't inherit an issue/brief claim that "X was removed / doesn't exist" without disproving it against current code |
| Build-on recorded | Where prior art exists, a Key Decision says whether to extend it or replace it, and why |

If the prior art check was skipped, run it now: `grep -riE '<capability synonyms>'` across all source roots before approving. One matching file means a requirement needs reframing from "build X" to "extend/fix/wire-up the existing X."

### 8. Consumer (brownfield only)

A must-have that introduces new externally-facing surface with no named consumer is speculative — it can't be planned or verified.

| Check | What to look for |
|-------|-----------------|
| Surface has a consumer | A must-have introduces new externally-facing surface (API surface, command, endpoint, exported contract) but nothing else in the spec consumes it |
| Consumer is named | Where such surface exists, the spec names who/what consumes it — not left implicit |

If who/what consumes the surface isn't named, either name the consumer or move the item to *Future Considerations* before approving.

### 9. Composition (brownfield only)

For an existing mechanism the prior-art sweep surfaced that sits upstream or downstream in the same data pipeline, "the mechanism exists" is not the end — its composition with the new feature is the load-bearing question.

| Check | What to look for |
|-------|-----------------|
| Pipeline interaction surfaced | A surfaced mechanism sits upstream/downstream in the same data pipeline and transforms (truncate, filter, buffer, reorder, dedupe) the data the feature depends on |
| Composition recorded | The interaction is recorded as a Key Decision tagged `needs-spike-before-planning`, not left as an unexamined assumption |

A new mechanism that composes wrongly with an existing one in the same pipeline ships broken even though neither piece was reinvented.

## Calibration

**Only fix issues that would cause real problems downstream.**

A downstream planning system acting on this spec should be able to:
- Understand what to build without asking the user again
- Decompose requirements into tasks
- Know what's in scope and what's not
- Understand the constraints they're working within

Minor wording preferences, stylistic consistency, and "sections that could be more detailed" are not issues. Ambiguity that could lead someone to build the wrong thing IS an issue.

**Approve the spec unless there are serious gaps.** Then present to the user for review.
