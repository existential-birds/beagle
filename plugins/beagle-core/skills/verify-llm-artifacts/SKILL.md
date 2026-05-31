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

1. Load `Skill(skill: "beagle-core:review-verification-protocol")` — general anti–false-positive discipline, including the **Anti-confabulation gate** (echo the artifact from a freshly read source before any verdict). The Load + ECHO gate in step 1 is this skill's concrete instance of that rule.
2. Load `Skill(skill: "beagle-core:llm-artifacts-detection")` — category criteria for what counts as a real issue.

## Instructions

### Hard gates

Objective pass conditions before you claim verification is done:

1. **Input parse:** The JSON load command in step 1 exits 0 (no traceback). **Pass:** valid JSON on disk at `.beagle/llm-artifacts-review.json`.
2. **Echo before adjudicate:** Step 1 has printed the full finding table (one row per `findings[]` entry: id, file, line, category, description) sourced from the parsed JSON in **this** turn. **Pass:** the table exists in your output and its row count equals `len(findings)` — you have not begun any verdict before it.
3. **ID lock:** Step 1 has recorded the exact id set from `findings[]` and stated it explicitly. Every `results` entry maps 1:1 to a locked id — none added, none dropped. **Pass:** the locked id list is printed; if at any point an apparent finding has no matching locked id, you STOP (see step 1, ID lock).
4. **Evidence before verdict:** For each finding you adjudicate, you have applied [references/verification-checklist.md](references/verification-checklist.md) for its `category` (or documented why the category is N/A) and recorded matching strings in `checks_performed`. **Pass:** no `status` without at least one checklist-backed check or an explicit N/A note in `notes`.
5. **Output contract:** After writing `.beagle/llm-artifacts-verification.json`, the validate command in step 4 exits 0; `summary` counts equal the number of `results` entries by `status`; the `results` id set equals the **locked id set** from gate 3 exactly. **Pass:** schema-valid JSON and `results` ids == locked ids == source `findings[]` ids.

### 1. Load, ECHO, and lock ids

This is a two-part gate. **Parsing is not loading** — a `json.load` that exits 0 only proves the file is well-formed, not that you have the findings in context. You must echo the actual content before any adjudication.

**1a. Parse and echo the finding table.**

Print every finding from the parsed `findings[]` array — not from memory, not from the branch name, not from surrounding files:

```bash
python3 - <<'PY'
import json
r = json.load(open('.beagle/llm-artifacts-review.json'))
f = r['findings']
print(f"git_head={r.get('git_head')} scope={r.get('scope')} count={len(f)}")
print("| id | file | line | category | description |")
print("|----|------|------|----------|-------------|")
for x in f:
    desc = (x.get('description') or '').replace('|', '\\|')[:80]
    print(f"| {x['id']} | {x.get('file')} | {x.get('line')} | {x.get('category')} | {desc} |")
print("ids=" + ",".join(str(x['id']) for x in f))
PY
```

**Pass:** the command exits 0 and the table (one row per finding) appears in your output.

> **The only source of findings is the parsed `findings[]` array.** Do not infer findings from the branch name, the working directory, or surrounding files. If your mental model of the findings differs from the echoed table, **the table wins** — discard the mental model and adjudicate only the rows above.

**1b. ID lock (hard gate, before any adjudication).**

Record the exact set of ids from the `ids=` line above and state it now, e.g. `Locked ids: {1, 2, 3, 4, 5, 6, 7}`. This is the **locked id set**. Every result you write in step 4 must map 1:1 to this set: no id added, none dropped. The output id-check in step 4 references this locked set, not a re-derived one.

If, while verifying, you find yourself about to adjudicate a finding whose id is **not** in the locked set — or about to write a result for a file that does not appear in any locked row — **STOP**. That is an agent error (you are reasoning from memory or context, not the report). Re-read `findings[]` via the echo command above and restart adjudication. Do **not** record such a finding as `false_positive` (see step 3, Status discipline).

Record `git_head` and `scope` from the report (already printed by 1a). If the working tree no longer matches (optional strict mode: compare to `git rev-parse HEAD`), warn that line numbers may drift.

### 2. Order findings

Default order:

1. `category == "dead_code"` or `fix_action == "delete"` or `risk == "High"`
2. Remaining findings by `(risk descending, id ascending)`

With `--priority-only`, stop after processing category `dead_code` and all `fix_action: delete` (still write full output for those processed).

### 3. Verify each finding

For each finding, follow [references/verification-checklist.md](references/verification-checklist.md). Its **first** check for every category is the existence precondition: confirm the cited `file` exists at `source_git_head` before running any symbol/usage check.

**Minimum evidence per finding:**

- **Existence first:** Confirm `file` exists at `source_git_head` (`git cat-file -e <head>:<file>` or `test -f`). A nonexistent cited file is **not** routine — it is either a deleted-file finding (note it) or a sign you are not looking at the real report. A **wall** of missing-file results means STOP and re-read `findings[]` (step 1a). Do not absorb missing files silently.
- Read the **file** at the cited location and enough context to judge (parent symbol, imports).
- For unused/dead claims: **search** the repo (symbols, exports, string hooks) unless the issue is purely stylistic with no removal.

**Pass:** `checks_performed` lists only checks you actually ran (e.g. `file_exists`, `read_symbol`, `ripgrep_symbol`); `notes` cite the decisive observation.

Assign one status:

| `status` | Meaning |
|----------|---------|
| `confirmed_issue` | The finding in the report is valid; acting on it is appropriate. |
| `false_positive` | The finding **in the report** is invalid (factually wrong, or harmful if "fixed"); do not auto-fix. |
| `inconclusive` | Needs human or product context; treat like risky in `fix-llm-artifacts`. |

Set `confidence`: `high` | `medium` | `low` based on how direct the evidence was.

**Status discipline (hard rule):** `false_positive` means *"the finding present in the report is invalid."* It never means *"this finding is not in the report."* If you encounter an apparent finding that cannot be matched to an entry in the locked id set (step 1b), that is **agent error, not a false positive** — STOP, re-read `findings[]` via the step-1a echo command, and restart adjudication. Writing a `false_positive` (or any status) for an id outside the locked set is forbidden.

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
      "checks_performed": ["file_exists", "read_symbol", "ripgrep_symbol", "export_trace"],
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

Validate the file you wrote:

```bash
python3 -c "import json; json.load(open('.beagle/llm-artifacts-verification.json'))"
```

**Pass:** command exits 0; re-open the file and confirm (a) `summary` matches `results` (count each `status`), and (b) the set of `results` ids equals the **locked id set** from step 1b exactly — no id added, none dropped. If the id sets differ, the pass is broken: do not ship; re-read `findings[]` (step 1a) and reconcile.

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
- **`fix_action` custody:** The `fix_action` field (`refactor`/`delete`/`simplify`/`extract`) is emitted by `review-llm-artifacts` and consumed by `fix-llm-artifacts` as a risk gate; verification carries it through unchanged and does **not** re-validate it.
