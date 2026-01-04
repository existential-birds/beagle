# LLM Judge Command Design

**Date:** 2025-01-04
**Status:** Approved
**Command:** `/beagle:llm-judge`

## Overview

Compare code implementations across 2+ repos using LLM-as-judge methodology. Produces per-dimension scores (1-5 scale) with configurable weights, then ranks implementations.

## Command Interface

```bash
# Spec is required first argument
/beagle:llm-judge ./spec.md /path/to/repo-a /path/to/repo-b

# With labels
/beagle:llm-judge ./spec.md --labels="Claude,GPT-4" /path/a /path/b

# With custom weights
/beagle:llm-judge ./spec.md --weights="functionality:40,security:30" /path/a /path/b /path/c
```

### Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `spec` | Yes | Path to spec/plan document (first positional arg) |
| `repos...` | Yes | 2+ paths to repos being compared |
| `--labels` | No | Comma-separated labels (default: directory names) |
| `--weights` | No | Override dimension weights |
| `--branch` | No | Branch to compare (default: current vs main) |

### Default Weights

| Dimension | Weight |
|-----------|--------|
| Functionality | 30% |
| Security | 25% |
| Test Quality | 20% |
| Overengineering | 15% |
| Dead Code | 10% |

## Execution Architecture

### Two-Phase Approach

```
┌─────────────────────────────────────────────────────────────┐
│                     PHASE 1: Fact Gathering                 │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │ Repo A Agent│  │ Repo B Agent│  │ Repo C Agent│  ...     │
│  │  (parallel) │  │  (parallel) │  │  (parallel) │          │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘          │
│         │                │                │                  │
│         ▼                ▼                ▼                  │
│     Facts A          Facts B          Facts C                │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                     PHASE 2: Judging                        │
├─────────────────────────────────────────────────────────────┤
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌───────────┐ │
│  │Functionality│ │  Security  │ │   Tests    │ │  Style    │ │
│  │   Judge    │ │   Judge    │ │   Judge    │ │  Judge    │ │
│  │ (parallel) │ │ (parallel) │ │ (parallel) │ │ (parallel)│ │
│  └─────┬──────┘ └─────┬──────┘ └─────┬──────┘ └─────┬─────┘ │
│        │              │              │              │        │
│        ▼              ▼              ▼              ▼        │
│   Scores A,B,C   Scores A,B,C   Scores A,B,C   Scores A,B,C  │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
                  ┌─────────────────┐
                  │ Aggregate &     │
                  │ Rank            │
                  └─────────────────┘
```

**Phase 1 agents** explore their assigned repo and extract structured facts (no scoring).
**Phase 2 judges** receive all facts and score each repo on their dimension, ensuring consistent scoring.

## Phase 1: Fact Gathering

Each Repo Agent receives the spec and its assigned repo path. It gathers facts without making judgments.

### Inputs to Each Repo Agent

- The spec document (full text)
- Repo path
- Branch to compare (default: current branch vs main)

### Fact Schema

```json
{
  "repo_label": "Claude",
  "repo_path": "/path/to/repo-a",
  "git_info": {
    "branch": "feature-x",
    "base": "main",
    "files_changed": 42,
    "additions": 1250,
    "deletions": 380
  },
  "functionality": {
    "spec_requirements": ["auth flow", "data export", "rate limiting"],
    "implemented": ["auth flow", "data export"],
    "missing": ["rate limiting"],
    "test_results": { "ran": true, "passed": 45, "failed": 2, "skipped": 1 }
  },
  "security": {
    "findings": [
      { "file": "src/api.py", "line": 42, "issue": "SQL string concatenation" }
    ],
    "patterns_observed": ["input validation present", "no secrets in code"]
  },
  "tests": {
    "coverage_estimate": "moderate",
    "dry_violations": [
      { "file": "tests/test_api.py", "description": "setup repeated in 5 functions" }
    ],
    "test_count": 48,
    "mocking_approach": "mocks at adapter boundary"
  },
  "overengineering": {
    "abstractions": [
      { "file": "src/factory.py", "issue": "Factory for single implementation" }
    ],
    "defensive_code": [],
    "config_complexity": "low"
  },
  "dead_code": {
    "unused_imports": ["src/utils.py:3"],
    "unused_functions": [],
    "todo_comments": 2,
    "commented_code_blocks": 1
  }
}
```

## Phase 2: Judging

Each Dimension Judge receives all facts from all repos and scores them on a 1-5 scale with justification.

### Scoring Rubric

| Score | Meaning |
|-------|---------|
| 5 | Excellent - Exceeds expectations |
| 4 | Good - Meets all requirements, minor issues |
| 3 | Average - Functional but notable gaps |
| 2 | Below Average - Significant issues |
| 1 | Poor - Fails to meet basic requirements |

### Judge Output Schema

```json
{
  "dimension": "functionality",
  "scores": {
    "Claude": {
      "score": 4,
      "justification": "Implements 2/3 requirements. Tests pass with 2 failures. Missing rate limiting.",
      "evidence": ["spec_requirements vs implemented", "test_results"]
    },
    "GPT-4": {
      "score": 5,
      "justification": "All 3 requirements implemented. All tests pass.",
      "evidence": ["spec_requirements vs implemented", "test_results"]
    }
  },
  "ranking": ["GPT-4", "Claude"]
}
```

### The 5 Judges

1. **Functionality Judge** - Compares spec requirements to implementation, weighs test results
2. **Security Judge** - Evaluates findings severity, checks for OWASP top 10
3. **Tests Judge** - Assesses DRY adherence, coverage adequacy, mock boundaries
4. **Overengineering Judge** - Flags unnecessary abstractions, defensive overkill
5. **Dead Code Judge** - Counts and weighs unused code, TODOs, commented blocks

### Functionality Verification

Hybrid approach:
- Run tests if they exist (`npm test`, `pytest`, `go test`, etc.)
- Fall back to static analysis if no tests

## Output Format

### JSON Report

Location: `.beagle/llm-judge-report.json`

```json
{
  "version": "1.0.0",
  "created_at": "2025-01-04T14:30:00Z",
  "spec_file": "./spec.md",
  "repos": [
    { "label": "Claude", "path": "/path/a", "branch": "main", "git_head": "abc123" },
    { "label": "GPT-4", "path": "/path/b", "branch": "main", "git_head": "def456" }
  ],
  "weights": {
    "functionality": 30,
    "security": 25,
    "tests": 20,
    "overengineering": 15,
    "dead_code": 10
  },
  "scores": {
    "Claude": {
      "functionality": { "score": 4, "justification": "..." },
      "security": { "score": 3, "justification": "..." },
      "tests": { "score": 4, "justification": "..." },
      "overengineering": { "score": 5, "justification": "..." },
      "dead_code": { "score": 4, "justification": "..." },
      "weighted_total": 3.95
    },
    "GPT-4": {
      "functionality": { "score": 5, "justification": "..." },
      "security": { "score": 4, "justification": "..." },
      "tests": { "score": 3, "justification": "..." },
      "overengineering": { "score": 3, "justification": "..." },
      "dead_code": { "score": 4, "justification": "..." },
      "weighted_total": 3.90
    }
  },
  "ranking": ["Claude", "GPT-4"],
  "verdict": "Claude edges out GPT-4 despite lower functionality score due to better security and less overengineering."
}
```

### Markdown Summary

Displayed after execution:

```markdown
## LLM Judge Results

**Spec:** ./spec.md
**Repos compared:** Claude, GPT-4

### Scores

| Dimension | Weight | Claude | GPT-4 |
|-----------|--------|--------|-------|
| Functionality | 30% | 4 | 5 |
| Security | 25% | 3 | 4 |
| Tests | 20% | 4 | 3 |
| Overengineering | 15% | 5 | 3 |
| Dead Code | 10% | 4 | 4 |
| **Weighted Total** | | **3.95** | **3.90** |

### Ranking

1. **Claude** (3.95)
2. GPT-4 (3.90)

### Verdict

Claude edges out GPT-4 despite lower functionality score due to better security and less overengineering.

### Detailed Justifications
[Expandable sections per dimension...]
```

## File Structure

```
beagle/
├── commands/
│   └── llm-judge.md              # The command (user-invoked)
├── skills/
│   └── llm-judge/
│       ├── SKILL.md              # Core skill (auto-loaded by command)
│       └── references/
│           ├── repo-agent.md     # Phase 1 agent instructions
│           ├── fact-schema.md    # JSON schema for facts
│           ├── judge-agents.md   # Phase 2 judge instructions
│           └── scoring-rubrics.md # Detailed rubrics per dimension
```

## Command Responsibilities

1. Parse arguments (spec, paths, labels, weights)
2. Validate inputs (spec exists, repos exist, have git)
3. Load the `llm-judge` skill
4. Orchestrate Phase 1 (spawn N repo agents in parallel)
5. Orchestrate Phase 2 (spawn 5 judge agents in parallel)
6. Aggregate scores, compute weighted totals, rank
7. Write JSON report to `.beagle/llm-judge-report.json`
8. Display markdown summary

## Dependencies

- `llm-artifacts-detection` skill - Reused by repo agents for dead code/overengineering facts
- Potentially `receive-feedback` patterns for structured output

## Future Enhancements (Not MVP)

- Full repo comparison (not just diff)
- `--watch` mode for re-running as you iterate
- CI integration (exit code based on winner)
- Benchmark repo registry
