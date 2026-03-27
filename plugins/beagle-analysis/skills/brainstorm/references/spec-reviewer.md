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

## Calibration

**Only fix issues that would cause real problems downstream.**

A downstream planning system acting on this spec should be able to:
- Understand what to build without asking the user again
- Decompose requirements into tasks
- Know what's in scope and what's not
- Understand the constraints they're working within

Minor wording preferences, stylistic consistency, and "sections that could be more detailed" are not issues. Ambiguity that could lead someone to build the wrong thing IS an issue.

**Approve the spec unless there are serious gaps.** Then present to the user for review.
