# LLM Judge Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a command that compares 2+ code implementations using LLM-as-judge methodology with weighted scoring across 5 dimensions.

**Architecture:** Two-phase execution: Phase 1 spawns parallel repo agents to gather facts, Phase 2 spawns parallel judge agents to score each dimension. Results aggregated into weighted ranking with JSON report and markdown summary.

**Tech Stack:** Claude Code plugin (markdown commands/skills), Task tool for subagents, Bash for git/test commands.

---

## Task 1: Create Fact Schema Reference

**Files:**
- Create: `skills/llm-judge/references/fact-schema.md`

**Step 1: Create the skill directory structure**

Run: `mkdir -p skills/llm-judge/references`

**Step 2: Write the fact schema reference file**

```markdown
# Fact Schema

JSON schema for structured facts gathered by Phase 1 Repo Agents.

## Full Schema

```json
{
  "repo_label": "string - Display name for this repo",
  "repo_path": "string - Absolute path to repo",
  "git_info": {
    "branch": "string - Current branch name",
    "base": "string - Base branch (usually main)",
    "files_changed": "number - Count of changed files",
    "additions": "number - Lines added",
    "deletions": "number - Lines deleted",
    "diff_summary": "string - Brief description of changes"
  },
  "functionality": {
    "spec_requirements": ["array of requirement strings extracted from spec"],
    "implemented": ["array of requirements found implemented"],
    "missing": ["array of requirements not found"],
    "partially_implemented": ["array of requirements with incomplete implementation"],
    "test_results": {
      "ran": "boolean - Whether tests were executed",
      "framework": "string - pytest, jest, go test, etc.",
      "passed": "number",
      "failed": "number",
      "skipped": "number",
      "error_summary": "string - Brief description of failures if any"
    }
  },
  "security": {
    "findings": [
      {
        "file": "string - File path",
        "line": "number - Line number",
        "issue": "string - Description of security issue",
        "severity": "high | medium | low",
        "category": "string - OWASP category if applicable"
      }
    ],
    "patterns_observed": ["array of positive security patterns found"]
  },
  "tests": {
    "test_count": "number - Total test count",
    "coverage_estimate": "none | low | moderate | high",
    "dry_violations": [
      {
        "file": "string",
        "line": "number",
        "description": "string"
      }
    ],
    "mocking_approach": "string - Description of mocking strategy",
    "test_quality_notes": "string - General observations"
  },
  "overengineering": {
    "abstractions": [
      {
        "file": "string",
        "line": "number",
        "issue": "string - Description of over-abstraction"
      }
    ],
    "defensive_code": [
      {
        "file": "string",
        "line": "number",
        "issue": "string"
      }
    ],
    "config_complexity": "low | medium | high"
  },
  "dead_code": {
    "unused_imports": ["array of file:line references"],
    "unused_functions": ["array of file:line references"],
    "unused_variables": ["array of file:line references"],
    "todo_comments": "number - Count of TODO/FIXME",
    "commented_code_blocks": "number - Count of commented code"
  }
}
```

## Example

```json
{
  "repo_label": "Claude",
  "repo_path": "/path/to/repo-a",
  "git_info": {
    "branch": "main",
    "base": "main",
    "files_changed": 42,
    "additions": 1250,
    "deletions": 380,
    "diff_summary": "Adds auth flow and data export features"
  },
  "functionality": {
    "spec_requirements": ["auth flow", "data export", "rate limiting"],
    "implemented": ["auth flow", "data export"],
    "missing": ["rate limiting"],
    "partially_implemented": [],
    "test_results": {
      "ran": true,
      "framework": "pytest",
      "passed": 45,
      "failed": 2,
      "skipped": 1,
      "error_summary": "2 tests fail on edge case validation"
    }
  },
  "security": {
    "findings": [
      {
        "file": "src/api.py",
        "line": 42,
        "issue": "SQL string concatenation instead of parameterized query",
        "severity": "high",
        "category": "Injection"
      }
    ],
    "patterns_observed": ["input validation present", "no secrets in code", "HTTPS enforced"]
  },
  "tests": {
    "test_count": 48,
    "coverage_estimate": "moderate",
    "dry_violations": [
      {
        "file": "tests/test_api.py",
        "line": 15,
        "description": "Setup code repeated in 5 test functions"
      }
    ],
    "mocking_approach": "Mocks at adapter boundary, uses pytest fixtures",
    "test_quality_notes": "Good isolation, some DRY issues"
  },
  "overengineering": {
    "abstractions": [
      {
        "file": "src/factory.py",
        "line": 1,
        "issue": "Factory pattern for single implementation"
      }
    ],
    "defensive_code": [],
    "config_complexity": "low"
  },
  "dead_code": {
    "unused_imports": ["src/utils.py:3"],
    "unused_functions": [],
    "unused_variables": [],
    "todo_comments": 2,
    "commented_code_blocks": 1
  }
}
```
```

**Step 3: Commit**

Run: `git add skills/llm-judge/references/fact-schema.md && git commit --no-verify --no-gpg-sign -m "feat(llm-judge): add fact schema reference"`

---

## Task 2: Create Scoring Rubrics Reference

**Files:**
- Create: `skills/llm-judge/references/scoring-rubrics.md`

**Step 1: Write the scoring rubrics reference file**

```markdown
# Scoring Rubrics

Detailed rubrics for each of the 5 judging dimensions. Judges use these to assign consistent 1-5 scores.

## General Scoring Scale

| Score | Meaning | General Criteria |
|-------|---------|------------------|
| 5 | Excellent | Exceeds expectations, best practices throughout |
| 4 | Good | Meets all requirements, minor issues only |
| 3 | Average | Functional but notable gaps or issues |
| 2 | Below Average | Significant issues affecting quality |
| 1 | Poor | Fails to meet basic requirements |

---

## Functionality (30% weight)

Evaluates whether the implementation meets the spec requirements and works correctly.

| Score | Criteria |
|-------|----------|
| 5 | All spec requirements implemented. All tests pass. No obvious bugs. |
| 4 | All requirements implemented. Tests pass with minor failures (< 5%). Edge cases may be missing. |
| 3 | Most requirements implemented (> 75%). Some test failures. Core functionality works. |
| 2 | Partial implementation (50-75%). Significant test failures. Core features have bugs. |
| 1 | Minimal implementation (< 50%). Tests fail or don't exist. Core functionality broken. |

**Key Evidence:**
- `functionality.implemented` vs `functionality.spec_requirements`
- `functionality.test_results.passed` vs `functionality.test_results.failed`
- `functionality.missing` and `functionality.partially_implemented`

---

## Security (25% weight)

Evaluates security posture and absence of vulnerabilities.

| Score | Criteria |
|-------|----------|
| 5 | No security findings. Positive security patterns present. OWASP Top 10 addressed. |
| 4 | No high-severity findings. 1-2 low/medium issues. Good security hygiene. |
| 3 | 1-2 medium-severity issues OR 3+ low-severity. Basic security present. |
| 2 | 1+ high-severity issue OR 3+ medium. Security gaps evident. |
| 1 | Multiple high-severity issues. Critical vulnerabilities. No security consideration. |

**Severity Weights:**
- High: SQL injection, command injection, auth bypass, secrets in code
- Medium: XSS, CSRF, insecure deserialization, missing input validation
- Low: Information disclosure, verbose errors, missing security headers

**Key Evidence:**
- `security.findings` (count and severity)
- `security.patterns_observed`

---

## Test Quality (20% weight)

Evaluates test coverage, DRY adherence, and testing practices.

| Score | Criteria |
|-------|----------|
| 5 | High coverage. No DRY violations. Good mock boundaries. Tests are maintainable. |
| 4 | Moderate-high coverage. Minor DRY issues (1-2). Good testing practices. |
| 3 | Moderate coverage. Some DRY violations (3-5). Acceptable mocking. |
| 2 | Low coverage. Significant DRY violations. Poor mock boundaries. |
| 1 | Minimal/no tests. Severe DRY problems. Tests don't follow best practices. |

**Key Evidence:**
- `tests.coverage_estimate`
- `tests.dry_violations` (count)
- `tests.mocking_approach`
- `tests.test_count` relative to codebase size

---

## Overengineering (15% weight)

Evaluates simplicity and absence of unnecessary complexity.

| Score | Criteria |
|-------|----------|
| 5 | Clean, simple code. No unnecessary abstractions. YAGNI followed. |
| 4 | Mostly simple. 1-2 minor over-abstractions. Code is readable. |
| 3 | Some complexity. 3-5 abstraction issues. Config complexity medium. |
| 2 | Significant over-engineering. 6+ abstraction issues. Unnecessary patterns. |
| 1 | Severely over-engineered. Abstractions everywhere. Simple tasks made complex. |

**Key Evidence:**
- `overengineering.abstractions` (count)
- `overengineering.defensive_code` (count)
- `overengineering.config_complexity`

---

## Dead Code (10% weight)

Evaluates cleanliness and absence of unused/obsolete code.

| Score | Criteria |
|-------|----------|
| 5 | No dead code. No TODOs. Clean codebase. |
| 4 | 1-3 minor issues (unused imports). No significant dead code. |
| 3 | 4-6 issues. Some unused functions or TODOs. |
| 2 | 7-10 issues. Unused functions/classes. Multiple TODOs. |
| 1 | 10+ issues. Significant dead code. Many TODOs/commented blocks. |

**Key Evidence:**
- `dead_code.unused_imports` (count)
- `dead_code.unused_functions` (count)
- `dead_code.todo_comments`
- `dead_code.commented_code_blocks`
```

**Step 2: Commit**

Run: `git add skills/llm-judge/references/scoring-rubrics.md && git commit --no-verify --no-gpg-sign -m "feat(llm-judge): add scoring rubrics reference"`

---

## Task 3: Create Repo Agent Reference

**Files:**
- Create: `skills/llm-judge/references/repo-agent.md`

**Step 1: Write the repo agent reference file**

```markdown
# Repo Agent Instructions

Instructions for Phase 1 agents that gather facts from a single repository.

## Role

You are a fact-gathering agent. Your job is to explore a repository and extract structured facts WITHOUT making judgments or assigning scores. Scoring happens in Phase 2 by separate judge agents.

## Inputs You Receive

1. **Spec Document**: The requirements/plan that was given to the LLM to implement
2. **Repo Path**: Absolute path to the repository you're analyzing
3. **Repo Label**: Display name for this repo (e.g., "Claude", "GPT-4")
4. **Branch Info**: Which branch to compare (default: current vs main)

## Your Task

Produce a JSON object following the schema in [fact-schema.md](fact-schema.md).

## Step-by-Step Process

### 1. Gather Git Info

```bash
# Get branch name
git -C $REPO_PATH rev-parse --abbrev-ref HEAD

# Get diff stats
git -C $REPO_PATH diff --stat main...HEAD

# Count files changed
git -C $REPO_PATH diff --name-only main...HEAD | wc -l
```

### 2. Analyze Functionality

1. Read the spec document carefully
2. Extract discrete requirements as a list
3. Explore the codebase to determine which requirements are implemented
4. Run tests if available:

```bash
# Detect and run tests
cd $REPO_PATH

# Python
if [ -f pytest.ini ] || [ -f pyproject.toml ] || [ -d tests ]; then
  pytest --tb=short 2>&1
fi

# JavaScript/TypeScript
if [ -f package.json ]; then
  npm test 2>&1 || yarn test 2>&1
fi

# Go
if [ -f go.mod ]; then
  go test ./... 2>&1
fi
```

### 3. Analyze Security

Look for common vulnerabilities:
- SQL injection (string concatenation in queries)
- Command injection (unsanitized shell commands)
- XSS (unsanitized user input in HTML)
- Hardcoded secrets (API keys, passwords)
- Missing input validation
- Insecure deserialization

Also note positive patterns:
- Input validation present
- Parameterized queries
- Authentication checks
- Rate limiting

### 4. Analyze Tests

- Count test files and test functions
- Look for DRY violations (repeated setup code)
- Assess mocking strategy
- Estimate coverage (file count ratio, critical paths tested)

### 5. Analyze Overengineering

Use patterns from `@beagle:llm-artifacts-detection`:
- Unnecessary abstractions (interfaces with single impl)
- Factory patterns for simple objects
- Excessive defensive coding
- Over-configuration

### 6. Analyze Dead Code

- Unused imports (grep for imports, check usage)
- TODO/FIXME comments
- Commented-out code blocks
- Unused functions/variables

## Output Format

Return ONLY the JSON object. No markdown, no explanations. The JSON must be valid and follow [fact-schema.md](fact-schema.md).

## Important Rules

1. **Do not score** - Only gather facts
2. **Be thorough** - Check all changed files
3. **Be specific** - Include file:line references
4. **Be objective** - Report what you find, not opinions
5. **Use the skill** - Load `@beagle:llm-artifacts-detection` for dead code/overengineering
```

**Step 2: Commit**

Run: `git add skills/llm-judge/references/repo-agent.md && git commit --no-verify --no-gpg-sign -m "feat(llm-judge): add repo agent reference"`

---

## Task 4: Create Judge Agents Reference

**Files:**
- Create: `skills/llm-judge/references/judge-agents.md`

**Step 1: Write the judge agents reference file**

```markdown
# Judge Agent Instructions

Instructions for Phase 2 agents that score implementations on a single dimension.

## Role

You are a scoring judge. You receive facts gathered from ALL repositories and score each one on YOUR specific dimension using the rubrics in [scoring-rubrics.md](scoring-rubrics.md).

## Inputs You Receive

1. **Spec Document**: The original requirements
2. **Facts Array**: JSON facts from all repos (output of Phase 1)
3. **Your Dimension**: One of: functionality, security, tests, overengineering, dead_code

## Your Task

Produce a JSON object with scores and justifications for each repo.

## Output Schema

```json
{
  "dimension": "functionality",
  "scores": {
    "RepoLabel1": {
      "score": 4,
      "justification": "Clear explanation of why this score was assigned",
      "evidence": ["Specific facts that support this score"]
    },
    "RepoLabel2": {
      "score": 5,
      "justification": "...",
      "evidence": ["..."]
    }
  },
  "ranking": ["RepoLabel2", "RepoLabel1"],
  "notes": "Optional comparative notes"
}
```

## Scoring Process

1. Read the rubric for your dimension from [scoring-rubrics.md](scoring-rubrics.md)
2. For each repo's facts:
   - Extract the relevant section (e.g., `facts.functionality` for functionality judge)
   - Apply the rubric criteria
   - Assign a 1-5 score
   - Write a clear justification citing specific evidence
3. Rank the repos by score (highest first)

## Dimension-Specific Instructions

### Functionality Judge

Focus on `facts.functionality`:
- Compare `spec_requirements` to `implemented` and `missing`
- Weight test results heavily (`test_results.passed` vs `failed`)
- Consider `partially_implemented` as half credit

### Security Judge

Focus on `facts.security`:
- Count and weight `findings` by severity
- High severity = major deduction
- Positive `patterns_observed` can offset minor issues

### Tests Judge

Focus on `facts.tests`:
- Evaluate `coverage_estimate`
- Count `dry_violations` (more = worse)
- Consider `mocking_approach` quality
- Raw `test_count` relative to codebase size

### Overengineering Judge

Focus on `facts.overengineering`:
- Count `abstractions` issues
- Count `defensive_code` issues
- Consider `config_complexity`
- FEWER issues = HIGHER score (inverse)

### Dead Code Judge

Focus on `facts.dead_code`:
- Sum all unused items
- Weight `unused_functions` > `unused_imports`
- Count `todo_comments` and `commented_code_blocks`
- FEWER issues = HIGHER score (inverse)

## Important Rules

1. **Use the rubric** - Don't invent criteria
2. **Be consistent** - Apply the same standards to all repos
3. **Cite evidence** - Every score needs justification from facts
4. **Be comparative** - Rankings should reflect relative quality
5. **Valid JSON only** - Output must be parseable
```

**Step 2: Commit**

Run: `git add skills/llm-judge/references/judge-agents.md && git commit --no-verify --no-gpg-sign -m "feat(llm-judge): add judge agents reference"`

---

## Task 5: Create Main Skill File

**Files:**
- Create: `skills/llm-judge/SKILL.md`

**Step 1: Write the main skill file**

```markdown
---
name: llm-judge
description: LLM-as-judge methodology for comparing code implementations across repositories. Scores implementations on functionality, security, test quality, overengineering, and dead code using weighted rubrics. Used by /beagle:llm-judge command.
---

# LLM Judge Skill

Compare code implementations across 2+ repositories using structured evaluation.

## Overview

This skill implements a two-phase LLM-as-judge evaluation:

1. **Phase 1: Fact Gathering** - Parallel agents explore each repo and extract structured facts
2. **Phase 2: Judging** - Parallel judges score each dimension using consistent rubrics

## Reference Files

| File | Purpose |
|------|---------|
| [references/fact-schema.md](references/fact-schema.md) | JSON schema for Phase 1 facts |
| [references/scoring-rubrics.md](references/scoring-rubrics.md) | Detailed rubrics for each dimension |
| [references/repo-agent.md](references/repo-agent.md) | Instructions for Phase 1 agents |
| [references/judge-agents.md](references/judge-agents.md) | Instructions for Phase 2 judges |

## Scoring Dimensions

| Dimension | Default Weight | Evaluates |
|-----------|----------------|-----------|
| Functionality | 30% | Spec compliance, test pass rate |
| Security | 25% | Vulnerabilities, security patterns |
| Test Quality | 20% | Coverage, DRY, mock boundaries |
| Overengineering | 15% | Unnecessary complexity |
| Dead Code | 10% | Unused code, TODOs |

## Scoring Scale

| Score | Meaning |
|-------|---------|
| 5 | Excellent - Exceeds expectations |
| 4 | Good - Meets requirements, minor issues |
| 3 | Average - Functional but notable gaps |
| 2 | Below Average - Significant issues |
| 1 | Poor - Fails basic requirements |

## Phase 1: Spawning Repo Agents

For each repository, spawn a Task agent with:

```
You are a Phase 1 Repo Agent for the LLM Judge evaluation.

**Your Repo:** $REPO_LABEL at $REPO_PATH
**Spec Document:**
$SPEC_CONTENT

**Instructions:** Read @beagle:llm-judge references/repo-agent.md

Gather facts and return a JSON object following the schema in references/fact-schema.md.

Load @beagle:llm-artifacts-detection for dead code and overengineering analysis.

Return ONLY valid JSON, no markdown or explanations.
```

## Phase 2: Spawning Judge Agents

After all Phase 1 agents complete, spawn 5 judge agents (one per dimension):

```
You are the $DIMENSION Judge for the LLM Judge evaluation.

**Spec Document:**
$SPEC_CONTENT

**Facts from all repos:**
$ALL_FACTS_JSON

**Instructions:** Read @beagle:llm-judge references/judge-agents.md

Score each repo on $DIMENSION using the rubric in references/scoring-rubrics.md.

Return ONLY valid JSON following the judge output schema.
```

## Aggregation

After Phase 2 completes:

1. Collect scores from all 5 judges
2. For each repo, compute weighted total:
   ```
   weighted_total = sum(score[dim] * weight[dim]) / 100
   ```
3. Rank repos by weighted total (descending)
4. Generate verdict explaining the ranking

## Output

Write results to `.beagle/llm-judge-report.json` and display markdown summary.

## Dependencies

- `@beagle:llm-artifacts-detection` - Reused by repo agents for dead code/overengineering
```

**Step 2: Commit**

Run: `git add skills/llm-judge/SKILL.md && git commit --no-verify --no-gpg-sign -m "feat(llm-judge): add main skill file"`

---

## Task 6: Create the Command File

**Files:**
- Create: `commands/llm-judge.md`

**Step 1: Write the command file**

```markdown
---
description: Compare code implementations across 2+ repos using LLM-as-judge methodology with weighted scoring
---

# LLM Judge

Compare code implementations across multiple repositories using structured LLM-as-judge evaluation.

## Usage

```bash
/beagle:llm-judge <spec> <repo1> <repo2> [repo3...] [--labels=...] [--weights=...] [--branch=...]
```

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `spec` | Yes | Path to spec/requirements document |
| `repos` | Yes | 2+ paths to repositories to compare |
| `--labels` | No | Comma-separated labels (default: directory names) |
| `--weights` | No | Override weights, e.g., `functionality:40,security:30` |
| `--branch` | No | Branch to compare against main (default: current) |

## Examples

```bash
# Basic comparison
/beagle:llm-judge ./spec.md /path/to/repo-a /path/to/repo-b

# With custom labels
/beagle:llm-judge ./spec.md --labels="Claude,GPT-4,Gemini" /path/a /path/b /path/c

# With custom weights
/beagle:llm-judge ./spec.md --weights="functionality:40,security:35,tests:15,overengineering:5,dead_code:5" /path/a /path/b
```

## Step 1: Parse Arguments

Parse `$ARGUMENTS` to extract:
- `spec_path`: First positional argument
- `repo_paths`: Remaining positional arguments (must be 2+)
- `labels`: From `--labels` flag or derive from directory names
- `weights`: From `--weights` flag or use defaults
- `branch`: From `--branch` flag or use "main"

**Default Weights:**
```json
{
  "functionality": 30,
  "security": 25,
  "tests": 20,
  "overengineering": 15,
  "dead_code": 10
}
```

## Step 2: Validate Inputs

```bash
# Check spec exists
[ -f "$SPEC_PATH" ] || echo "Error: Spec file not found: $SPEC_PATH"

# Check each repo exists and is a git repo
for repo in $REPO_PATHS; do
  [ -d "$repo/.git" ] || echo "Error: Not a git repository: $repo"
done

# Ensure at least 2 repos
[ ${#REPO_PATHS[@]} -ge 2 ] || echo "Error: Need at least 2 repositories to compare"
```

If validation fails, exit with error message.

## Step 3: Read Spec Document

```bash
SPEC_CONTENT=$(cat "$SPEC_PATH")
```

## Step 4: Load the Skill

Load the llm-judge skill: `Skill(skill: "beagle:llm-judge")`

## Step 5: Phase 1 - Spawn Repo Agents

Spawn N parallel agents (one per repo) using the `Task` tool:

```
For each repo, spawn a Task with:

prompt: |
  You are a Phase 1 Repo Agent for the LLM Judge evaluation.

  **Your Repo:** $LABEL at $REPO_PATH

  **Spec Document:**
  $SPEC_CONTENT

  **Instructions:**
  1. Load skill: Skill(skill: "beagle:llm-judge")
  2. Read references/repo-agent.md for detailed instructions
  3. Read references/fact-schema.md for the output format
  4. Load Skill(skill: "beagle:llm-artifacts-detection") for analysis

  Explore the repository and gather facts. Return ONLY valid JSON following the fact schema.

  Do NOT score or judge. Only gather facts.

subagent_type: "general-purpose"
description: "Gather facts from $LABEL repo"
```

Wait for all agents to complete. Collect their JSON outputs into `ALL_FACTS` array.

## Step 6: Validate Phase 1 Results

For each repo agent result:
1. Verify it returned valid JSON
2. Verify required fields are present
3. If any agent failed, report error and abort

```bash
# Validate JSON (example check)
echo "$FACTS" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null || echo "Invalid JSON from $LABEL"
```

## Step 7: Phase 2 - Spawn Judge Agents

Spawn 5 parallel judge agents using the `Task` tool:

```
For each dimension in [functionality, security, tests, overengineering, dead_code]:

prompt: |
  You are the $DIMENSION Judge for the LLM Judge evaluation.

  **Spec Document:**
  $SPEC_CONTENT

  **Facts from all repos:**
  $ALL_FACTS_JSON

  **Instructions:**
  1. Load skill: Skill(skill: "beagle:llm-judge")
  2. Read references/judge-agents.md for detailed instructions
  3. Read references/scoring-rubrics.md for the $DIMENSION rubric

  Score each repo on $DIMENSION. Return ONLY valid JSON with scores and justifications.

subagent_type: "general-purpose"
description: "Judge $DIMENSION dimension"
```

Wait for all judges to complete. Collect their outputs.

## Step 8: Aggregate Scores

Combine all judge outputs:

```python
# Pseudocode for aggregation
for repo_label in labels:
    scores[repo_label] = {}
    for dimension in dimensions:
        scores[repo_label][dimension] = judge_outputs[dimension]['scores'][repo_label]

    # Compute weighted total
    weighted_total = sum(
        scores[repo_label][dim]['score'] * weights[dim] / 100
        for dim in dimensions
    )
    scores[repo_label]['weighted_total'] = round(weighted_total, 2)

# Rank by weighted total
ranking = sorted(labels, key=lambda l: scores[l]['weighted_total'], reverse=True)
```

## Step 9: Generate Verdict

Based on the ranking and score differences, generate a verdict:

```
The verdict should:
1. Name the winner
2. Explain WHY they won (which dimensions drove the result)
3. Note any close calls or trade-offs
```

## Step 10: Write JSON Report

Create `.beagle` directory if needed:

```bash
mkdir -p .beagle
```

Write to `.beagle/llm-judge-report.json`:

```json
{
  "version": "1.0.0",
  "created_at": "ISO timestamp",
  "spec_file": "$SPEC_PATH",
  "repos": [
    { "label": "...", "path": "...", "git_head": "..." }
  ],
  "weights": { ... },
  "scores": { ... },
  "ranking": [ ... ],
  "verdict": "..."
}
```

## Step 11: Display Summary

```markdown
## LLM Judge Results

**Spec:** $SPEC_PATH
**Repos compared:** $LABELS

### Scores

| Dimension | Weight | $LABEL1 | $LABEL2 | ... |
|-----------|--------|---------|---------|-----|
| Functionality | 30% | X | Y | |
| Security | 25% | X | Y | |
| Tests | 20% | X | Y | |
| Overengineering | 15% | X | Y | |
| Dead Code | 10% | X | Y | |
| **Weighted Total** | | **X.XX** | **Y.YY** | |

### Ranking

1. **$WINNER** (X.XX)
2. $SECOND (Y.YY)
...

### Verdict

$VERDICT

### Detailed Justifications

#### Functionality
- **$LABEL1:** $JUSTIFICATION
- **$LABEL2:** $JUSTIFICATION

[Repeat for each dimension]

---

Report saved to `.beagle/llm-judge-report.json`
```

## Step 12: Verification

Before completing:

1. Verify `.beagle/llm-judge-report.json` exists and is valid JSON
2. Verify all repos have scores for all dimensions
3. Verify weighted totals sum correctly

```bash
# Verify JSON
python3 -c "import json; json.load(open('.beagle/llm-judge-report.json'))" && echo "Valid report"
```

## Rules

- Always validate inputs before proceeding
- Spawn Phase 1 agents in parallel (one per repo)
- Wait for Phase 1 to complete before Phase 2
- Spawn Phase 2 agents in parallel (one per dimension)
- Every score must have a justification
- Write JSON report before displaying summary
```

**Step 2: Commit**

Run: `git add commands/llm-judge.md && git commit --no-verify --no-gpg-sign -m "feat(llm-judge): add command file"`

---

## Task 7: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Read current CLAUDE.md**

Run: Read the current CLAUDE.md to find the commands table.

**Step 2: Add llm-judge to the commands table**

Find the "Key Commands" table and add:

```markdown
| `llm-judge` | Compare implementations using LLM-as-judge methodology |
```

**Step 3: Commit**

Run: `git add CLAUDE.md && git commit --no-verify --no-gpg-sign -m "docs: add llm-judge to commands table"`

---

## Task 8: Update README or Plugin Manifest

**Files:**
- Check: `.claude-plugin/plugin.json` for version bump needs

**Step 1: Check if version bump is needed**

This is a new feature (minor version bump). Read `.claude-plugin/plugin.json` and increment the minor version.

**Step 2: Commit version bump**

Run: `git add .claude-plugin/plugin.json && git commit --no-verify --no-gpg-sign -m "chore: bump version for llm-judge feature"`

---

## Task 9: Final Verification

**Step 1: Verify file structure**

```bash
ls -la skills/llm-judge/
ls -la skills/llm-judge/references/
ls -la commands/llm-judge.md
```

Expected:
```
skills/llm-judge/
├── SKILL.md
└── references/
    ├── fact-schema.md
    ├── scoring-rubrics.md
    ├── repo-agent.md
    └── judge-agents.md

commands/llm-judge.md
```

**Step 2: Verify all commits**

```bash
git log --oneline feat/llm-judge ^main
```

Expected: 7-8 commits for the feature.

**Step 3: Test command loads**

In a new Claude Code session, run `/beagle:llm-judge --help` or similar to verify the command is recognized.

---

## Summary

| Task | Files Created/Modified |
|------|------------------------|
| 1 | `skills/llm-judge/references/fact-schema.md` |
| 2 | `skills/llm-judge/references/scoring-rubrics.md` |
| 3 | `skills/llm-judge/references/repo-agent.md` |
| 4 | `skills/llm-judge/references/judge-agents.md` |
| 5 | `skills/llm-judge/SKILL.md` |
| 6 | `commands/llm-judge.md` |
| 7 | `CLAUDE.md` (modified) |
| 8 | `.claude-plugin/plugin.json` (version bump) |
| 9 | Verification only |
