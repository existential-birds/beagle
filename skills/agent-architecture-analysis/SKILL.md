---
name: agent-architecture-analysis
description: "Use when auditing an agent codebase against the 12-Factor Agents methodology, reviewing LLM-powered system architecture, or assessing agentic app compliance. Triggers on \"analyze agent architecture\", \"12-factor audit\", \"how compliant is this agent\", or \"evaluate this LLM app\". Also applies when comparing frameworks or planning agent improvements. Not for quick checklists \u2014 this performs deep per-factor codebase analysis with file-level evidence."
---

# 12-Factor Agents Compliance Analysis

> Reference: [12-Factor Agents](https://github.com/humanlayer/12-factor-agents)

## Input Parameters

| Parameter | Description | Required |
|-----------|-------------|----------|
| `docs_path` | Path to documentation directory (for existing analyses) | Optional |
| `codebase_path` | Root path of the codebase to analyze | Required |

## Analysis Framework

The full per-factor rubric — principle, search patterns, file patterns, compliance criteria (Strong/Partial/Weak), and anti-patterns for each of the 13 factors — lives in [references/factors.md](references/factors.md). During the [Analysis Workflow](#analysis-workflow), read the relevant factor sections there for the search patterns to run and the criteria to score against.

| # | Factor | Focus |
|---|--------|-------|
| 1 | Natural Language to Tool Calls | Schema-validated structured outputs from LLM |
| 2 | Own Your Prompts | Prompts as first-class, versioned, templated code |
| 3 | Own Your Context Window | Custom formatting of history/state/tool results |
| 4 | Tools Are Structured Outputs | Validated JSON triggers deterministic code |
| 5 | Unify Execution State | Single state object merging execution + business state |
| 6 | Launch/Pause/Resume | APIs to launch, pause anywhere, resume |
| 7 | Contact Humans with Tools | Human contact as a structured tool call |
| 8 | Own Your Control Flow | Custom routing/retries, not framework defaults |
| 9 | Compact Errors into Context | Errors fed back for self-healing + escalation |
| 10 | Small, Focused Agents | Narrow responsibility, 3-10 steps each |
| 11 | Trigger from Anywhere | CLI/REST/WebSocket/chat/webhook entry points |
| 12 | Stateless Reducer | Pure `(state, input) -> (state, output)` agents |
| 13 | Pre-fetch Context | Fetch likely-needed data upfront |

See [references/factors.md](references/factors.md) for the complete rubric for every factor above.

---

## Output Format

**Gate order:** Do not assign Strong / Partial / Weak or treat recommendations as observed facts until **Hard gates** (after [Analysis Workflow](#analysis-workflow)) are satisfied for the factors in scope.

### Executive Summary Table

```markdown
| Factor | Status | Notes |
|--------|--------|-------|
| 1. Natural Language -> Tool Calls | **Strong/Partial/Weak** | [Key finding] |
| 2. Own Your Prompts | **Strong/Partial/Weak** | [Key finding] |
| ... | ... | ... |
| 13. Pre-fetch Context | **Strong/Partial/Weak** | [Key finding] |

**Overall**: X Strong, Y Partial, Z Weak
```

### Per-Factor Analysis

For each factor, provide:

1. **Current Implementation**
   - Evidence with file:line references
   - Code snippets showing patterns

2. **Compliance Level**
   - Strong/Partial/Weak with justification

3. **Gaps**
   - What's missing vs. 12-Factor ideal

4. **Recommendations**
   - Actionable improvements with code examples

---

## Analysis Workflow

1. **Initial Scan**
   - Run search patterns for all factors
   - Identify key files for each factor
   - Note any existing compliance documentation

2. **Deep Dive** (per factor)
   - Read identified files
   - Evaluate against compliance criteria
   - Document evidence with file paths

3. **Gap Analysis**
   - Compare current vs. 12-Factor ideal
   - Identify anti-patterns present
   - Prioritize by impact

4. **Recommendations**
   - Provide actionable improvements
   - Include before/after code examples
   - Reference roadmap if exists

5. **Summary**
   - Compile executive summary table
   - Highlight strengths and critical gaps
   - Suggest priority order for improvements

---

## Hard gates (evidence before scores)

Run these in order. Do not skip ahead: each **Pass** is an objective condition you can check (paths on disk, citations present), not internal certainty.

1. **Scan gate** — After the initial scan (workflow step 1), **Pass:** for every factor (1–13) you have either (a) ≥1 repo-relative path or glob hit to inspect, or (b) a one-line note with rationale (e.g. search command/output, or “no matches — codebase may omit this concern”). Empty hand-waving (“looks fine”) fails this gate.
2. **Evidence gate (per factor)** — Before writing Strong / Partial / Weak for that factor, **Pass:** “Current Implementation” includes ≥1 citation with **file path** plus **line range or short quoted snippet** from `codebase_path`, or an explicit **no evidence located** statement after targeted reads. If evidence is missing after search, default that factor to **Weak** unless the criterion is clearly N/A (say why).
3. **Synthesis gate** — Executive summary table and per-factor analysis sections, **Pass:** only after gates 1–2 are satisfied for the factors in scope. Recommendations may name new files or patterns only as proposals; they must not be presented as observed facts without matching citations from step 2.

---

## Quick Reference: Compliance Scoring

| Score | Meaning | Action |
|-------|---------|--------|
| **Strong** | Fully implements principle | Maintain, minor optimizations |
| **Partial** | Some implementation, significant gaps | Planned improvements |
| **Weak** | Minimal or no implementation | High priority for roadmap |

## When to Use This Skill

- Evaluating new LLM-powered systems
- Reviewing agent architecture decisions
- Auditing production agentic applications
- Planning improvements to existing agents
- Comparing frameworks or implementations
