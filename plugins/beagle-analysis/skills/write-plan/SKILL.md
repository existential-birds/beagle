---
name: write-plan
description: "Use when you have a finalized brainstorm-beagle spec at `.beagle/concepts/<slug>/spec.md` and need a bite-sized, TDD-driven implementation plan before any code is written. Triggers on: \"write a plan\", \"plan this spec\", \"turn the spec into a plan\", \"now plan the implementation\", \"write-plan\". Reads the spec, designs the file structure, decomposes work into 2-5 minute TDD steps with exact paths and commands, reviews the draft in one pass, gets user approval, then writes to `.beagle/concepts/<slug>/plan.md` and offers to generate an execution handoff prompt via the subagent-prompt skill. Does NOT brainstorm specs, write code, or execute the plan — produces the plan document (and an optional handoff prompt) only."
---

# Write Plan: Spec Into Implementation Plan

Turn a [brainstorm-beagle](../brainstorm-beagle/SKILL.md) spec into an implementation plan that an engineer — or a downstream agent that will not re-derive your reasoning — can execute task by task.

The output is a single markdown plan at `.beagle/concepts/<slug>/plan.md`, sitting beside the spec in the same concept folder. The plan captures HOW — file structure, task decomposition, exact tests, exact commands — while the spec already owns WHAT and WHY.

<hard_gate>
Do NOT start writing the plan until a brainstorm-beagle spec exists at `.beagle/concepts/<slug>/spec.md`. If one is missing, stop and route the user to [brainstorm-beagle](../brainstorm-beagle/SKILL.md) first. Skipping the spec produces plans that bake in unexamined assumptions — the spec is the contract this skill plans against.
</hard_gate>

## Workflow

1. **Locate the spec** — find `.beagle/concepts/<slug>/spec.md`; if absent, stop and route to [brainstorm-beagle](../brainstorm-beagle/SKILL.md)
2. **Read the spec** — ingest every section; do not paraphrase, do not summarize away requirements
3. **Read project conventions** — scan `AGENTS.md`/`CLAUDE.md` (root and nested) for testing tiers, comment policy, commit format, forbidden patterns
4. **Explore relevant code** — read the files the plan will touch or pattern-match against; do not guess at structure
5. **Design file structure** — map what gets created or modified before writing any task
6. **Decompose into tasks** — bite-sized TDD steps with exact paths, tests, and commands, per `references/planning-disciplines.md`
7. **Audit assumptions** — surface what the spec did not pin (see *Assumption Audit*)
8. **Review the draft — one pass** — inline or via a reviewer subagent, against `references/plan-reviewer.md`
9. **Present draft to user** — show it in chat; iterate on request
10. **Write to disk** — save to `.beagle/concepts/<slug>/plan.md` only after explicit approval

```text
Spec at .beagle/concepts/<slug>/spec.md? ── No  → STOP, route to brainstorm-beagle
                                          ── Yes → Read spec + conventions + relevant code
                                                   ↓
                                                   Design file structure
                                                   ↓
                                                   Decompose into TDD tasks
                                                   ↓
                                                   One review pass → fix inline
                                                   ↓
                                                   Present draft → User review
                                                                  ├─ Changes? → Revise
                                                                  └─ Approved? → Write plan.md
```

**The terminal state is a written plan.** This skill does not execute the plan, run tests, or modify production code.

## Locating the Spec

The default input path is `.beagle/concepts/<slug>/spec.md`.

**Slug resolution priorities (in order):**
1. User-supplied path or slug (`write-plan auth-rewrite`, "plan the spec at `.beagle/concepts/foo/spec.md`")
2. Recently-edited spec under `.beagle/concepts/`
3. Ask the user to disambiguate when multiple specs are plausible

**If no spec exists:**
> "I can't find a brainstorm-beagle spec at `.beagle/concepts/<slug>/spec.md`. Run [brainstorm-beagle](../brainstorm-beagle/SKILL.md) first to produce the spec, then come back to plan it."

Do not proceed. The spec is the contract; planning without one re-invents it under a different name and skips the review gates `brainstorm-beagle` enforces.

## Scope Check

If the spec covers multiple independent subsystems, it should have been decomposed during brainstorming. Signs it is too broad for one plan:

- More than ~15 must-have requirements with no shared core loop
- Requirements spanning independent subsystems (auth, billing, analytics — each is its own plan)
- The core loop can't be explained in 30 seconds

**Action:** "This spec covers more than one cohesive system. I'd suggest splitting it during brainstorm-beagle and planning each sub-spec independently. Want to do that, or proceed with one big plan?"

## Reading Project Conventions

Before designing tasks, scan for the rules that shape the plan:

- **`AGENTS.md` / `CLAUDE.md` at repo root and in any subdirectory you'll touch** — testing tiers, commenting policy, commit conventions, forbidden patterns
- **Test framework and runner** — Cargo, pytest, npm test, mix test. Tasks must use the correct command, and the plan header must name the baseline suite command.
- **Existing patterns** — follow the codebase's file layout. The spec's *Constraints* and *Reference Points* often pin these.

When project conventions mandate something specific ("every user-visible feature needs a tier-3 test driven through the compiled binary"), the plan must include tasks that satisfy it. Do not silently produce a plan that violates project policy — call it out and adapt.

## File Structure

Map which files will be created or modified, and what each is responsible for, before defining tasks. This is where decomposition gets locked in.

- Design units with clear boundaries. Each file has one clear responsibility.
- Prefer smaller, focused files — you reason better about code you can hold in context at once, and so will the executor.
- Files that change together live together. Split by responsibility, not by technical layer.
- In existing codebases, follow established patterns. Do not unilaterally restructure — but if a file you're modifying has grown unwieldy, including a split is reasonable.

This section appears in the plan itself, so the executor sees the shape of the work before reading individual tasks.

## Bite-Sized Task Granularity

**Each step is one action (2-5 minutes):** write the failing test → run it and watch it fail → implement against it → run the test and the suite → sweep → commit.

Steps that bundle actions ("write the test and the implementation") are too coarse — split them. Steps that describe behavior abstractly ("add validation") are too vague — pin the contract.

## Plan Document Format

**`references/plan-template.md` is the sole source of truth for the emitted plan's shape.** Read it before drafting. It defines the header, the mandatory inlined **Executor Contract**, the baseline suite command, the Assumptions and Patterns sections, the six-step task block, and the Review Outcome.

Do not reproduce the template here or improvise a variant. `quick-plan` writes the same format from the same file.

## Drafting Disciplines

**Read `references/planning-disciplines.md` before writing task bodies.** It carries the rules that govern what goes inside a task:

Code in steps (tests real, impls as skeletons) · the recoverability test · test authoring · behavior contracts · failure propagation · cleanup sweeps · patterns and the application audit · spike before plan-lock · the parallel-implementation gate.

Two of those change the *shape* of the plan and are non-optional when they apply: a `Task 0: Spike <claim>` for every unverified load-bearing claim about tool or input behavior, and a final contract-equivalence task whenever the plan adds a second implementation behind an existing interface.

## No Placeholders

Every step must contain the actual content an executor needs. These are **plan failures**:

- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" / "add validation" / "handle edge cases" — without naming WHICH errors, rules, or cases
- "Write tests for the above" — without the actual assertion
- "Similar to Task N" with nothing further — use a `Patterns` reference instead
- Test steps without exact assertions, command steps without exact commands, commit steps without exact messages
- References to types or functions not defined in any task and not already in the codebase

A behavior contract under an implementation step is **not** a placeholder — it is the deliberate contract the executor implements against. The forbidden pattern is vague language *without* a contract.

## Assumption Audit

Plans bake in assumptions the spec does not always pin — data shapes, naming, library choices, error semantics, persistence boundaries. List yours and check each against the spec.

**Re-read the files the spec names.** A spec may characterize a file in a way that is outdated or partial; the file's own doc comment or surrounding code may encode a constraint the spec missed. Spec authors work from memory; the code is ground truth. A contradiction between the two is an assumption-audit item, not a reason to trust the spec.

If an assumption is not anchored by the spec and could plausibly be made differently, surface it during *Draft Review*. The user confirms or corrects. Do not silently choose. Capture confirmed assumptions in the plan's `## Assumptions` block.

## Review the Draft — One Pass

After the complete draft exists, run **one** review pass against `references/plan-reviewer.md`, which carries every review criterion — format integrity, coverage and scope, test quality, implementation contracts, gates and loops.

**If the agent supports subagents**, dispatch a reviewer with that brief for long (>10 tasks), unfamiliar, or high-stakes plans. **Otherwise**, or for short plans over familiar code, run the same pass inline. Identical criteria either way.

Fix blocking findings inline and move on. Do not re-run the pass to confirm your own fixes landed — a second dispatch is justified only when the fixes restructured the plan. Record the outcome in the plan's `## Review Outcome` section, including anything left open.

Don't dispatch ritualistically; the human review that follows catches most of what a second machine pass would.

## Draft Review

Before writing to disk, present the draft in chat. Show:

- The full plan markdown, end to end, as concrete prose — not a summary, not "here's a description of the plan"
- The assumptions you made
- The list of files the plan will create or modify
- A pointer to the source spec

If the user requests changes, revise inline and present again. Do not write to disk during this loop.

## Writing the Plan

**Do not write until both are true:**

1. **User gate:** the user explicitly approved the draft or directed you to save it. Vague enthusiasm is not approval — confirm if unclear.
2. **Path gate:** the target path is finalized.

- **Default path:** `.beagle/concepts/<slug>/plan.md`
- **Slug source:** inherit from the spec's parent folder (the `<slug>` segment under `.beagle/concepts/`). User preferences override the default path.
- If the user explicitly asks to commit, use: `docs: add <slug> implementation plan`
- After writing, tell the user:
  > "Plan written to `<path>`. Review it on disk and let me know if you want changes."
- Then ask exactly: **"Do you want a prompt to execute this plan in a new session?"**
- Wait for the next instruction before considering work complete.

## Execution Handoff

The plan is a handoff document, not an instruction to execute.

- **On yes:** load the **subagent-prompt** skill (`beagle-core:subagent-prompt`) to produce the orchestration prompt in this session, naming the just-written `plan.md` as the source material so its source-material and task-decomposition gates resolve from the plan without re-interrogating the user. subagent-prompt owns the prompt's contract — do not restate it here.
- **On no, or if `beagle-core` is unavailable:** tell the user the plan is ready and that they can hand it off later by invoking **subagent-prompt** themselves in a fresh session, or via any other downstream executor skill the project provides.

**Do not start executing.** This skill produces the plan (and optionally the handoff prompt); execution is a separate decision and usually a separate skill.

## When This Skill Is Wrong For the Job

This skill assumes a spec exists ([brainstorm-beagle](../brainstorm-beagle/SKILL.md) if not), the work is scoped to one cohesive system, and a TDD-aware executor is downstream.

If the work is a one-line fix, a refactor inside one file, or experimental spike work, a full plan is overkill — say so and suggest doing the work directly. If there is no spec but the conversation already pins the intent, [quick-plan](../quick-plan/SKILL.md) produces the same plan format without one.
