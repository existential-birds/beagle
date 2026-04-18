# Subagent Prompt Templates

Use these when dispatching research tasks to subagents. One task per subagent. Launch all subagents in a single turn so they run in parallel.

Every template ends with the same **return format** — a structured proposal the orchestrator can drop directly into the spec. Don't let subagents return free-form prose; decisions are the deliverable, not transcripts.

## Return format (shared across all templates)

Every subagent must return exactly this structure, ~300 words max:

```
## Recommended answer
<one-sentence answer, then a short paragraph on WHY>

## Alternatives considered
- <alternative 1> — rejected because <reason>
- <alternative 2> — rejected because <reason>

## Evidence
- <file:line citation, URL, or reference to an existing spec section>
- <additional citations as needed>

## Open sub-questions (if any)
- <anything the subagent couldn't resolve and needs the user or orchestrator to decide>
```

If the subagent cannot produce a recommendation with evidence, it should say so explicitly in "Open sub-questions" rather than guess.

---

## Template: Codebase pattern

Use when the question is about how the existing codebase works — an API, a pattern, a file layout, a convention that the spec references.

```
You are researching one question for an in-progress project spec.

Spec path: <absolute path>
Question: <the exact open question, verbatim>

Your job: read the relevant code and return a structured proposal answering the question. Use Grep, Glob, and Read. Do not modify any files.

Scope hints:
- <file/dir hints from the spec, if any>
- <reference points mentioned in the spec>

Return in this exact format:

## Recommended answer
<one-sentence answer, then a short paragraph on WHY — grounded in what you found>

## Alternatives considered
- <alt 1> — rejected because <reason, citing code>
- <alt 2> — rejected because <reason, citing code>

## Evidence
- <file:line> — <one-line description of what's there>
- <file:line> — <one-line description>

## Open sub-questions
- <anything that needs user input or is blocked>

Cap the return at ~300 words. Cite file paths and line numbers. Decisions, not transcripts.
```

## Template: External / API

Use when the question is about an external system — a framework's capabilities, an SDK's API, a tool's behavior.

```
You are researching one question for an in-progress project spec.

Spec path: <absolute path>
Question: <the exact open question, verbatim>

Your job: use WebSearch, WebFetch, and Context7 (if available) to find authoritative answers — official docs, source repositories, maintainer statements. Avoid blog posts and secondhand summaries.

Focus area: <framework / SDK / tool name>
Why it matters: <one-line context pulled from the spec's Problem Statement or Key Decisions>

Return in this exact format:

## Recommended answer
<one-sentence answer, then a short paragraph on WHY — grounded in what the official source says>

## Alternatives considered
- <alt 1> — rejected because <reason, citing source>
- <alt 2> — rejected because <reason, citing source>

## Evidence
- <URL> — <one-line description of what it says>
- <URL> — <one-line description>

## Open sub-questions
- <anything version-specific, ambiguous, or that needs user confirmation>

Cap the return at ~300 words. Prefer primary sources. Decisions, not transcripts.
```

## Template: Design tradeoff

Use when the question is a product/design judgment call with no single "right answer" in the codebase or external docs — format decisions, deduplication heuristics, UX structure.

```
You are researching one question for an in-progress project spec.

Spec path: <absolute path>
Question: <the exact open question, verbatim>

Your job: reason about the tradeoff and produce a concrete recommendation grounded in the spec's own Core Value, Problem Statement, and Key Decisions. Reference the spec heavily — the right answer usually already lives implicit in the rest of the document.

Do NOT propose implementation details. The answer goes into the spec as a WHAT/WHY decision, not a HOW.

Return in this exact format:

## Recommended answer
<one-sentence answer, then a short paragraph on WHY — explicitly citing which spec section supports the choice>

## Alternatives considered
- <alt 1> — rejected because <reason, ideally citing a spec section it would undermine>
- <alt 2> — rejected because <reason>

## Evidence
- Spec section "<section name>" — <what it says that informs this>
- <additional analogies or reference points if relevant>

## Open sub-questions
- <anything that needs the user's judgment (preferences, budgets, unstated constraints)>

Cap the return at ~300 words. Ground the call in the spec. Decisions, not transcripts.
```

## Template: Scope / policy

Use when the question is about inclusion/exclusion — what routes where, what's covered, what's explicitly out.

```
You are researching one question for an in-progress project spec.

Spec path: <absolute path>
Question: <the exact open question, verbatim>

Your job: recommend the scope/policy answer that best preserves the spec's Core Value and is consistent with its existing Out-of-Scope rationale. Read the spec end-to-end before deciding — scope answers regress fast if you only look at the local question.

Do NOT propose implementation details. The answer goes into the spec as a WHAT/WHY decision.

Return in this exact format:

## Recommended answer
<one-sentence answer, then a short paragraph on WHY — showing it aligns with Core Value and existing Out-of-Scope reasoning>

## Alternatives considered
- <alt 1> — rejected because <reason, ideally showing it conflicts with a stated constraint>
- <alt 2> — rejected because <reason>

## Evidence
- Spec section "Core Value" — <relevant phrase>
- Spec section "Out of Scope" — <relevant rationale>
- <other spec sections as needed>

## Open sub-questions
- <anything that needs user input on future intent>

Cap the return at ~300 words. Consistency with the spec matters more than novelty. Decisions, not transcripts.
```
