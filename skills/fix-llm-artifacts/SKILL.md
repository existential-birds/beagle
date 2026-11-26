---
name: fix-llm-artifacts
description: Applies fixes from a prior review-llm-artifacts run with safe/risky classification, honoring verify-llm-artifacts output when present to skip false positives. Use when cleaning up reviewed LLM coding artifacts.
---

# Fix LLM Artifacts

Apply fixes from a previous [review-llm-artifacts](../review-llm-artifacts/SKILL.md) run with automatic safe/risky classification. If `.beagle/llm-artifacts-verification.json` exists, **skip** findings marked `false_positive` and treat `inconclusive` like risky fixes (prompt or skip per user).

## Usage

Invoke the **fix-llm-artifacts** skill, optionally passing these flags:

```text
fix-llm-artifacts [--dry-run] [--all] [--category <name>]
```

**Flags:**
- `--dry-run` - Show what would be fixed without changing files
- `--all` - Fix entire codebase (runs `review-llm-artifacts --all` first if no review JSON)
- `--category <name>` - Only fix specific category: `tests|dead_code|abstraction|style` (also accepts `dead-code`; `-` and `_` are normalized when matching JSON `category`)

## Instructions

### Hard gates

Sequence matters. Do not apply fixes until each **pass condition** is satisfied (these steps are not "internal verification").

1. **Working tree** — `git status --porcelain` is empty **or** a stash was created with message `pre-fix-llm-artifacts backup` and `git stash list` shows it. If the user refuses stash/backup, **stop** or document explicit acceptance of risk in the report before edits.
2. **Review artifact on disk** — `.beagle/llm-artifacts-review.json` exists, **or** `--all` completed a `review-llm-artifacts` run that wrote that file. Otherwise **stop** (no fixes from memory or guesses).
2a. **Echo + ID lock (anti-confabulation)** — After loading the review (Section 3), echo the finding table (`id | category | file:line | description`) from the **parsed JSON** and record the exact id set as the **locked id set**. You fix only findings in this set; never fix a finding inferred from the branch name, directory, or memory. Every fix you apply or skip maps 1:1 to a locked id. See the [review-verification-protocol](../review-verification-protocol/SKILL.md) skill → Anti-confabulation (gate 0).
2b. **Per-fix existence precondition** — Before editing for any finding, confirm (i) its `id` is in the locked set, and (ii) the cited `file` exists and the cited code is actually present at `file:line` (read it now). If the file or code is absent, **do not edit** — the finding is stale or confabulated; mark it skipped with a reason and move on. Never create or rewrite a file to match a finding.
3. **Stale review** — If `jq -r '.git_head' .beagle/llm-artifacts-review.json` does not match `git rev-parse HEAD` (prefix match accepted only for legacy short SHAs with `len(stored_head) >= 7`), prompt to re-run review. **`y`** → re-run review, then continue. **`n`** → **abort** the fix pass (do not apply fixes against stale findings).
4. **Verification overlay** — If `.beagle/llm-artifacts-verification.json` exists, it must **parse**; build exclude/inconclusive sets **before** partitioning (Section 4). On parse failure, **stop** and report the error.
5. **Risky fixes** — No `code_removal`, `logic_change`, `mock_boundary`, `abstraction_change`, or `test_refactor` work without the interactive choice in Section 6 (or `s` to skip all remaining risky items).

**Post-edit:** Sections 7–8 **pass** only when invoked tools exit successfully (non-zero = failure; keep JSON artifacts per Cleanup).

### 1. Parse Arguments

Accept optional flags (`--dry-run`, `--all`, `--category <name>`):
- `--dry-run` - Preview mode only
- `--all` - Full codebase scan
- `--category <name>` - Filter to specific category (normalize `-` to `_`, e.g., `dead-code` → `dead_code`, to match `review-llm-artifacts` JSON `category` values: `tests`, `dead_code`, `abstraction`, `style`)

### 2. Pre-flight Safety Checks

```bash
# Check for uncommitted changes
git status --porcelain
```

If working directory is dirty, warn:
```text
Warning: You have uncommitted changes. Creating a git stash before proceeding.
Run `git stash pop` to restore if needed.
```

Create stash if dirty:
```bash
git stash push -m "pre-fix-llm-artifacts backup"
```

### 3. Load Review Results

Check for existing review file:
```bash
cat .beagle/llm-artifacts-review.json 2>/dev/null
```

**If file missing:**
- If `--all` flag: Run `review-llm-artifacts --all` first to produce a full-project review
- Otherwise: Fail with: "No review results found. Run the review-llm-artifacts skill first."

**Echo + lock ids (gate 2a):** Once the file is present, print every finding from the parsed JSON and lock the id set before partitioning:

```bash
python3 - <<'PY'
import json
r = json.load(open('.beagle/llm-artifacts-review.json'))
f = r['findings']
if not isinstance(f, list) or not f:
    raise SystemExit("No findings to lock; aborting.")
ids = [x.get('id') for x in f]
if any(not isinstance(i, int) for i in ids):
    raise SystemExit("All finding ids must be integers; aborting.")
if len(set(ids)) != len(ids):
    raise SystemExit("Duplicate finding ids detected; aborting.")
print("| id | category | file:line | description |")
print("|----|----------|-----------|-------------|")
for x in f:
    desc = (x.get('description') or '').replace('|', '\\|')[:80]
    print(f"| {x['id']} | {x.get('category')} | {x.get('file')}:{x.get('line')} | {desc} |")
print("Locked ids: {" + ", ".join(str(i) for i in sorted(set(ids))) + "}")
PY
```

Adjudicate and fix only the ids above. If your sense of what to fix differs from this table, the table wins.

**Optional verification overlay** — if `.beagle/llm-artifacts-verification.json` exists:
- Build a set of finding ids with `status: false_positive` → **exclude** these from all fix lists.
- Finding ids with `status: inconclusive` → **always** follow risky-fix handling (Section 6), even if `fix_safety` was `Safe` in the review.
- Finding ids with `status: confirmed_issue` → use review JSON `fix_safety` / `risk` as usual.

If verification is missing, warn when applying deletes or `dead_code` (`--category dead-code`) fixes: "For fewer false positives, run the [verify-llm-artifacts](../verify-llm-artifacts/SKILL.md) skill first."

**If file exists, validate freshness:**
```bash
# Get stored git HEAD, scope, and target from JSON (expects full 40-char SHA from git rev-parse HEAD)
stored_head=$(jq -r '.git_head // ""'   .beagle/llm-artifacts-review.json)
stored_scope=$(jq -r '.scope // "all"'  .beagle/llm-artifacts-review.json)
stored_target=$(jq -r '.target // "."'  .beagle/llm-artifacts-review.json)
current_head=$(git rev-parse HEAD)

if [ "$stored_head" != "$current_head" ] && { [ "${#stored_head}" -lt 7 ] || [[ "$current_head" != "$stored_head"* ]]; }; then
  echo "Warning: Review was run at commit $stored_head, but HEAD is now $current_head"
fi
```

If stale, prompt: "Review results are stale. Re-run review? (y/n)".
- **`y`** → **re-run `review-llm-artifacts` with the original scope and target** read from the stale JSON, then reload. This preserves the user's original intent; do **not** silently widen or narrow the scope, which would apply fixes unrelated to the user's diff (or miss files they cared about). Concretely:
  - `scope == "changed"` → invoke `review-llm-artifacts "$stored_target"` (default scope is already changed-files).
  - `scope == "all"`     → invoke `review-llm-artifacts --all "$stored_target"`.
  - If `scope` or `target` is missing from the JSON (pre-schema review), **do not abort.** Assume `scope = "all"` and `target = "."`, then warn:
    > "Review JSON predates the scope/target schema; re-running as a full-project scan (`--all`). If you meant a narrower scope (the default changed-files diff, or a subdirectory), cancel now and re-run the review-llm-artifacts skill explicitly."
    Proceed only if the user does not cancel.
- **`n`** → **abort** (do not apply fixes; stale findings are not trustworthy).

### 4. Partition Findings by Safety

Parse findings from JSON and classify by `fix_safety` field (after applying verification overlay from step 3):

**Safe Fixes** (auto-apply):
- `unused_import` - Unused imports
- `todo_comment` - Stale TODO/FIXME comments
- `dead_code_obvious` - Obviously unreachable code
- `verbose_comment` - Overly verbose LLM-style comments
- `redundant_type` - Redundant type annotations

**Risky Fixes** (require confirmation):
- `test_refactor` - Test structure changes
- `abstraction_change` - Class/function extraction
- `code_removal` - Removing functional code
- `mock_boundary` - Test mock scope changes
- `logic_change` - Any behavioral modifications

### 5. Apply Safe Fixes

If `--dry-run`:
```markdown
## Safe Fixes (would apply automatically)

| File | Line | Type | Description |
|------|------|------|-------------|
| src/api.py | 15 | unused_import | Remove `from typing import List` |
| src/models.py | 42 | verbose_comment | Remove 23-line docstring |
...
```

Otherwise, apply the safe fixes per category. **If the agent supports subagents**, dispatch one per category in parallel; **otherwise** work through the categories sequentially yourself, applying the identical per-finding contract below and producing the same per-fix report.

```text
Apply safe fixes for category "{category}"
Files: [list of files with findings in this category]
Instructions: For EACH finding, first confirm it is in the locked id set and that the
cited code exists at file:line (read it). If the file or code is absent, skip the finding
with a reason — do NOT create or rewrite a file to match the finding. Then apply each
confirmed fix, preserving surrounding code. Report success/failure/skip per fix by id.
```

Categories (parallelized across subagents when supported, otherwise handled sequentially; normalize CLI `--category` `-` to `_` when matching JSON `category`):
- `style` - Comments, formatting
- `dead_code` (CLI alias: `dead-code`) - Imports, unreachable code
- `tests` - Test-related safe fixes
- `abstraction` - Safe refactors

### 6. Handle Risky Fixes

For each risky fix, prompt interactively:

```text
[src/services/auth.py:156] Remove seemingly unused authenticate_legacy() method?
This method has no callers in the codebase but may be used externally.
(y)es / (n)o / (s)kip all risky:
```

Track user choices:
- `y` - Apply this fix
- `n` - Skip this fix
- `s` - Skip all remaining risky fixes

### 7. Post-Fix Verification

Detect project type and run appropriate linters:

**Python:**
```bash
# Check if ruff config exists
if [ -f "pyproject.toml" ] || [ -f "ruff.toml" ]; then
    ruff check --fix .
    ruff format .
fi

# Check if mypy config exists
if [ -f "pyproject.toml" ] || [ -f "mypy.ini" ]; then
    mypy .
fi
```

**TypeScript/JavaScript:**
```bash
# Check for eslint (flat config or legacy config)
if [ -f "eslint.config.js" ] || [ -f "eslint.config.mjs" ] || [ -f "eslint.config.cjs" ] || [ -f "eslint.config.ts" ] || [ -f ".eslintrc.json" ] || [ -f ".eslintrc.js" ] || [ -f ".eslintrc.cjs" ]; then
    npx eslint --fix .
fi

# Check for TypeScript
if [ -f "tsconfig.json" ]; then
    npx tsc --noEmit
fi
```

**Go:**
```bash
if [ -f "go.mod" ]; then
    go vet ./...
    go build ./...
fi
```

### 8. Run Tests

```bash
# Python
if [ -f "pyproject.toml" ] || [ -f "pytest.ini" ]; then
    pytest
fi

# JavaScript/TypeScript
if [ -f "package.json" ]; then
    npm test 2>/dev/null || yarn test 2>/dev/null || true
fi

# Go
if [ -f "go.mod" ]; then
    go test ./...
fi
```

### 9. Report Results

```markdown
## Fix Summary

### Applied Fixes
- [x] src/api.py:15 - Removed unused import `List`
- [x] src/models.py:42-64 - Removed verbose docstring
- [x] src/auth.py:156-189 - Removed dead method (user confirmed)

### Skipped Fixes
- [ ] src/services/cache.py:23 - User declined risky fix
- [ ] tests/test_api.py:45 - Test refactor skipped

### Verification Results
- Linter: PASSED
- Type check: PASSED
- Tests: PASSED (42 passed, 0 failed)

### Diff Summary
```bash
git diff --stat
```

## Cleanup

On successful completion (all verifications pass):
```bash
rm -f .beagle/llm-artifacts-review.json .beagle/llm-artifacts-verification.json
```

If any verification fails, keep the files and report:
```text
Review file preserved at .beagle/llm-artifacts-review.json
Fix issues and re-run, or restore with: git stash pop
```

## Example

```text
# Preview all fixes without applying
fix-llm-artifacts --dry-run

# Fix only dead code issues (accepts dead-code or dead_code)
fix-llm-artifacts --category dead-code

# Full codebase scan and fix
fix-llm-artifacts --all

# Fix style issues only, preview first
fix-llm-artifacts --category style --dry-run
```
