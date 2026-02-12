---
description: Apply fixes from a prior review-ai-writing run to humanize AI-generated developer text
---

# Humanize

Apply fixes from a previous `review-ai-writing` run with automatic safe/risky classification.

## Usage

```text
/beagle-docs:humanize [--dry-run] [--all] [--category <name>]
```

**Flags:**
- `--dry-run` - Show what would be fixed without changing files
- `--all` - Fix entire codebase (runs review with --all first)
- `--category <name>` - Only fix specific category: `content|vocabulary|formatting|communication|filler|code_docs`

## Instructions

### 1. Parse Arguments

Extract flags from `$ARGUMENTS`:
- `--dry-run` - Preview mode only
- `--all` - Full codebase scan
- `--category <name>` - Filter to specific category

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
git stash push -u -m "beagle-docs: pre-humanize backup"
```

### 3. Load Review Results

Check for existing review file:
```bash
cat .beagle/ai-writing-review.json 2>/dev/null
```

**If file missing:**
- If `--all` flag: Run `/beagle-docs:review-ai-writing --all` first
- Otherwise: Fail with: "No review results found. Run `/beagle-docs:review-ai-writing` first."

**If file exists, validate freshness:**
```bash
# Get stored git HEAD from JSON
stored_head=$(jq -r '.git_head' .beagle/ai-writing-review.json)
current_head=$(git rev-parse HEAD)

if [ "$stored_head" != "$current_head" ]; then
  echo "Warning: Review was run at commit $stored_head, but HEAD is now $current_head"
fi
```

If stale, prompt: "Review results are stale. Re-run review? (y/n)"

### 4. Load Skills

```text
Skill(skill: "beagle-docs:humanize")
```

### 5. Filter Findings

If `--category` is set, filter findings to that category only.

Partition remaining findings by `fix_safety`:

**Safe Fixes** (auto-apply):
- `chat_leak` - Delete conversational artifacts
- `cutoff_disclaimer` - Delete knowledge cutoff references
- `filler_phrase` - Delete filler phrases
- `heading_restatement` - Delete restating first sentence
- `emoji_decoration` - Remove emoji from technical text
- `boldface_overuse` - Remove excessive bold formatting
- `ai_vocabulary_high` - Swap high-signal AI words
- `narrating_obvious` - Delete obvious code comments
- `synthetic_opener` - Delete "In today's..." openers
- `sycophantic_tone` - Delete or neutralize praise
- `vague_authority` - Delete unattributed claims
- `excessive_hedging` - Remove qualifiers
- `generic_conclusion` - Delete summary padding
- `copula_avoidance` - Use "is/are" naturally
- `rhetorical_device` - Delete rhetorical questions

**Needs Review Fixes** (require confirmation):
- `promotional_language` - Rewrite with specifics
- `formulaic_structure` - Restructure sections
- `synonym_cycling` - Pick consistent term
- `commit_inflation` - Rewrite commit scope
- `tautological_docstring` - Rewrite or delete docstring
- `exhaustive_enumeration` - Trim parameter docs
- `this_noun_verbs` - Rewrite docstring voice
- `ai_vocabulary_low` - Reduce cluster density
- `apologetic_error` - Rewrite error message

### 6. Apply Safe Fixes

If `--dry-run`:
```markdown
## Safe Fixes (would apply automatically)

| # | File | Line | Type | Action |
|---|------|------|------|--------|
| 1 | README.md | 3 | synthetic_opener | Delete "In today's rapidly evolving..." |
| 2 | src/auth.py | 15 | narrating_obvious | Delete "# Check if user exists" |
| 3 | README.md | 42 | ai_vocabulary_high | Replace "utilize" with "use" |
...
```

Otherwise, apply fixes grouped by file to minimize file I/O:

1. Sort findings by file, then by line number (descending, to avoid offset drift)
2. For each file, apply all safe fixes in reverse line order
3. For git artifacts (`git:commit:*`, `git:pr:*`), skip — these can't be auto-fixed. Report them for manual attention.

### 7. Handle Needs Review Fixes

If `--dry-run`, list them:
```markdown
## Needs Review Fixes (would prompt interactively)

| # | File | Line | Type | Original | Suggested |
|---|------|------|------|----------|-----------|
| 4 | README.md | 8 | promotional_language | "powerful, enterprise-grade solution" | "authentication library" |
...
```

Otherwise, for each fix, prompt interactively:

```text
[README.md:8] Promotional language: "powerful, enterprise-grade solution"
Suggested: "authentication library"
(y)es / (n)o / (e)dit / (s)kip all:
```

Track user choices:
- `y` - Apply this fix as suggested
- `n` - Skip this fix
- `e` - User provides custom replacement
- `s` - Skip all remaining interactive fixes

### 8. Validate Results

For each modified markdown file, verify basic validity:

```bash
# Check for broken markdown (unclosed code blocks, broken links)
# Simple check: matching ``` pairs
grep -c '```' "$file" | awk '{print ($1 % 2 == 0) ? "OK" : "WARNING: odd number of code fences"}'
```

For modified source files, check syntax is still valid:

**Python:**
```bash
python3 -c "import ast; ast.parse(open('$file').read())"
```

**TypeScript/JavaScript:**
```bash
npx -y acorn --ecma2020 "$file" > /dev/null 2>&1
```

If validation fails for any file, revert that file:
```bash
git checkout -- "$file"
echo "Reverted $file due to validation failure"
```

### 9. Report Results

~~~markdown
## Humanize Summary

### Applied Fixes
- [x] README.md:3 - Deleted synthetic opener
- [x] README.md:42 - Replaced "utilize" with "use"
- [x] src/auth.py:15 - Deleted obvious comment

### Interactive Fixes
- [x] README.md:8 - Rewrote promotional language (user approved)
- [ ] docs/guide.md:22 - Skipped by user

### Skipped (Git Artifacts)
- [ ] git:commit:abc1234 - Chat leak in commit message (amend manually)

### Validation
- README.md: OK
- src/auth.py: OK

### Diff Summary
```bash
git diff --stat
```
~~~

### 10. Cleanup

On successful completion (all validations pass):
```bash
rm .beagle/ai-writing-review.json
```

If any validation fails, keep the file and report:
```text
Review file preserved at .beagle/ai-writing-review.json
Fix issues and re-run, or restore with: git stash pop
```

## Example

```bash
# Preview all fixes without applying
/beagle-docs:humanize --dry-run

# Fix only vocabulary issues
/beagle-docs:humanize --category vocabulary

# Full codebase scan and fix
/beagle-docs:humanize --all

# Preview filler fixes only
/beagle-docs:humanize --category filler --dry-run
```

## Rules

- Always load `beagle-docs:humanize` skill first
- Never modify files without a stash or clean working directory
- Apply safe fixes in reverse line order to avoid offset drift
- Never auto-fix git artifacts (commits, PRs) — report them for manual action
- Validate every modified file before considering it done
- Revert files that fail validation
- Write JSON report before displaying summary
- Clean up JSON report only on full success
