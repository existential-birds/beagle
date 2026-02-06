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
