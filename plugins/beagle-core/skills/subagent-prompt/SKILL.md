---
name: subagent-prompt
description: Produce a comprehensive prompt that hands off the current session's work to a fresh session for sub-agent-orchestrated execution. Use when the user wants to execute discussed/planned work in a new session, run a job to completion via sub-agents, or generate a portable handoff prompt with per-task verification and a bounded stop rule. Assumes the target session supports sub-agents. Reads plans from .beagle/concepts/<slug>/plan.md or .beagle/plans/<slug>/plan.md when one exists. Triggers on "subagent-prompt", "give me a prompt to run this in a new session", "hand this off to sub-agents", "execute this with sub-agents".
disable-model-invocation: false
user-invocable: true
---

# Sub-Agent Orchestration Prompt

Produce a single, self-contained prompt that the user can paste into a new agent session (one that supports sub-agents) to execute the work discussed in this conversation. The new session is the **orchestrator**: it dispatches a sub-agent per task and synthesizes results — it does not implement code itself.

This skill **owns the executor contract** in the generated prompt. Plan-writing skills defer the contract to this skill; they supply the tasks, this skill supplies the rules the executors run under.

## Goal

Hand off the current session's work to a fresh context window in a form that:

- Runs to completion without the user babysitting each step
- Uses one sub-agent per task so each task has its own context window
- Gives each sub-agent a **bounded** per-task check and a **legal way to stop**
- Leaves the orchestrator with enough material to confirm the whole job is functional at the end

## Gates

Complete in order. Do not advance until the **Pass when** condition holds.

1. **Source material identified** — **Pass when:** you can point to the concrete artifacts this prompt hands off. If a plan exists at `.beagle/concepts/<slug>/plan.md` or `.beagle/plans/<slug>/plan.md`, that is the spine. If the conversation has only vague intent, ask the user what the prompt should cover before drafting.
2. **Task decomposition explicit** — **Pass when:** you have a numbered task list (or can point to one on disk) where each task is small enough for one sub-agent to own end-to-end.
3. **Per-task check named** — **Pass when:** every task names **one** concrete command that proves that task's own behavior (see *Verification sizing* below). "Verify it works" is not a pass.
4. **Prompt drafted and self-contained** — **Pass when:** the draft would make sense to a fresh session with zero memory of this conversation: it names paths, tools, commands, and the success condition.

## Verification sizing — one rule, applied always

**A task's check is that task's own single test command. Nothing wider.**

`pytest tests/auth/test_session.py::test_expiry`, `cargo test --package osprey-core session::expiry`, `npx vitest run src/lib/token.test.ts` — one command, scoped to what the task changed. Never a project-wide typecheck plus full suite per task: that pays whole-repo cost per micro-task, and its failures are dominated by other tasks' in-flight state rather than by the task under test.

Project-wide typecheck, lint, and full suite run **once**, at the end, as the orchestrator's final integration check.

This rule does not vary by who executes the task. Do not write a branch that sizes verification differently for different executors — the unused branch rots.

## What the Generated Prompt Must Contain

Draft the handoff prompt as a single fenced block. It must include, in this order:

1. **Role line** — "You are the orchestrator. Dispatch one sub-agent per task. Do not implement code yourself."
2. **Context** — what the work is, where the source material lives (absolute plan/spec/repo paths), and any non-obvious constraints.
3. **Executor contract** — inline `beagle-core:execution-contract` verbatim into the generated prompt, or reference it by name if the target session loads beagle skills. It carries the two-attempt-per-step budget, the stop-and-report template, shape-not-string failure matching, the pre-existing-red policy, and the proceed-and-flag rule for ambiguity. Do not restate or re-derive those rules here — they have one home.
4. **Baseline capture** — instruct the orchestrator to run the project's suite **once before task 1** and record which tests are already red, so executors can apply the contract's pre-existing-red policy.
5. **Task list** — each task numbered, with: title, input artifacts (paths/sections), sub-agent type, and its single verification command per *Verification sizing*.
6. **Reporting contract** — each sub-agent reports back with: what it changed, the command it ran, and the last lines of that command's output. It reports **whether the check passed or not** — a `BLOCKED` report at the attempt budget is a complete, successful hand-back, not a failure to be retried into.
7. **Orchestrator loop with a declared budget** — "Dispatch tasks until each has reported either a passing check or a `BLOCKED` report. A `BLOCKED` task gets **at most one** follow-up sub-agent, briefed with the blocked report. If that follow-up also returns `BLOCKED`, record the task as blocked, continue with tasks that do not depend on it, and surface it to the user in the final summary. Never dispatch a third attempt at the same step."
8. **Final integration check** — the single command or short sequence the orchestrator runs once, after the task loop, to confirm the whole job is functional (project typecheck, full suite, lint, smoke run). Name it concretely. Judge it **against the recorded baseline**: new red blocks, pre-existing red does not.
9. **Partial-result exit** — "If tasks remain blocked after the final check, report: what landed and is verified, what is blocked with each `BLOCKED` block verbatim, and what the user must decide. Do not revert completed tasks because a later one stalled. Delivering a verified partial result with a clear blocker list is a **successful** outcome."

## Drafting Discipline

- **Absolute paths only.** A new session cannot resolve this session's relative paths.
- **Concrete commands only.** "Run the tests" is not a command. `cargo test --package osprey-core` is.
- **Name the sub-agent type** in the target harness's own terms. Don't leave the orchestrator guessing.
- **Pre-specify criteria where you can; where you cannot, say so in the prompt.** An underspecified task is handled by `execution-contract`'s proceed-and-flag rule: the executor takes the most reasonable reading, flags it as `AMBIGUITY: …`, and moves on. If a task is so underspecified that no reasonable reading exists, it needs a planning-tier decision — say that to the user before drafting rather than shipping a task no one can finish.
- **One source of truth.** If a plan file exists on disk, point the orchestrator at it rather than restating it. Restating drifts; the file is authoritative.

## Workflow

1. Identify the source material (gate 1). Check `.beagle/concepts/<slug>/plan.md` and `.beagle/plans/<slug>/plan.md`; either is a first-class spine. If neither exists, ask the user what to base the prompt on.
2. Confirm task decomposition (gate 2). Reuse the source's numbering if it has one.
3. For each task, name its single verification command (gate 3). Match the project's actual tooling — read `CLAUDE.md`/`AGENTS.md` and any `Makefile`/`package.json`/`Cargo.toml`. Separately identify the project-wide command for the final integration check.
4. Draft the prompt as a single fenced block (gate 4), covering every item in *What the Generated Prompt Must Contain*.
5. Deliver it. Default is to present it in chat. If the user wants it on disk — or the prompt is long enough that copying is awkward — offer to write it beside its source plan as `handoff-prompt.md` (e.g. `.beagle/plans/<slug>/handoff-prompt.md`), and give the user the absolute path.
6. Offer one refinement pass if the user spots a missing constraint, a wrong path, or a verification gap.

## When This Skill Is the Wrong Tool

- The work fits in one session and one context window — just do it.
- The work is exploratory and the user wants to stay in-loop — orchestration is overkill.
- No concrete artifacts exist yet — route the user to `beagle-analysis:brainstorm-beagle`, then `beagle-analysis:write-plan` (spec in hand) or `beagle-analysis:quick-plan` (no spec), to produce what this skill hands off.
