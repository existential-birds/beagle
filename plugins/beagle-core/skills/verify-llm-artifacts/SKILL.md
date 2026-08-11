---
name: verify-llm-artifacts
description: Adjudicates findings from review-llm-artifacts into confirmed_issue / false_positive / inconclusive before any delete or risky refactor. Applies a risk-tiered evidence gate - full per-finding investigation only where the verdict authorizes a deletion, record-only adjudication everywhere else. Use after a review run, when the user wants to reduce false positives, before fix-llm-artifacts on dead code, or when validating a full-project scan.
disable-model-invocation: true
---

# Verify LLM Artifacts Findings

Second-pass adjudication of `.beagle/llm-artifacts-review.json`. The detection pass optimizes for recall; this pass optimizes for **precision** where precision has a price — so agents do not remove code that is still required.

This skill imports its verification vocabulary from the `beagle-core:verification-budget` skill. Tier names (REVERSIBLE / IRREVERSIBLE), the budget syntax, the one-echo rule, and the prove-a-negative ban are defined there and are **not restated here**.

## When to run

- After the [review-llm-artifacts](../review-llm-artifacts/SKILL.md) skill, especially full-project scans.
- Before the [fix-llm-artifacts](../fix-llm-artifacts/SKILL.md) skill when any finding carries `fix_action: delete`.
- Whenever past runs flagged artifacts that should not have been removed.

## Inputs

- **Required:** `.beagle/llm-artifacts-review.json` from a completed review.
- **Optional:** `$ARGUMENTS` — `--priority-only` (adjudicate `dead_code` and every `fix_action: delete` first, then stop), `--id N` (single finding id).

If the review file is missing, exit with: `Run the review-llm-artifacts skill first.`

Load category criteria from the `beagle-core:llm-artifacts-detection` skill **only** for the categories present in `findings[]`, and only when a verdict actually turns on the criteria. Do not preload the whole skill, and do not load `review-verification-protocol` — its budget vocabulary now lives in `verification-budget`, which this skill already imports.

## The one gate: risk-tiered evidence

There is exactly one hard gate in this skill. Classify each finding by the **reversibility of the action its verdict authorizes**, then apply the matching evidence requirement.

| Finding | Tier | Evidence required before recording a status |
|---------|------|---------------------------------------------|
| `fix_action == "delete"` | **IRREVERSIBLE** | Full ceremony: existence check at `source_git_head`, full-context read of the cited symbol, enumerated reference search, `checks_performed` recorded. See [references/verification-checklist.md](references/verification-checklist.md). |
| Any other `fix_action` (`refactor`, `simplify`, `extract`) | **REVERSIBLE** | **None.** Adjudicate from the finding record itself. `checks_performed` may be `[]`. |

A `dead_code` finding whose `fix_action` is not `delete` authorizes no removal — it is REVERSIBLE. The tier tracks what the downstream fix can *do*, not the category label.

**Why the split:** a wrong REVERSIBLE verdict costs a human one disagreement in a report they are already reading. A wrong IRREVERSIBLE verdict destroys code. Verification cost tracks the cost of being wrong (`verification-budget` §1).

**Not-N/A rule:** a REVERSIBLE finding you cannot decide from the record alone is `inconclusive`. Do not escalate it into ceremony to force a decision — `inconclusive` is the correct, cheap answer and `fix-llm-artifacts` already treats it as risky.

## Instructions

### 1. Parse and echo the finding table (once)

This is the pipeline's **single** echo (`verification-budget` §3). Downstream stages trust it; `fix-llm-artifacts` does not re-echo.

```bash
jq -r '"git_head=\(.git_head) scope=\(.scope) count=\(.findings|length)",
       "| id | file:line | category | fix_action | risk | description |",
       "|----|-----------|----------|------------|------|-------------|",
       (.findings[] | "| \(.id) | \(.file):\(.line) | \(.category) | \(.fix_action // "-") | \(.risk // "-") | \(((.description // "")|gsub("\\|";"\\|"))[0:80]) |"),
       "ids=\(.findings|map(.id|tostring)|join(","))",
       "destructive_ids=\([.findings[]|select(.fix_action=="delete")|.id|tostring]|join(","))"' \
  .beagle/llm-artifacts-review.json
```

The command exiting 0 proves the file is well-formed and puts the rows in context. `ids=` is the id set you adjudicate; `destructive_ids=` is the IRREVERSIBLE subset.

> **The parsed `findings[]` array is the only source of findings.** Do not infer findings from the branch name, the working directory, or surrounding files. If your mental model differs from the echoed table, the table wins.

Record `git_head` and `scope`. If `git rev-parse HEAD` differs, note that line numbers may have drifted — this is a warning, not a stop.

### 2. Order findings

1. `fix_action == "delete"`, then `category == "dead_code"`, then `risk == "High"`
2. Remaining findings by `(risk descending, id ascending)`

With `--priority-only`, stop after the `dead_code` and `fix_action: delete` findings; still write full output for those processed.

### 3. Adjudicate

**REVERSIBLE findings** — read the finding record, assign a status, write one sentence of reasoning in `notes`. No file reads required. If the record is too thin to judge, record `inconclusive`.

**IRREVERSIBLE findings** — work [references/verification-checklist.md](references/verification-checklist.md) for the finding's `category` and record what you ran in `checks_performed` (e.g. `file_exists`, `read_symbol`, `ripgrep_symbol`, `export_trace`).

Statuses (schema-fixed, do not extend):

| `status` | Meaning |
|----------|---------|
| `confirmed_issue` | The finding in the report is valid; acting on it is appropriate. |
| `false_positive` | The finding **in the report** is invalid — factually wrong, or harmful if "fixed". Do not auto-fix. |
| `inconclusive` | Needs human or product context. `fix-llm-artifacts` treats it as risky. |

Set `confidence`: `high` | `medium` | `low`, by how direct the evidence was.

**Status discipline.** `false_positive` means *"the finding present in the report is invalid."* It never means *"this finding is not in the report."*

**Loop budget — findings mismatch.** If you are about to adjudicate an id that is not in the `ids=` line, or a file that appears in no echoed row: **max 1 pass.** Re-run the step-1 command once. Stop condition: every id you are adjudicating appears in `ids=`. Tie-break: drop the unmatched item, adjudicate only the echoed ids, and flag the discrepancy in your step-5 summary. Proceed — do not restart adjudication a second time.

**Loop budget — missing cited files.** A finding whose cited file does not exist at `source_git_head` is adjudicated on that fact (usually `false_positive`, sometimes `inconclusive`), with a note. If **most** findings cite nonexistent files, re-run step 1 once to confirm you are reading the real report. **Max 1 pass.** Stop condition: the re-echoed table's paths match what you adjudicated. Tie-break: record the affected ids as `inconclusive` with a `report-may-be-stale` note and proceed.

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

`results` maps 1:1 to `findings[]` ids. `checks_performed` lists only checks you actually ran, and is `[]` for REVERSIBLE findings.

**Scripted audit.** Counting is not a judgment task — run the check, do not perform it by eye:

```bash
jq -n \
  --slurpfile r .beagle/llm-artifacts-review.json \
  --slurpfile v .beagle/llm-artifacts-verification.json \
  '($r[0].findings|map(.id)|sort) as $src
   | ($v[0].results|map(.id)|sort) as $out
   | ($v[0].results) as $res
   | ($v[0].summary) as $sum
   | {missing_ids: ($src - $out),
      extra_ids: ($out - $src),
      summary_mismatch: (["confirmed_issue","false_positive","inconclusive"]
        | map(. as $s | {status:$s, counted:($res|map(select(.status==$s))|length), recorded:($sum[$s] // 0)})
        | map(select(.counted != .recorded)))}
   | . + {ok: ((.missing_ids|length)==0 and (.extra_ids|length)==0 and (.summary_mismatch|length)==0)}'
```

**Loop budget — output reconciliation.** **Max 1 pass.** Stop condition: the command prints `"ok": true`. On `false`, make one corrective write — add `missing_ids` as `inconclusive` entries, drop `extra_ids`, recompute `summary` — and re-run. Tie-break: if the second run is still `false`, ship the file, report the exact `jq` output in step 5, and recommend against running `fix-llm-artifacts` until it is reconciled. Do not re-adjudicate.

With `--priority-only` or `--id N`, `missing_ids` for findings you deliberately did not process is expected — say so instead of back-filling.

### 5. Summarize for the user

A short markdown table: id, category, original one-line description, **verdict**, confidence.

End with:

- Counts of confirmed vs false positive vs inconclusive.
- Any flags raised by the step-3 or step-4 tie-breaks.
- Recommendation: run `fix-llm-artifacts` on confirmed findings.

## Rules

- Do **not** invent new issues; only adjudicate existing `findings[]` entries.
- Prefer `inconclusive` over `confirmed_issue` when removal could break dynamic or cross-repo usage.
- Preserve finding `id` values exactly as in the source report.
- Ambiguity resolves toward *proceed and flag*, never toward *verify again*.

## Integration

- **`fix-llm-artifacts`:** consumes this file to skip `false_positive` ids and to treat `inconclusive` like risky fixes. It trusts the ids recorded here and does not re-echo the finding table.
- **`fix_action` custody:** `fix_action` (`refactor`/`delete`/`simplify`/`extract`) is emitted by `review-llm-artifacts` and consumed by `fix-llm-artifacts` as a risk gate. Verification reads it to assign the tier above and carries it through unchanged — it does **not** re-validate it.
