# Orchestration prompt: gate-style improvements for every `SKILL.md`

Use this document as the **system prompt or initial user message** in a **new session** dedicated to this work. The goal is to process **every** skill in this repository with **one sub-agent per skill**, apply **rules → gates** improvements where they genuinely help, and **verify** each change so the tree stays consistent and functional.

**Background (shared vocabulary):** Read [Rules and Gates](https://blog.fsck.com/2026/04/07/rules-and-gates/) first. In short:

- A **rule** is easy to skip (“verify before you assert”) because the agent can rationalize compliance without evidence.
- A **gate** is a **sequenced** workflow with an **objective pass condition** before the next step (e.g. “URLs captured → then write findings,” not “I verified internally”).

Improvements in scope: rewrite soft instructions into **explicit sequences** and **checkable conditions** (what must exist on disk, what tool output must be attached, what question must be answerable honestly) **without** bloating skills or turning every doc into bureaucracy.

---

## Critical: division of labor

| Role | Allowed actions |
|------|-----------------|
| **Main session (orchestrator)** | Maintain queue, spawn **one sub-agent per skill path**, ingest structured results, update run log, handle blockers (merge conflicts, ambiguous duplicates), **do not** edit `SKILL.md` files directly except to fix orchestration metadata (e.g. the run log path) if needed. |
| **Per-skill sub-agent** | Read exactly **one** `SKILL.md` (and its `references/` only if required for context), decide if gate improvements apply, **edit only that skill’s files** if improving, **verify** own work, return a structured report. |

If the main session edits skills to “save time,” you lose per-skill isolation and reviewability. **Do not.**

## Command safety gate

The orchestrator may need shell probes for inventory, diff checks, or final sanity checks. Treat those probes as a gated workflow too, so a single expensive command does not make the whole session appear hung.

1. **Classify each command before launch** as one of:
   - `fast probe`: expected to return in a few seconds (`git ls-files`, `rg`, `sed`, targeted `git diff`)
   - `long-running`: unknown or potentially expensive (`cargo` builds/tests, `du` on large trees, broad `find`, cache scans, Docker-wide inspection)
2. **Only parallelize `fast probe` commands.** Never mix a `long-running` or unknown-cost command into the same parallel batch as quick checks.
3. **Avoid unbounded artifact-tree walks during preflight.** Do not run `du`, broad `find`, or similar whole-tree scans over `target/`, `node_modules/`, caches, or generated artifact directories unless that exact measurement is the task. Prefer narrow reads such as `ls`, `stat`, scoped `rg`, or an explicitly named measurement phase.
4. **Run long-running commands as named phases with visible progress.** Poll early, report what phase is in flight, and reassess if the first poll shows no useful output instead of waiting indefinitely.
5. **If a background process was spawned accidentally, inspect it before continuing.** Either keep polling it intentionally or stop it; do not leave ambiguous work running while telling the user you are still “checking.”

---

## Phase 0 — Inventory (one short sub-agent or shell)

1. Produce a **stable-ordered** list of all skills:

   ```bash
   git ls-files '**/skills/*/SKILL.md' | sort
   ```

   Save it to **`docs/skills-gates-run-queue.txt`** (one path per line, repo-relative). If the file already exists from a partial run, **resume** from the first path not marked `DONE` in the manifest (Phase 1).

2. Optional: count lines for ETA (`wc -l docs/skills-gates-run-queue.txt`).

Inventory commands should stay in the `fast probe` class from the Command safety gate above. If a queue-building or status-check command might take materially longer, treat it as a separate named phase rather than bundling it into preflight.

---

## Phase 1 — Run manifest

Create or append to **`docs/skills-gates-run-manifest.md`** with columns:

| Skill path | Status | Verdict | Summary |
|------------|--------|---------|---------|
| `plugins/.../SKILL.md` | `DONE` / `SKIP` / `FAIL` | `CHANGED` / `NO_CHANGE` / `N/A` | One line: what changed or why not |

**Rules:**

- Append **one row per completed sub-agent**; never batch-merge without per-skill rows.
- `SKIP` = blocked (missing file, permission, duplicate handled elsewhere—explain).
- `FAIL` = sub-agent reported failure after retries—do not mark `DONE`.

---

## Phase 2 — Per-skill sub-agent prompt (copy for each spawn)

Send the following to **each** dedicated sub-agent, substituting `{{SKILL_PATH}}` with a single repo-relative path from the queue.

````markdown
## Your task (single skill only)

You are the **only** editor for this invocation. Work on exactly one file tree:

- **Primary:** `{{SKILL_PATH}}`
- **Allowed edits:** `SKILL.md` in that directory, and files under `references/` **only if** the improvement requires it (prefer keeping changes in `SKILL.md`).

Do **not** edit other skills, commands, or unrelated plugins in this run.

### 1) Read

- Read `{{SKILL_PATH}}` in full.
- If the skill imports patterns from `references/`, read only what you need.

### 2) Decide: gates vs noise

Apply improvements **only** where they reduce **honor-system** steps for tasks that are **evidence-bound** or **destructive** if wrong:

- **High value:** verification-heavy flows (reviews, research, security claims), structured outputs (JSON/schemas), destructive or irreversible actions, “report before claim” patterns.
- **Low value:** pure reference / API shape / library recipes where the risk is style, not fabricated evidence—**leave unchanged** unless a single short gate removes a known rationalization.

If there is **no** meaningful upgrade (already explicit, or inappropriate for gates), return `NO_CHANGE` and do not edit.

### 3) If you change content

- Add a **Gates** (or **Hard gates**) subsection, or weave **numbered sequences** with **bold pass conditions**, matching the skill’s existing tone and structure.
- Prefer **checklists agents can answer yes/no with artifacts**: file paths, URLs, tool output, schema validity—not “ensure you verified.”
- Keep edits **minimal**: do not refactor unrelated sections, rename the skill, or expand scope.
- Preserve YAML frontmatter exactly unless a field is wrong (rare); do not remove `description` or `name`.

### 4) Verify your own work (mandatory)

Before returning:

1. Re-read your edited sections (or full file if small).
2. Confirm frontmatter is still valid YAML.
3. Confirm internal links and `references/` paths exist if you cited them.
4. Confirm you did not introduce contradictory instructions with the rest of the skill.

### 5) Return format (strict)

Reply with exactly this structure:

```
SKILL_PATH: {{SKILL_PATH}}
VERDICT: CHANGED | NO_CHANGE
FILES_TOUCHED:
  - list every path edited, or "none"
SUMMARY: <= 280 characters describing gate-related edits, or why NO_CHANGE
RISKS: none | short note on edge cases
VERIFICATION: passed | failed (if failed, explain)
```

If you cannot complete (file missing, ambiguous ownership), set `VERDICT: NO_CHANGE` and explain under `RISKS`, and set `VERIFICATION: failed` with reason.
````

---

## Phase 3 — Orchestrator loop (main session)

Until the queue is exhausted:

1. Pop the next path from `docs/skills-gates-run-queue.txt` that is not `DONE` in the manifest.
2. Spawn a sub-agent with **Phase 2** prompt and that path.
3. On success:
   - If `VERDICT: CHANGED`, optionally run `git diff` on `FILES_TOUCHED` in a **read-only** check sub-agent or shell to ensure scope stayed local.
   - Append manifest row; commit is **optional** per project policy—either **one commit per skill** (atomic) or batch commits by plugin; never leave the repo broken.
4. On failure: retry once with the same prompt plus the failure reason; if still failing, mark `FAIL`, continue or stop per policy.
5. **Checkpoint:** every N skills (e.g. 10), ensure manifest is flushed to disk.

Operational note: shell work in this loop must obey the Command safety gate. In particular, keep read-only checks small and deterministic, and isolate any build/test/sanity phase from routine manifest or queue maintenance.

**Stopping condition:** every path in the queue has a terminal manifest row (`DONE` or `SKIP` or `FAIL`). For a **completely functional** tree, aim for zero `FAIL`; resolve `FAIL` items before declaring completion.

---

## Duplicate and mirrored skills

Some content is **duplicated across plugins** (e.g. shared review protocols). Policy (pick one and stick to it):

- **Independent:** Each duplicate gets its own sub-agent run; accept small wording drift, or
- **Canonical copy:** Process the canonical path first; other runs only align if manifest notes “mirror of X.”

Document the chosen policy at the top of `docs/skills-gates-run-manifest.md` before the table.

---

## Definition of done

- [ ] `docs/skills-gates-run-queue.txt` lists all `**/skills/*/SKILL.md` paths.
- [ ] `docs/skills-gates-run-manifest.md` has one row per path with terminal status.
- [ ] Every `CHANGED` skill has `VERIFICATION: passed` from its sub-agent and a sane diff scope.
- [ ] No `FAIL` rows remain **or** each `FAIL` has a documented follow-up owner.
- [ ] Repository builds / tests still pass if your project requires a global check after bulk doc edits (run separately—**orchestrator** may spawn a final “sanity” sub-agent).

---

## Session starter (paste into new chat)

```text
You are the orchestrator for the skills “rules → gates” batch. Goal: process each SKILL.md path from docs/skills-gates-run-queue.txt (full inventory per Phase 0: git ls-files '**/skills/*/SKILL.md' | sort) with one sub-agent per skill, apply gate-style improvements only where they help, and keep the tree consistent.

Before doing anything: read docs/SKILLS_GATES_SUBAGENT_ORCHESTRATION.md in full. Then open docs/skills-gates-run-queue.txt and docs/skills-gates-run-manifest.md if they exist—resume from the first queue path not in a terminal manifest state (DONE / SKIP / FAIL) instead of rebuilding from scratch unless the manifest is missing or clearly invalid.

Execute the doc’s phases in order: Phase 0 inventory (stable queue file), Phase 1 manifest setup (include duplicate/mirror policy at top of manifest per the doc), Phase 2 loop (spawn one sub-agent per skill using the Phase 2 prompt template with {{SKILL_PATH}} substituted—do not edit SKILL.md yourself except allowed orchestration metadata), Phase 3 until the queue is exhausted. Obey the Command safety gate: only parallelize commands that are clearly fast probes, and isolate any long-running or unknown-cost shell command as its own named phase with progress updates.

As orchestrator: maintain the queue and manifest, ingest structured sub-agent reports, optionally run read-only git diff on reported FILES_TOUCHED after CHANGED, retry a failed spawn once with the failure reason, and checkpoint the manifest periodically. Do not edit skill content directly to “save time.”

Verification: satisfy the Definition of done in the doc (queue completeness, one manifest row per path, no unexplained FAIL, and sub-agent VERIFICATION: passed for changes). If the project requires a global check after bulk documentation edits, run tests or the agreed CI-equivalent once near the end (orchestrator may use a final sanity pass).

Stop only when every queued path has a terminal manifest row and follow-ups are owned for any remaining FAIL.
```

---

*Generated for batch application of [Rules and Gates](https://blog.fsck.com/2026/04/07/rules-and-gates/) style improvements across Beagle plugin skills.*
