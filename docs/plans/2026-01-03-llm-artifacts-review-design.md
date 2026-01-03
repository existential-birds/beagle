# LLM Artifacts Review Commands Design

## Overview

Two commands to detect and fix common code artifacts left behind by LLM coding agents:

| Command | Purpose |
|---------|---------|
| `/beagle:review-llm-artifacts` | Detect issues using 4 parallel subagents |
| `/beagle:fix-llm-artifacts` | Apply fixes with safe/risky classification |

## Detection Categories

| Agent | Issues |
|-------|--------|
| **Tests** | DRY violations, library testing, wrong mock boundaries |
| **Dead Code** | Unused code/imports, TODOs, backwards compat cruft, orphaned tests |
| **Abstraction** | Over-abstraction, copy-paste drift, over-configuration |
| **Style** | Obvious comments, over-documentation, defensive overkill |

## Commands

### review-llm-artifacts

**Arguments:** `--all` (full codebase), `--parallel` (force parallel), path

**Flow:** Detect scope → detect languages → spawn 4 agents → consolidate → write JSON → display summary

### fix-llm-artifacts

**Arguments:** `--dry-run`, `--all`, `--category <name>`

**Flow:** Load JSON → check staleness → auto-fix safe issues → prompt for risky → run linters/tests → cleanup

**Fix classification:**
- **Safe** (auto-apply): unused imports, TODOs, dead code, verbose comments
- **Risky** (prompt): test refactors, abstraction changes, code removal

## Cross-Session State

Findings persist to `.beagle/llm-artifacts-review.json` with staleness detection via `git_head`.

## Files

```
commands/review-llm-artifacts.md
commands/fix-llm-artifacts.md
skills/llm-artifacts-detection/
├── SKILL.md
└── references/{tests,dead-code,abstraction,style}-criteria.md
```
