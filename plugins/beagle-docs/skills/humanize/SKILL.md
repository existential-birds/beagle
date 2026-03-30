---
name: humanize
description: Rewrite AI-generated developer text to sound human — fix inflated language, filler, tautological docs, and robotic tone. Use after review-ai-writing identifies issues.
disable-model-invocation: true
dependencies:
  - docs-style
  - review-ai-writing
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

```markdown
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
```

```bash
git diff --stat
```

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

## Reference Material

## Humanize Developer Text

Fix AI-generated writing patterns in docs, docstrings, commit messages, PR descriptions, and code comments. Prioritize deletion over rewriting — the best fix for filler is removal.

## Core Principles

1. **Delete first, rewrite second.** Most AI patterns are padding. Removing them improves the text.
2. **Use simple words.** Replace "utilize" with "use", "facilitate" with "help", "implement" with "add".
3. **Keep sentences short.** Break compound sentences. One idea per sentence.
4. **Preserve meaning.** Never change what the text says, only how it says it.
5. **Match the register.** Commit messages are terse. READMEs are conversational. API docs are precise.
6. **Don't overcorrect.** A slightly formal sentence is fine. Only fix patterns that read as obviously AI-generated.

## Fix Strategies by Category

### Content Patterns

| Type | Strategy | Risk |
|------|----------|------|
| Promotional language | Replace superlatives with specifics | Needs review |
| Vague authority | Delete the claim or add a citation | Safe |
| Formulaic structure | Remove the intro/conclusion wrapper | Needs review |
| Synthetic openers | Delete the opener, start with the point | Safe |

**Before:**
```markdown
In today's rapidly evolving software landscape, authentication is a crucial
component that plays a pivotal role in securing modern applications.
```

**After:**
```markdown
This guide covers authentication setup for the API.
```

### Vocabulary Patterns

| Type | Strategy | Risk |
|------|----------|------|
| High-signal AI words | Direct word swap | Safe |
| Low-signal clusters | Reduce density, keep 1-2 | Needs review |
| Copula avoidance | Use "is/are" naturally | Safe |
| Rhetorical devices | Delete the question, state the fact | Safe |
| Synonym cycling | Pick one term, use it consistently | Needs review |
| Commit inflation | Rewrite to match actual change scope | Needs review |

**Word swap reference:**

| AI Word | Replacement |
|---------|-------------|
| utilize | use |
| leverage (as "use") | use |
| delve | look at, explore, examine |
| facilitate | help, enable, let |
| endeavor | try, work, effort |
| harnessing | using |
| paradigm | approach, model, pattern |
| whilst | while |
| furthermore | also, and |
| moreover | also, and |
| robust (non-technical) | reliable, solid, strong |
| seamless | smooth, easy |
| cutting-edge | modern, latest, new |
| pivotal | important, key |
| elevate | improve |
| empower | let, enable |
| revolutionize | change, improve |
| unleash | release, enable |
| synergy | (delete — rarely means anything) |
| embark | start, begin |

**Before:**
```text
feat: Leverage robust caching paradigm to facilitate seamless data retrieval
```

**After:**
```text
feat: add response caching for faster reads
```

### Formatting Patterns

| Type | Strategy | Risk |
|------|----------|------|
| Boldface overuse | Remove bold from non-key terms | Safe |
| Emoji decoration | Remove emoji from technical content | Safe |
| Heading restatement | Delete the restating sentence | Safe |

**Before:**
```markdown
## Error Handling

**Error handling** is a **critical** aspect of building **reliable** applications.
The `handleError` function **catches** and **processes** all **runtime errors**.
```

**After:**
```markdown
## Error Handling

The `handleError` function catches runtime errors and logs them with context.
```

### Communication Patterns

| Type | Strategy | Risk |
|------|----------|------|
| Chat leaks | Delete entirely | Safe |
| Cutoff disclaimers | Delete entirely | Safe |
| Sycophantic tone | Delete or neutralize | Safe |
| Apologetic errors | Rewrite as direct error message | Needs review |

**Before:**
```python
# Great implementation! This elegantly handles the edge case.
# As of my last update, this API endpoint supports JSON.
```

**After:**
```python
# Handles the re-entrant edge case from issue #42.
# This endpoint accepts JSON.
```

### Filler Patterns

| Type | Strategy | Risk |
|------|----------|------|
| Filler phrases | Delete the phrase | Safe |
| Excessive hedging | Remove qualifiers, state directly | Safe |
| Generic conclusions | Delete the conclusion paragraph | Safe |

**Before:**
```markdown
It's worth noting that the configuration file might potentially need to be
updated. Going forward, this could possibly affect performance.
```

**After:**
```markdown
Update the configuration file. This affects performance.
```

### Code Docs Patterns

| Type | Strategy | Risk |
|------|----------|------|
| Tautological docstrings | Delete or add real information | Needs review |
| Narrating obvious code | Delete the comment | Safe |
| "This noun verbs" | Rewrite in active/direct voice | Safe |
| Exhaustive enumeration | Keep only non-obvious params | Needs review |

**Before:**
```python
def get_user(user_id: int) -> User:
    """Get a user.

    This method retrieves a user from the database by their ID.

    Args:
        user_id: The ID of the user to get.

    Returns:
        User: The user object.

    Raises:
        ValueError: If the user ID is invalid.
    """
    return db.query(User).get(user_id)
```

**After:**
```python
def get_user(user_id: int) -> User:
    """Raises UserNotFound if ID doesn't exist in the database."""
    return db.query(User).get(user_id)
```

## Developer Voice Guidelines

Good developer writing is:

- **Conversational but precise.** Write like you'd explain it to a colleague, but get the details right.
- **Direct.** State opinions. "Use X" not "You might consider using X".
- **Terse where appropriate.** Commit messages and code comments should be short. Don't pad them.
- **Specific.** Replace vague claims with concrete details, numbers, or examples.
- **Consistent.** Pick one term and stick with it. Don't cycle synonyms.

### Register Guide

| Artifact | Tone | Length | Example |
|----------|------|--------|---------|
| Commit message | Terse, imperative | 50-72 chars | `fix: prevent nil panic in auth middleware` |
| Code comment | Brief, explains why | 1-2 lines | `// retry once — transient DNS failures are common in k8s` |
| Docstring | Precise, adds value | What the name doesn't tell you | `"""Raises ConnectionError after 3 retries."""` |
| PR description | Structured, factual | Context + what changed + how to test | Bullet points, not paragraphs |
| README | Conversational, scannable | As short as possible | Start with what it does, then how to use it |
| Error message | Actionable, specific | What happened + what to do | `Config file not found at ~/.app/config.yml. Run 'app init' to create one.` |

## Applying Fixes

### Safe Fixes (Auto-Apply)

These are mechanical and can be applied without human review:

- Delete chat leaks ("Certainly!", "Great question!")
- Delete cutoff disclaimers ("As of my last update")
- Delete filler phrases ("It's worth noting that")
- Delete heading restatements
- Remove emoji from technical docs
- Remove excessive bold formatting
- Swap high-signal AI vocabulary (utilize -> use)
- Delete "As we can see" / "Let's take a look at"
- Delete narrating-obvious comments

### Needs Review Fixes (Interactive)

These require a human to verify the replacement preserves intent:

- Rewriting promotional language (may need domain knowledge)
- Fixing synonym cycling (need to pick the right term)
- Rewriting tautological docstrings (need to decide what's actually worth documenting)
- Trimming exhaustive parameter docs (need to decide which params are non-obvious)
- Rewriting commit messages (scope judgment)
- Restructuring formulaic sections (may change document flow)
- Fixing apologetic error messages (wording matters for UX)
