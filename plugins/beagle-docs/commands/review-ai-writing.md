---
description: Detect AI-generated writing patterns in docs, docstrings, commits, PR descriptions, and code comments
---

# Review AI Writing

Detect AI-generated writing patterns across developer text artifacts using parallel subagents.

## Usage

```
/beagle-docs:review-ai-writing [--all] [--category <name>] [path]
```

**Flags:**
- `--all` - Scan entire codebase (default: changed files from main)
- `--category <name>` - Only check specific category: `content|vocabulary|formatting|communication|filler|code_docs`
- Path: Target directory (default: current working directory)

## Instructions

### 1. Parse Arguments

Extract flags from `$ARGUMENTS`:
- `--all` - Full codebase scan
- `--category <name>` - Filter to specific category
- Path - Target directory

### 2. Load Skills

Load required skills:

```
Skill(skill: "beagle-docs:review-ai-writing")
Skill(skill: "beagle-core:review-verification-protocol")
```

### 3. Determine Scope

```bash
# Default: changed files from main
git diff --name-only $(git merge-base HEAD main)..HEAD

# If --all flag: scan all text artifacts
find . -type f \( -name "*.md" -o -name "*.py" -o -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.go" -o -name "*.rs" -o -name "*.java" -o -name "*.rb" -o -name "*.swift" -o -name "*.kt" -o -name "*.ex" -o -name "*.exs" \) ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/vendor/*" ! -path "*/__pycache__/*" ! -path "*/dist/*" ! -path "*/build/*"
```

If no files found, exit with: "No files to scan. Check your branch has changes or use --all."

### 4. Check for Existing LLM Artifacts Review

```bash
# Check if llm-artifacts review exists to avoid double-flagging
if [ -f .beagle/llm-artifacts-review.json ]; then
  echo "Found existing llm-artifacts review — will skip overlapping findings"
fi
```

Parse existing findings from `.beagle/llm-artifacts-review.json` if present. When consolidating, skip any finding where both the file:line and pattern type match an existing llm-artifacts finding (specifically `verbose_comment` and `over_documentation` types).

### 5. Classify Files by Type

Partition files into three groups:

| Group | File Types | Patterns to Check |
|-------|-----------|-------------------|
| **Prose** | `*.md` | All 6 categories |
| **Code Docs** | `*.py`, `*.ts`, `*.tsx`, `*.js`, `*.jsx`, `*.go`, `*.rs`, `*.java`, `*.rb`, `*.swift`, `*.kt`, `*.ex`, `*.exs` | vocabulary, communication, filler, code_docs |
| **Git** | Commit messages, PR descriptions | content, vocabulary, communication, filler |

For Git artifacts, collect recent commits:

```bash
# Commits on current branch not in main
git log --format="%H %s" $(git merge-base HEAD main)..HEAD
```

### 6. Spawn Parallel Subagents

If total items >= 4, spawn up to 3 subagents via `Task` tool. If `--category` is set, spawn a single agent for that category only.

#### Subagent 1: Prose Agent

**Scope:** Markdown files only
**Check:** All 6 pattern categories
**Instructions:**
1. Load `beagle-docs:review-ai-writing` skill
2. Read each markdown file
3. Scan for all pattern categories
4. Apply false positive checks from the skill
5. Return findings in the structured format

#### Subagent 2: Code Docs Agent

**Scope:** Source code files
**Check:** vocabulary, communication, filler, code_docs categories
**Instructions:**
1. Load `beagle-docs:review-ai-writing` skill
2. Extract docstrings and comments from each file
3. Scan for applicable pattern categories
4. Skip code itself — only check text in comments and docstrings
5. Return findings in the structured format

#### Subagent 3: Git Agent

**Scope:** Commit messages and PR descriptions
**Check:** content, vocabulary, communication, filler categories
**Instructions:**
1. Load `beagle-docs:review-ai-writing` skill
2. Read commit messages from the branch
3. If on a PR branch, read the PR description via `gh pr view --json body`
4. Scan for applicable pattern categories
5. Use synthetic paths: `git:commit:<sha>` with line 0, `git:pr:<number>` with line 0
6. Return findings in the structured format

### 7. Consolidate Findings

Wait for all subagents to complete, then:

1. Merge all findings into a single list
2. Remove duplicates (same file:line and type)
3. Remove findings that overlap with `.beagle/llm-artifacts-review.json`
4. Assign unique IDs (1, 2, 3...)
5. Group by category for display

### 8. Write JSON Report

Create `.beagle` directory if it doesn't exist:

```bash
mkdir -p .beagle
```

Write findings to `.beagle/ai-writing-review.json`:

```json
{
  "version": "1.0.0",
  "created_at": "2025-01-15T10:30:00Z",
  "git_head": "abc1234",
  "scope": "changed",
  "files_scanned": 12,
  "commits_scanned": 5,
  "findings": [
    {
      "id": 1,
      "category": "vocabulary",
      "type": "ai_vocabulary_high",
      "file": "README.md",
      "line": 15,
      "original_text": "This library leverages cutting-edge algorithms to facilitate seamless data processing.",
      "description": "High-signal AI vocabulary: leverage, cutting-edge, facilitate, seamless",
      "suggestion": "This library uses streaming algorithms for fast data processing.",
      "risk": "Low",
      "fix_safety": "Safe",
      "fix_action": "rewrite"
    },
    {
      "id": 2,
      "category": "code_docs",
      "type": "tautological_docstring",
      "file": "src/auth.py",
      "line": 42,
      "original_text": "\"\"\"Get the user by ID.\"\"\"",
      "description": "Docstring restates function name get_user_by_id without adding value",
      "suggestion": "\"\"\"Raises UserNotFound if ID doesn't exist.\"\"\"",
      "risk": "Medium",
      "fix_safety": "Needs review",
      "fix_action": "rewrite"
    },
    {
      "id": 3,
      "category": "communication",
      "type": "chat_leak",
      "file": "git:commit:abc1234",
      "line": 0,
      "original_text": "Certainly! Here's the updated authentication flow",
      "description": "Chat leak in commit message: starts with 'Certainly! Here's'",
      "suggestion": "Update authentication flow",
      "risk": "Low",
      "fix_safety": "Safe",
      "fix_action": "rewrite"
    }
  ],
  "summary": {
    "total": 3,
    "by_category": {
      "vocabulary": 1,
      "code_docs": 1,
      "communication": 1
    },
    "by_risk": {
      "Low": 2,
      "Medium": 1
    },
    "by_fix_safety": {
      "Safe": 2,
      "Needs review": 1
    }
  }
}
```

### 9. Display Summary

```markdown
## AI Writing Review

**Scope:** Changed files from main
**Files scanned:** 12 | **Commits scanned:** 5

### Findings by Category

#### Vocabulary (1 issue)

1. [README.md:15] **AI vocabulary** (Low, Safe)
   - High-signal AI vocabulary: leverage, cutting-edge, facilitate, seamless
   - Suggestion: Rewrite with simple words

#### Code Docs (1 issue)

2. [src/auth.py:42] **Tautological docstring** (Medium, Needs review)
   - Docstring restates function name without adding value
   - Suggestion: Add meaningful information or delete

#### Communication (1 issue)

3. [git:commit:abc1234:0] **Chat leak** (Low, Safe)
   - Commit message starts with "Certainly! Here's"
   - Suggestion: Rewrite as imperative commit message

### Summary Table

| Category | Safe | Needs Review | Total |
|----------|------|--------------|-------|
| Vocabulary | 1 | 0 | 1 |
| Code Docs | 0 | 1 | 1 |
| Communication | 1 | 0 | 1 |
| **Total** | **2** | **1** | **3** |

### Next Steps

- Run `/beagle-docs:humanize` to apply fixes
- Run `/beagle-docs:humanize --dry-run` to preview changes first
- Review the JSON report at `.beagle/ai-writing-review.json`
```

### 10. Verification

Before completing, verify:

1. **JSON validity:** Confirm `.beagle/ai-writing-review.json` exists and is parseable
2. **Subagent success:** All spawned subagents completed without errors
3. **Git HEAD captured:** The `git_head` field is non-empty
4. **No double-flagging:** Cross-check against `.beagle/llm-artifacts-review.json` if it exists

```bash
# Verify JSON is valid
python3 -c "import json; json.load(open('.beagle/ai-writing-review.json'))" 2>/dev/null && echo "Valid JSON" || echo "Invalid JSON"
```

If any verification fails, report the error and do not proceed.

## Output Format for Each Finding

```text
[FILE:LINE] **ISSUE_TYPE** (Risk, Fix Safety)
- Description
- Suggestion: Specific fix recommendation
```

## Rules

- Always load `beagle-docs:review-ai-writing` and `beagle-core:review-verification-protocol` first
- Use `Task` tool for parallel subagents when >= 4 items to scan
- Every finding MUST have file:line reference (use synthetic paths for git artifacts)
- Do not flag false positives listed in the skill
- Do not duplicate findings from `.beagle/llm-artifacts-review.json`
- Create `.beagle` directory if needed
- Write JSON report before displaying summary
