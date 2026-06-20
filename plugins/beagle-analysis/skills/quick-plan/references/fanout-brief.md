# Fanout Exploration + Expert Subagent Brief

quick-plan has no spec, so it reconstructs the spec's *Reference Points* and *Key Decisions* by fanning out subagents that are **both explorers and domain experts** for the codebase region they own. Each one answers: "what is here, how is it built, what should the plan mirror, and what's the right way to extend it?"

## When to fan out

- **Fan out** when the task spans more than one cohesive area, or touches code you have not already read this session. One subagent per area (a subsystem, a layer, a directory, an integration point). Two or three agents is typical.
- **Skip the fanout and explore inline** when the task is a one-file change or you have already read every file the plan will touch. The dispatch overhead isn't worth it for trivial scope.
- **Don't over-shard.** If two agents would read the same files or one agent would own the whole repo, you've scoped wrong. Each agent should own a region it can map without tripping over its neighbors.

## How to dispatch

If the environment supports subagents, send them in **one message, multiple tool calls**, so they run in parallel. Pass **paths, not file contents** — each agent has its own context window and reads the files itself. If the environment has no subagents, run the same briefs inline, one at a time; the questions and the structured output are identical, just slower.

Give each agent the relevant slice of the Intent Brief (the goal + the must-haves that touch its area) so its recommendation is anchored to what's actually being built — not generic advice.

## Dispatch template

Fill the brackets per agent. Keep the brief tight; the value is in the structured return.

```text
You are a senior engineer and domain expert in [AREA / STACK — e.g. "this repo's Go HTTP layer", "the SwiftData persistence code", "the React Flow canvas"].

We are planning this work (no spec exists; this is the reconstructed intent):
  Goal: [Intent Brief → Goal]
  The part that touches your area: [the must-haves / behaviors relevant to this region]

Explore these paths (read the real files — do not guess):
  [path/to/dir/, path/to/related_file.ext, ...]

Return a compact structured report with EXACTLY these sections:

## File map
- `path` — one-line responsibility. Only files the plan will plausibly touch or mirror.

## Conventions
- Test framework + the EXACT command to run one test and the area's suite (copy-pasteable).
- Naming, file-layout, and error-handling patterns the plan must follow.
- Any AGENTS.md/CLAUDE.md rule local to this area (test tiers, comment policy, forbidden patterns).

## Reference points
- `file.ext:line-line` — the closest existing analog to what we're building, and the one-sentence delta (what to mirror, what to change). 2-3 of these; they become the plan's behavior-contract references.

## Approach + risks
- The idiomatic way to extend this area for the goal above, in 2-4 bullets, grounded in the patterns you just read (NOT generic best practice).
- Pitfalls / failure modes specific to this stack or this code that the plan must defend against.
- Any claim of the form "tool/lib X does Y" or "input arrives in shape Z" that you could NOT verify from the files — flag it explicitly as a spike candidate.

Rules: cite real `file:line` you actually read; never invent paths or symbols. If something isn't in the code, say "not found" rather than guessing.

Write your report to [WORKSPACE/fanout-<area>.md]. Return ≤250 words: the report's headline findings and every Reference point and spike-candidate verbatim.
```

## Folding reports back into the plan

Each report feeds specific parts of the plan — this is the whole point of the fanout:

- **File map** → the plan's *File Structure* section.
- **Conventions** → the exact test/commit commands in each task's Step 2 and Step 4; the project rules the self-review checks.
- **Reference points** → the `file:line` **Reference** under each implementation step's behavior contract. These are the analogs the executor mirrors.
- **Approach + risks** → the Intent Brief's *Approach decisions* (the Key-Decisions equivalent that lands in the plan's `## Intent` block), and the *pitfalls* become named bug-class tests or spike candidates.
- **Spike candidates** → a `Task 0: Spike <claim>` per unverified load-bearing claim.

## Reconcile, don't rubber-stamp

Experts disagree, and codebases contradict their own conventions. When two reports conflict, or an agent's recommended approach fights an existing pattern in the code:

- If it changes the plan's shape → surface it to the user as a gap-check question.
- If you can resolve it from the code → record the decision in the plan's *Assumptions* block.

An expert recommendation that contradicts a load-bearing comment or pattern in the code is an **assumption-audit item**, not a given. The fanout informs the plan; it does not get to bypass the same scrutiny write-plan applies to a spec's characterization of the code.
