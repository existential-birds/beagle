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
/beagle:llm-judge ./spec.md /path/a /path/b /path/c --labels="Claude,GPT-4,Gemini"

# With custom weights
/beagle:llm-judge ./spec.md /path/a /path/b --weights="functionality:40,security:35,tests:15,overengineering:5,dead_code:5"
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
[ -f "$SPEC_PATH" ] || { echo "Error: Spec file not found: $SPEC_PATH"; exit 1; }

# Check each repo exists and is a git repo
for repo in "${REPO_PATHS[@]}"; do
  [ -d "$repo/.git" ] || { echo "Error: Not a git repository: $repo"; exit 1; }
done

# Ensure at least 2 repos
[ ${#REPO_PATHS[@]} -ge 2 ] || { echo "Error: Need at least 2 repositories to compare"; exit 1; }
```

Validation failures exit immediately with error message.

## Step 3: Read Spec Document

```bash
SPEC_CONTENT=$(cat "$SPEC_PATH") || { echo "Error: Failed to read spec file: $SPEC_PATH"; exit 1; }
[ -z "$SPEC_CONTENT" ] && { echo "Error: Spec file is empty: $SPEC_PATH"; exit 1; }
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
