---
name: verify-llm-artifacts
description: Confirms or rejects findings from review-llm-artifacts before deletes or risky refactors. Loads review-verification-protocol-style checks per finding. Use after a review run, when the user wants to reduce false positives, before fix-llm-artifacts on dead code, or when validating a full-project scan.
disable-model-invocation: true
---

# Verify LLM Artifacts Findings

Second-pass verification for `.beagle/llm-artifacts-review.json`. The detection pass optimizes for recall; this pass optimizes for **precision** so agents do not remove or “clean” code that is still required.

## When to run

- After `/beagle-core:review-llm-artifacts` (especially full-project scans).
- Before `/beagle-core:fix-llm-artifacts` when findings include **deletions**, **dead code**, or **High** risk.
- Whenever past runs flagged artifacts that should not have been removed.

## Inputs

- **Required:** `.beagle/llm-artifacts-review.json` from a completed review.
- **Optional:** `$ARGUMENTS` — `--priority-only` (verify `dead_code` and any `fix_action` of `delete` first; then others), `--id N` (single finding id).

If the review file is missing, exit with: `Run /beagle-core:review-llm-artifacts first.`

## Prerequisite skills

1. Load `Skill(skill: "beagle-core:review-verification-protocol")` — general anti–false-positive discipline.
2. Load `Skill(skill: "beagle-core:llm-artifacts-detection")` — category criteria for what counts as a real issue.

## Instructions

### 1. Load and validate JSON

```bash
python3 -c "import json; json.load(open('.beagle/llm-artifacts-review.json'))"
```

Record `git_head` and `scope` from the report. If the working tree no longer matches (optional strict mode: compare to `git rev-parse HEAD`), warn that line numbers may drift.

### 2. Order findings

Default order:

1. `category == "dead_code"` or `fix_action == "delete"` or `risk == "High"`
2. Remaining findings by `(risk descending, id ascending)`

With `--priority-only`, stop after processing category `dead_code` and all `fix_action: delete` (still write full output for those processed).

### 3. Verify each finding

For each finding, follow [references/verification-checklist.md](references/verification-checklist.md).

**Minimum evidence per finding:**

- Read the **file** at the cited location and enough context to judge (parent symbol, imports).
- For unused/dead claims: **search** the repo (symbols, exports, string hooks) unless the issue is purely stylistic with no removal.

Assign one status:

| `status` | Meaning |
|----------|---------|
| `confirmed_issue` | The finding is valid; acting on it is appropriate. |
| `false_positive` | The finding should be discarded; do not auto-fix. |
| `inconclusive` | Needs human or product context; treat like risky in `fix-llm-artifacts`. |

Set `confidence`: `high` | `medium` | `low` based on how direct the evidence was.

### 4. Write output

Create `.beagle` if needed. Write **`.beagle/llm-artifacts-verification.json`**:

```json
{
  "version": "1.0.0",
  "created_at": "2026-04-19T12:00:00Z",
  "source_report": ".beagle/llm-artifacts-review.json",
  "source_git_head": "<from review>",
  "review_scope": "all|changed",
  "results": [
    {
      "id": 1,
      "status": "confirmed_issue|false_positive|inconclusive",
      "confidence": "high|medium|low",
      "checks_performed": ["read_symbol", "ripgrep_symbol", "export_trace"],
      "notes": "1-3 sentences of evidence"
    }
  ],
  "summary": {
    "confirmed_issue": 0,
    "false_positive": 0,
    "inconclusive": 0
  }
}
```

### 5. Summarize for the user

Print a short markdown table: id, category, original one-line description, **verdict**, confidence.

End with:

- Counts of confirmed vs false positive vs inconclusive.
- Recommendation: run `fix-llm-artifacts` only on confirmed (see that skill when verification file is present).

## Rules

- Do **not** invent new issues; only adjudicate existing `findings[]` entries.
- Prefer `inconclusive` over `confirmed_issue` when removal could break dynamic or cross-repo usage.
- Preserve finding `id` values exactly as in the source report.

## Integration

- **`fix-llm-artifacts`:** When this file exists, use it to skip `false_positive` ids and to treat `inconclusive` like risky fixes.
