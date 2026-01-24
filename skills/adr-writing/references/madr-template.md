# MADR Template

> Markdown Any Decision Records (MADR) - https://adr.github.io/madr/

## Template Structure

```markdown
---
status: {draft | proposed | accepted | rejected | deprecated | superseded by [ADR-NNNN](NNNN-title.md)}
date: YYYY-MM-DD
decision-makers: [list of involved people]
consulted: [list of people whose opinions are sought]
informed: [list of people who are kept up-to-date]
---

# {Title: Short imperative statement of decision}

## Context and Problem Statement

{Describe the context and problem statement, e.g., in free form using two to three sentences or in the form of an illustrative story. You may want to articulate the problem in form of a question.}

## Decision Drivers

* {decision driver 1, e.g., a force, facing concern, ...}
* {decision driver 2, e.g., a force, facing concern, ...}
* ...

## Considered Options

* {title of option 1}
* {title of option 2}
* {title of option 3}
* ...

## Decision Outcome

Chosen option: "{title of option 1}", because {justification. e.g., only option, which meets k.o. criterion decision driver | which resolves force {force} | ... | comes out best (see below)}.

### Consequences

* Good, because {positive consequence, e.g., improvement of one or more desired qualities, ...}
* Bad, because {negative consequence, e.g., compromising one or more desired qualities, ...}
* Neutral, because {neutral consequence, neither positive nor negative}

### Confirmation

{Describe how the implementation of/compliance with the ADR is confirmed. E.g., by a review or an ArchUnit test. Although we classify this element as optional, it is recommended to include it.}

## Pros and Cons of the Options

### {title of option 1}

{example | description | pointer to more information | ...}

* Good, because {argument a}
* Good, because {argument b}
* Neutral, because {argument c}
* Bad, because {argument d}
* ...

### {title of option 2}

{example | description | pointer to more information | ...}

* Good, because {argument a}
* Good, because {argument b}
* Neutral, because {argument c}
* Bad, because {argument d}
* ...

### {title of option 3}

{example | description | pointer to more information | ...}

* Good, because {argument a}
* Good, because {argument b}
* Neutral, because {argument c}
* Bad, because {argument d}
* ...

## More Information

{You might want to provide additional evidence/confidence for the decision outcome here and/or document the team agreement on the decision and/or define when this decision should be re-considered and/or links to other decisions and resources.}
```

## Section Guide

### Status Values

| Status | Meaning |
|--------|---------|
| `draft` | Initial creation, not yet reviewed |
| `proposed` | Ready for team review |
| `accepted` | Approved and active |
| `rejected` | Considered but not adopted |
| `deprecated` | No longer recommended |
| `superseded by [ADR-NNNN]` | Replaced by newer decision |

### Title

- Use imperative mood ("Use X", "Adopt Y", "Migrate to Z")
- Keep concise (5-10 words)
- Start with verb

### Context and Problem Statement

- 2-4 sentences describing the situation
- Can be phrased as a question
- Include relevant constraints

### Decision Drivers

- List forces influencing the decision
- Prioritize by importance
- Include both technical and business drivers

### Considered Options

- Minimum 2 options (including chosen)
- Include "do nothing" if viable
- Brief titles, details in Pros/Cons section

### Decision Outcome

- State chosen option clearly
- Explain why it was chosen
- Reference decision drivers it satisfies

### Consequences

- Categorize as Good/Bad/Neutral
- Be honest about tradeoffs
- Include operational impacts

## Optional Sections

These sections enhance completeness but may be omitted for simpler decisions:

- **Confirmation** - How to verify compliance
- **Pros and Cons of the Options** - Detailed option analysis
- **More Information** - Links, references, caveats

## Minimal Template

For quick decisions, use this shortened form:

```markdown
---
status: draft
date: YYYY-MM-DD
---

# {Title}

## Context and Problem Statement

{description}

## Decision Drivers

* {driver 1}
* {driver 2}

## Decision Outcome

Chosen option: "{option}", because {reason}.

### Consequences

* Good, because {positive}
* Bad, because {negative}
```
