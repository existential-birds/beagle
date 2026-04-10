---
name: spec-brainstorm
description: "Turn ideas into comprehensive project specs through collaborative dialogue. Use BEFORE any planning or implementation — for new projects, features, or significant changes. Produces a system-agnostic spec document that can feed into any agentic workflow."
---

# Brainstorm: Ideas Into Specs

Turn a fuzzy idea into a comprehensive, implementation-free project spec through collaborative dialogue.

The output is a standalone spec document — structured enough for any agentic system to consume, clear enough for a human to act on. It captures WHAT and WHY, never HOW.

<hard_gate>
Do NOT write any code, create implementation plans, scaffold projects, or take any implementation action. This skill produces a SPEC DOCUMENT only. Every project goes through this process regardless of perceived simplicity — "simple" projects are where unexamined assumptions waste the most work.
</hard_gate>

## Workflow

Complete these steps in order:

1. **Explore context** — read project files, docs, git history, existing specs
2. **Assess scope** — is this one spec or does it need decomposition?
3. **Ask clarifying questions** — one at a time, follow the thread
4. **Propose 2-3 directions** — high-level product approaches with tradeoffs
5. **Draft spec** — write the structured spec document
6. **Self-review** — check for completeness, contradictions, implementation leakage (see `references/spec-reviewer.md`)
7. **User review** — present for approval, iterate if needed
8. **Write to disk** — save to `docs/specs/YYYY-MM-DD-<topic>.md`

```
Explore context → Assess scope ──→ Too large? → Decompose into sub-projects
                                                  → Brainstorm first sub-project
                                 → Right size? → Clarifying questions
                                                  → Propose directions
                                                  → Draft spec
                                                  → Self-review (fix inline)
                                                  → User review ──→ Changes? → Revise
                                                                  → Approved? → Write to disk
```

**The terminal state is a written spec.** This skill does not transition to implementation, planning, or any other skill. The user decides what to do with the spec.

## Questioning

You are a thinking partner, not an interviewer. The user has a fuzzy idea — your job is to help them sharpen it.

**How to question:**

- **Start open.** Let them dump their mental model. Don't interrupt with structure.
- **Follow energy.** Whatever they emphasized, dig into that. What excited them? What problem sparked this?
- **Challenge vagueness.** Never accept fuzzy answers. "Good" means what? "Users" means who? "Simple" means how?
- **Make the abstract concrete.** "Walk me through using this." "What does that actually look like?"
- **Clarify ambiguity.** "When you say Z, do you mean A or B?"
- **Know when to stop.** When you understand what, why, who, and what done looks like — offer to proceed.

**Question mechanics:**

- One question per message. If a topic needs more, break it into multiple messages.
- Prefer multiple choice when possible — easier to react to concrete options than open-ended prompts.
- When the user selects "other" or wants to explain freely, switch to plain text. Don't force them back into structured choices.
- 2-4 options is ideal. Never use generic categories ("Technical", "Business", "Other").

**What to ask about:**

| Ask about | Examples |
|-----------|----------|
| Motivation | "What prompted this?" "What are you doing today that this replaces?" |
| Concreteness | "Walk me through using this" "Give me an example" |
| Clarification | "When you say X, do you mean A or B?" |
| Success | "How will you know this is working?" "What does done look like?" |
| Boundaries | "What is this explicitly NOT?" |

**What NOT to ask about:**

- Technical implementation details (that's for planning)
- Architecture patterns (that's for planning)
- User's technical skill level (irrelevant — the system builds)
- Success metrics (inferred from the work)
- Canned questions regardless of context ("What's your core value?", "Who are your stakeholders?")

**Background checklist** (check mentally, not out loud):

- [ ] What they're building (concrete enough to explain to a stranger)
- [ ] Why it needs to exist (the problem or desire driving it)
- [ ] Who it's for (even if just themselves)
- [ ] What "done" looks like (observable outcomes)

When all four are clear, offer to proceed. If the user wants to keep exploring, keep going.

## Scope Assessment

Before diving into questions, assess whether the idea is one project or several.

**Signs it needs decomposition:**
- Multiple independent subsystems ("build a platform with chat, file storage, billing, and analytics")
- No clear ordering dependency between parts
- Would take multiple months of work

**When decomposition is needed:**
1. Help the user identify the independent pieces and their relationships
2. Establish what order they should be built
3. Brainstorm the first sub-project through the normal flow
4. Each sub-project gets its own spec

**For right-sized projects**, proceed directly to clarifying questions.

## Exploring Directions

After understanding the idea, propose 2-3 high-level directions. These are product directions, not technical architectures.

**Good directions:**
- "A CLI tool that operates on single files vs. a daemon that watches directories"
- "A focused MVP with just the core loop vs. a broader first version with supporting features"
- "Optimized for speed of use (power users) vs. optimized for discoverability (new users)"

**Bad directions (implementation leaking in):**
- "React with a REST API vs. HTMX with server-side rendering"
- "PostgreSQL vs. SQLite for storage"
- "Monorepo vs. polyrepo"

Lead with your recommendation and explain why. Present tradeoffs conversationally.

## Scope Discipline

Brainstorming naturally generates ideas beyond the current scope. Handle this gracefully:

**When the user expands scope mid-brainstorm:**
> "That's a great idea but it's its own project/phase. I'll capture it in Future Considerations so it's not lost. For now, let's focus on [current scope]."

**The heuristic:** Does this clarify what we're building, or does it add a new capability that could stand on its own?

Capture deferred ideas in the spec's "Future Considerations" section. Don't lose them, don't act on them.

## Implementation Leakage

The spec must never prescribe implementation. This is the hardest discipline.

| Allowed (WHAT) | Not allowed (HOW) |
|-----------------|-------------------|
| "Users can filter results by date and category" | "Add a /api/filter endpoint that accepts query params" |
| "Must support 10k concurrent users" | "Use Redis for session caching" |
| "Data must persist across sessions" | "Store in PostgreSQL with a users table" |
| "Must work offline" | "Use a service worker with IndexedDB" |
| "Search must feel instant" | "Use Elasticsearch with debounced queries" |

**Exception — constraints:** When the user has genuine constraints ("must use PostgreSQL because that's what our infra runs"), those go in the Constraints section with rationale. A constraint is a boundary condition, not a design choice made during brainstorming.

## Spec Format

Use the template in `references/spec-template.md`. The spec has these sections:

1. **Core Value** — ONE sentence, the most important thing
2. **Problem Statement** — what problem, who has it, why now
3. **Requirements** — must have, should have, out of scope (with reasons)
4. **Constraints** — hard limits with rationale
5. **Key Decisions** — decisions made during brainstorming with alternatives considered
6. **Reference Points** — "I want it like X" moments, external docs, inspiration
7. **Open Questions** — unresolved items needing future research
8. **Future Considerations** — ideas that emerged but belong in later phases

Requirements must be concrete and testable:

| Good requirement | Bad requirement |
|-----------------|-----------------|
| "User can undo the last 10 actions" | "Good undo support" |
| "Page loads in under 2 seconds on 3G" | "Fast performance" |
| "Works with screen readers" | "Accessible" |
| "Export to CSV and JSON" | "Multiple export formats" |

## Self-Review

After drafting the spec, review it for:

1. **Placeholders** — any TBD, TODO, vague requirements? Fix them.
2. **Contradictions** — do any sections conflict? Resolve them.
3. **Implementation leakage** — does any requirement prescribe HOW? Rewrite as WHAT.
4. **Untestable requirements** — could someone verify this was met? Make it concrete.
5. **Missing rationale** — do constraints and out-of-scope items explain WHY? Add reasons.
6. **Scope** — is this focused enough for a single planning cycle?

Fix issues inline. Then present to the user for review.

See `references/spec-reviewer.md` for the detailed review checklist.

## Writing the Spec

- Save to `docs/specs/YYYY-MM-DD-<topic>.md` (user preferences override this path)
- Commit to git with message: `docs: add <topic> project spec`
- After writing, tell the user:
  > "Spec written to `<path>`. Review it and let me know if you want changes."
- Wait for approval before considering the brainstorm complete.

## Key Principles

- **One question at a time** — don't overwhelm
- **Follow the thread** — don't walk a checklist
- **YAGNI ruthlessly** — remove anything that isn't clearly needed
- **Concrete decisions only** — "card-based layout" not "modern and clean"
- **No implementation** — WHAT and WHY, never HOW
- **Capture everything** — ideas outside scope go to Future Considerations, never lost
- **Incremental validation** — confirm understanding before moving on
- **The spec stands alone** — anyone should be able to read it and understand the project
