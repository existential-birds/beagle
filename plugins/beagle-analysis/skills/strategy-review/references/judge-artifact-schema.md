# Judge Artifact Schema

Machine-readable JSON output for strategy reviews. Produced only when judge artifact mode is explicitly requested — never emitted during normal reviews.

The schema bridges the prose review (`strategy-review.md`) and automated evaluation pipelines. Every numeric score maps directly to a prose label the reviewer already assigned. No new judgments are invented for the JSON — it's a structured projection of the same review, not a separate evaluation.

---

## Output file

**Filename:** `strategy-review.json`
**Location:** Same directory as `strategy-review.md`. If durable review state is active, also write to the review state directory.

When the user requests both prose and JSON (the default in judge mode), produce `strategy-review.md` first, then `strategy-review.json`. The JSON must be consistent with the prose — if a dimension is rated "Weak" in the prose, the JSON score must be 2.

---

## Score mapping

Strategy-review uses four rating levels. Map them to integers:

| Label | Score | Description |
|-------|-------|-------------|
| **Strong** | 4 | Element is specific, testable, and structurally sound |
| **Adequate** | 3 | Element is present and functional but has notable gaps |
| **Weak** | 2 | Element has significant structural problems |
| **Missing** | 1 | Element is absent or so vague it provides no guidance |

This is a 1–4 scale, not 1–5. The strategy-review skill has four levels; the JSON reflects them faithfully rather than inventing intermediate granularity.

---

## Schema definition

> **Note:** The example below is a partial illustrative fragment. It shows two of seven required `dimension_ratings`, one of the minimum two `failure_paths`, and one of the required 2–4 `critical_findings` to demonstrate the structure without duplicating the pattern for every entry. A valid `strategy-review.json` must include all seven dimensions, at least two failure paths, and 2–4 critical findings per the field reference below.

```json
{
  "schema_version": "1.0",

  "evaluator": {
    "skill": "beagle-analysis:strategy-review",
    "version": "2.11.0"
  },

  "review_metadata": {
    "reviewed_at": "2026-04-10T14:30:00Z",
    "documents": [
      {
        "name": "strategy-draft.md",
        "path": "relative/path/or/null",
        "sha256": "hex digest or null",
        "word_count": 1850
      }
    ],
    "subject": "Mobile-first inspection workflows for mid-market",
    "maturity": "near-final",
    "audience": "Board of directors",
    "timeframe": "18 months"
  },

  "kernel_extraction": {
    "diagnosis": {
      "found": true,
      "summary": "Growth stalled because competitors launched mobile-first while Fieldkit remained desktop-only.",
      "evidence": [
        {
          "text": "68% of inspections happen on-site with a phone, but our mobile experience is a responsive web wrapper that drops offline.",
          "provenance": "doc_quote",
          "location": "Diagnosis, paragraph 2"
        }
      ]
    },
    "guiding_policy": {
      "found": true,
      "summary": "Dominate mobile-first inspection workflows for mid-market; stop pursuing enterprise until core product is defensible.",
      "exclusions": [
        "Enterprise sales motion",
        "SOC 2 / SSO / audit trail features this year",
        "Matching BuildOps on feature breadth"
      ],
      "evidence": [
        {
          "text": "Won't build enterprise compliance features this year.",
          "provenance": "doc_quote",
          "location": "Guiding Policy"
        }
      ]
    },
    "coherent_actions": {
      "found": true,
      "count": 4,
      "actions": [
        "Ship native mobile app with full offline sync by Q3",
        "Kill enterprise sales motion — reassign AEs to mid-market",
        "Build HappyCo and Yardi integrations",
        "Launch reliability guarantee"
      ],
      "evidence": [
        {
          "text": "Kill enterprise sales motion — reassign two enterprise AEs to mid-market, cancel SOC 2 engagement ($180K → mobile engineering)",
          "provenance": "doc_quote",
          "location": "Coherent Actions, item 2"
        }
      ]
    },
    "chain_paragraph": "Growth stalled because competitors launched mobile-first while Fieldkit remained desktop-only, and the company drifted into enterprise to compensate. Therefore, dominate mobile-first inspection workflows for mid-market and stop pursuing enterprise until the core product is defensible. Which means: ship native mobile with offline sync, kill enterprise sales, build mid-market integrations, and launch a reliability guarantee."
  },

  "dimension_ratings": [
    {
      "dimension": 1,
      "name": "diagnosis_quality",
      "score": 4,
      "label": "Strong",
      "confidence": "high",
      "assessment": "Names a specific structural mistake with concrete evidence. The 68% mobile statistic and the drift-to-enterprise pattern are falsifiable claims.",
      "evidence": [
        {
          "text": "Treating mobile as feature request, not delivery surface.",
          "provenance": "doc_quote",
          "location": "Diagnosis"
        }
      ],
      "recommendation": null
    },
    {
      "dimension": 2,
      "name": "guiding_policy_strength",
      "score": 4,
      "label": "Strong",
      "confidence": "high",
      "assessment": "Makes a painful cut (enterprise) to concentrate force where the org has an edge. Exclusions are explicit.",
      "evidence": [
        {
          "text": "Won't build enterprise compliance features this year. Won't match BuildOps on breadth.",
          "provenance": "doc_quote",
          "location": "Guiding Policy"
        }
      ],
      "recommendation": null
    }
  ],

  "bad_strategy_patterns": [
    {
      "pattern": "fluff",
      "detected": false,
      "severity": null,
      "evidence": [],
      "resolution": null
    },
    {
      "pattern": "failure_to_face_challenge",
      "detected": false,
      "severity": null,
      "evidence": [],
      "resolution": null
    },
    {
      "pattern": "goals_as_strategy",
      "detected": false,
      "severity": null,
      "evidence": [],
      "resolution": null
    },
    {
      "pattern": "bad_objectives",
      "detected": false,
      "severity": null,
      "evidence": [],
      "resolution": null
    },
    {
      "pattern": "strategy_by_analogy",
      "detected": false,
      "severity": null,
      "evidence": [],
      "resolution": null
    }
  ],

  "assumption_risk_map": [
    {
      "assumption": "Team can ship native mobile with offline sync by Q3",
      "stated_in_doc": false,
      "impact_if_wrong": "high",
      "uncertainty": "high",
      "risk_level": "critical",
      "provenance": "reviewer_inference",
      "consequence": "Load-bearing action fails. Reliability guarantee becomes liability. Integrations built on unstable foundation."
    }
  ],

  "failure_paths": [
    {
      "name": "Capability gap stalls native mobile",
      "pattern": "capability_gap",
      "scenario": "Team has never built native mobile. Q3 deadline assumes execution speed the org hasn't demonstrated. Six-month research project dressed as a deliverable.",
      "likelihood": "medium",
      "current_mitigation": "Budget reallocation from SOC 2 engagement",
      "suggested_mitigation": "Prototype sprint in month 1. If offline sync isn't working by week 6, the Q3 date is fiction — trigger contingency plan."
    }
  ],

  "review_lenses_applied": [
    {
      "lens": "balanced_scorecard",
      "trigger": "Success criteria are financial-only (ARR growth target)",
      "findings": [
        "No leading indicators from customer or internal-process perspectives. Strategy has a 6-month blind spot between cause and detection."
      ]
    }
  ],

  "interview_lens_audit": [
    {
      "lens": "landscape_mapping",
      "assessment": "partially_reflected",
      "survived": [
        "Evolution stage awareness for mobile delivery surface"
      ],
      "dropped": [
        "Notes identified data pipeline as custom-built when three vendors now offer it as product — draft omits this"
      ],
      "impact_on_kernel": "Diagnosis sharpened by mobile evolution insight but missed the infrastructure commoditization finding",
      "evidence": [
        {
          "text": "Our data pipeline is custom-built but three vendors now sell this as a product",
          "provenance": "notes_cross_ref",
          "location": "lens-notes.md, landscape mapping section"
        },
        {
          "text": "We face competitive pressure in infrastructure",
          "provenance": "doc_quote",
          "location": "Diagnosis, paragraph 3"
        }
      ]
    }
  ],

  "critical_findings": [
    {
      "title": "Native mobile capability assumed but unverified",
      "severity": "critical",
      "description": "The load-bearing action (native mobile app with offline sync by Q3) requires a capability the team has never demonstrated.",
      "impact": "If this action slips, the reliability guarantee becomes a liability and the enterprise exit loses its rationale.",
      "evidence": [
        {
          "text": "Ship native mobile app with full offline sync by Q3",
          "provenance": "doc_quote",
          "location": "Coherent Actions, item 1"
        }
      ],
      "recommendation": "Add a capability validation milestone in month 1. Define what 'on track' looks like at week 6."
    }
  ],

  "blocking_findings": [
    "Native mobile capability assumed but unverified"
  ],

  "unresolved_questions": [
    "Has the team built native mobile before, or is this a first attempt?",
    "What happens to existing enterprise customers during the transition?"
  ],

  "aggregate_score": {
    "weighted_total": 3.45,
    "weights": {
      "diagnosis_quality": 20,
      "guiding_policy_strength": 20,
      "action_coherence": 15,
      "kernel_chain_integrity": 15,
      "bad_strategy_patterns": 10,
      "assumption_exposure": 10,
      "specificity_falsifiability": 10
    },
    "label": "Adequate",
    "confidence": "high"
  },

  "reward_signal": {
    "pass": false,
    "score": 0.82,
    "rationale": "One critical blocking finding (unverified capability assumption on load-bearing action). Strategy is structurally sound but not ready to act on without resolving the capability question."
  }
}
```

---

## Field reference

### Top-level fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `schema_version` | string | yes | Schema version. Currently `"1.0"`. |
| `evaluator` | object | yes | Skill identifier and version. |
| `review_metadata` | object | yes | Document metadata and review context. |
| `kernel_extraction` | object | yes | Extracted kernel elements with evidence. |
| `dimension_ratings` | array[7] | yes | All seven dimensions, each with score and evidence. |
| `bad_strategy_patterns` | array[5] | yes | All five patterns, each with detected flag. Always include all five — `detected: false` for absent patterns. |
| `assumption_risk_map` | array | yes | Load-bearing assumptions. May be empty if none found (unusual). |
| `failure_paths` | array | yes | Failure scenarios. Minimum 2, typically 3–5. |
| `review_lenses_applied` | array | no | Omit if no review lenses triggered. |
| `interview_lens_audit` | array | no | Omit if no interview lenses were used during the `beagle-analysis:strategy-interview`. |
| `critical_findings` | array | yes | The 2–4 highest-severity findings. |
| `blocking_findings` | array | yes | Titles of findings that should block the strategy from being finalized. May be empty. |
| `unresolved_questions` | array | yes | Questions the review couldn't answer. May be empty. |
| `aggregate_score` | object | yes | Weighted composite score. |
| `reward_signal` | object | yes | Pass/fail determination for evaluation loops. |

### Review metadata fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `reviewed_at` | string (ISO 8601) | yes | Timestamp of the review. |
| `documents` | array | yes | Documents reviewed, each with `name`, `path`, `sha256`, `word_count`. |
| `subject` | string | yes | What the strategy is about. |
| `maturity` | enum | yes | Document maturity stage. One of: `early-draft`, `near-final`, `post-hoc`. |
| `audience` | string | yes | Intended audience for the strategy. |
| `timeframe` | string | no | Strategy timeframe if stated in the document. |

### Evidence objects

Evidence entries appear throughout the schema. Every evidence object has:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `text` | string | yes | The quoted passage or stated finding. |
| `provenance` | enum | yes | One of: `doc_quote`, `reviewer_inference`, `unverified_assumption`, `source_backed`, `notes_cross_ref`. |
| `location` | string | no | Section or page reference in the source document. |

**Provenance rules** — these match the evidence tagging in `source-evidence.md`:

- **`doc_quote`**: Direct quote from the strategy document. Must be verifiable against the source.
- **`reviewer_inference`**: Derived from the document but not directly stated. The reviewer connected dots the author didn't.
- **`unverified_assumption`**: Claim the strategy depends on that isn't confirmed in the document or notes.
- **`source_backed`**: Claim in the document that cites an external source.
- **`notes_cross_ref`**: Finding from strategy-notes.md or interview durable state artifacts.

**Notation mapping:** The durable review state files (`source-evidence.md`) use a slightly different format for the same tags: `doc quote`, `reviewer inference`, `unverified assumption`, `source-backed`, `notes cross-ref`. The JSON enum values use underscores (`doc_quote`, `source_backed`, `notes_cross_ref`) per JSON convention. The semantics are identical.

### Dimension rating objects

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `dimension` | integer | yes | 1–7, matching the review dimensions. |
| `name` | string | yes | Snake_case dimension name (e.g., `diagnosis_quality`). |
| `score` | integer | yes | 1–4. See score mapping above. |
| `label` | string | yes | `Strong`, `Adequate`, `Weak`, or `Missing`. Must match score. |
| `confidence` | enum | yes | `high`, `medium`, or `low`. How much evidence supported the assessment. |
| `assessment` | string | yes | 2–3 sentence assessment (same content as the prose review). |
| `evidence` | array | yes | At least one evidence entry per dimension. |
| `recommendation` | string/null | yes | Null if `label` is `Strong`. Required otherwise. |

### Bad-strategy pattern objects

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `pattern` | enum | yes | One of: `fluff`, `failure_to_face_challenge`, `goals_as_strategy`, `bad_objectives`, `strategy_by_analogy`. |
| `detected` | boolean | yes | Whether the pattern was found. |
| `severity` | enum/null | yes | `null` if `detected: false`. One of: `critical`, `serious`, `moderate` when detected. |
| `evidence` | array | yes | Evidence entries. Empty array if `detected: false`. |
| `resolution` | string/null | yes | Suggested fix. `null` if `detected: false`. |

### Interview lens audit objects

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `lens` | string | yes | Lens identifier (e.g., `landscape_mapping`, `choice_cascade`, `value_innovation`). |
| `assessment` | enum | yes | One of: `reflected`, `partially_reflected`, `missing`. |
| `survived` | array[string] | yes | Specific findings that made it into the draft. May be empty. |
| `dropped` | array[string] | yes | Specific findings lost between notes and draft. May be empty. |
| `impact_on_kernel` | string | yes | How the lens findings affected the kernel elements. |
| `evidence` | array | yes | Evidence entries with provenance. |

### Aggregate score

| Field | Type | Description |
|-------|------|-------------|
| `weighted_total` | number | `Σ(dimension_score × weight / 100)`. Range: 1.0–4.0. |
| `weights` | object | Percentage weights per dimension. Must sum to 100. |
| `label` | enum | Overall label derived from `weighted_total`: Strong (≥3.5), Adequate (≥2.5), Weak (≥1.5), Missing (<1.5). |
| `confidence` | enum | `high`, `medium`, or `low`. Reflects the lowest confidence among the three highest-weighted dimensions. |

**Default weights:**

| Dimension | Weight | Rationale |
|-----------|--------|-----------|
| Diagnosis quality | 20 | Foundation — everything downstream depends on it |
| Guiding policy strength | 20 | The core strategic choice |
| Action coherence | 15 | Execution readiness |
| Kernel chain integrity | 15 | Overall logical coherence |
| Bad-strategy patterns | 10 | Anti-pattern detection |
| Assumption exposure | 10 | Risk awareness |
| Specificity / falsifiability | 10 | Testability and accountability |

### Reward signal

| Field | Type | Description |
|-------|------|-------------|
| `pass` | boolean | `true` if `weighted_total ≥ 2.5` AND `blocking_findings` is empty. |
| `score` | number | Normalized 0.0–1.0: `(weighted_total - 1.0) / 3.0`. |
| `rationale` | string | One-sentence explanation of pass/fail. Must cite blocking findings if `pass` is `false`. |

**Pass/fail logic:**
- A strategy passes if its aggregate is at least Adequate AND no findings are blocking.
- A critical finding with severity "critical" that affects a load-bearing element (diagnosis, guiding policy, or the load-bearing action) is blocking by default.
- The reviewer may mark additional findings as blocking based on judgment.

### Failure path pattern vocabulary

Use these values for the `pattern` field in `failure_paths`. These cover the most common failure modes. If a scenario doesn't fit any of these, use a descriptive snake_case value — but prefer these standard patterns for pipeline consistency:

| Pattern | Description |
|---------|-------------|
| `capability_gap` | Load-bearing action requires capability the org doesn't have |
| `slow_drift` | Guiding policy exclusions erode through accumulated exceptions |
| `unmodeled_response` | Strategy assumes static competitive environment |
| `political_veto` | Strategy requires stopping something a powerful stakeholder owns |
| `assumption_cascade` | One failed assumption propagates through tightly coupled actions |
| `execution_bottleneck` | Multiple actions depend on same scarce resource |
| `measurement_void` | No leading indicators; problems invisible until too late |

---

## Validation rules

Before emitting the JSON, verify:

1. **Parseable**: Output is valid JSON. No trailing commas, no comments, no markdown fencing in the file itself.
2. **Required fields present**: All fields marked required in the field reference exist.
3. **Score-label consistency**: Every `score` matches its `label` per the mapping table. A `score: 3` with `label: "Weak"` is invalid.
4. **All seven dimensions present**: `dimension_ratings` has exactly seven entries, dimensions 1–7.
5. **All five patterns present**: `bad_strategy_patterns` has exactly five entries, one per pattern.
6. **Evidence non-empty**: Every dimension rating has at least one evidence entry. Every critical finding has at least one evidence entry.
7. **Weighted total correct**: `aggregate_score.weighted_total` equals `Σ(score × weight / 100)` within ±0.01.
8. **Aggregate label correct**: Label matches the weighted_total per the threshold table.
9. **Reward signal consistent**: `pass` is `true` only if `weighted_total ≥ 2.5` AND `blocking_findings` is empty.
10. **Blocking findings reference real findings**: Every entry in `blocking_findings` matches a `title` in `critical_findings`.
11. **Provenance valid**: Every `provenance` value is one of the five allowed enum values.
12. **Recommendations present when needed**: `recommendation` is non-null for any dimension with `label` other than `Strong`.
13. **Confidence values valid**: Every `confidence` value is one of: `high`, `medium`, `low`.
14. **Bad-strategy pattern names valid**: The five `bad_strategy_patterns` entries use exactly these `pattern` values: `fluff`, `failure_to_face_challenge`, `goals_as_strategy`, `bad_objectives`, `strategy_by_analogy`.
15. **Failure paths minimum count**: `failure_paths` has at least 2 entries.
16. **Critical findings count**: `critical_findings` has 2–4 entries.

---

## Relationship to prose review

The JSON artifact is a structured projection of the prose review, not a replacement. The two must be consistent:

- Every dimension label in the JSON matches the rating in `strategy-review.md`.
- Every critical finding in the JSON appears in the prose Critical Findings section.
- The aggregate label in the JSON matches the overall assessment tone in the Review Summary.
- Evidence quotes in the JSON are verifiable against the same document passages cited in the prose.

When both are produced, write the prose first, then derive the JSON from it. This ensures the reviewer's judgment flows from careful prose analysis, not from filling in a schema.

---

## What downstream consumers can expect

External frameworks (evaluation pipelines, RL loops, comparison dashboards) can rely on:

- **Stable field names** within a `schema_version`. Breaking changes increment the version.
- **Complete dimension coverage**: All seven dimensions, all five bad-strategy patterns, always present.
- **Evidence provenance**: Every score traces to tagged evidence. Consumers can filter by provenance to distinguish document facts from reviewer inferences.
- **Deterministic pass/fail**: The `reward_signal.pass` field follows a documented formula — no hidden judgment.
- **Blocking findings as a gate**: A pipeline can use `blocking_findings.length === 0` as a quality gate.
