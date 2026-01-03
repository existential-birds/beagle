---
description: Detects common LLM coding agent artifacts by spawning 4 parallel subagents
---

# LLM Artifacts Review

Detect common artifacts left behind by LLM coding agents: over-abstraction, dead code, DRY violations in tests, verbose comments, and defensive overkill.

## Arguments

- `--all`: Scan entire codebase (default: changed files from main)
- `--parallel`: Force parallel execution (default when 4+ files)
- Path: Target directory (default: current working directory)

## Step 1: Determine Scope

Parse `$ARGUMENTS` for flags and path:

```bash
# Default: changed files from main
git diff --name-only $(git merge-base HEAD main)..HEAD | grep -E '\.(py|ts|tsx|js|jsx|go|rs|java|rb|swift|kt)$'

# If --all flag: scan entire codebase
find . -type f \( -name "*.py" -o -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.go" -o -name "*.rs" -o -name "*.java" -o -name "*.rb" -o -name "*.swift" -o -name "*.kt" \) ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/vendor/*" ! -path "*/__pycache__/*"
```

If no files found, exit with: "No files to scan. Check your branch has changes or use --all to scan the entire codebase."

## Step 2: Detect Languages

Extract unique file extensions from the file list:

```bash
# Get unique extensions
echo "$FILES" | sed 's/.*\.//' | sort -u
```

Map extensions to language names for the report:
- `.py` -> Python
- `.ts`, `.tsx` -> TypeScript
- `.js`, `.jsx` -> JavaScript
- `.go` -> Go
- `.rs` -> Rust
- `.java` -> Java
- `.rb` -> Ruby
- `.swift` -> Swift
- `.kt` -> Kotlin

## Step 3: Spawn Parallel Subagents

If file count >= 4 OR `--parallel` flag is set, spawn 4 subagents via `Task` tool.

Each subagent MUST:
1. Load the skill: `Skill(skill: "beagle:llm-artifacts-detection")`
2. Review only its assigned category
3. Return findings in the structured format below

### Subagent 1: Tests Agent

**Focus:** Testing anti-patterns from LLM generation

- DRY violations (repeated setup code, duplicate assertions)
- Testing library/framework code instead of application logic
- Wrong mock boundaries (mocking too much or too little)
- Overly verbose test names that describe implementation
- Tests that just mirror the implementation

### Subagent 2: Dead Code Agent

**Focus:** Unused or obsolete code

- Unused imports, variables, functions, classes
- TODO/FIXME comments that should have been resolved
- Backwards compatibility code for removed features
- Orphaned test files for deleted code
- Commented-out code blocks
- Feature flags that are always on/off

### Subagent 3: Abstraction Agent

**Focus:** Over-engineering patterns

- Unnecessary abstraction layers (interfaces for single implementations)
- Copy-paste drift (similar code that diverged slightly)
- Over-configuration (configurable things that never change)
- Premature generalization
- Factory/Builder patterns for simple object creation
- Deep inheritance hierarchies

### Subagent 4: Style Agent

**Focus:** Verbose or defensive patterns

- Verbose comments explaining obvious code
- Defensive overkill (null checks on non-nullable values)
- Unnecessary type hints (dynamic languages with obvious types)
- Overly explicit error messages
- Redundant logging
- Self-documenting code with documentation

## Step 4: Consolidate Findings

Wait for all subagents to complete, then:

1. Merge all findings into a single list
2. Assign unique IDs (1, 2, 3...)
3. Group by category for display

## Step 5: Write JSON Report

Create `.beagle` directory if it doesn't exist:

```bash
mkdir -p .beagle
```

Write findings to `.beagle/llm-artifacts-review.json`:

```json
{
  "version": "1.0.0",
  "created_at": "2024-01-15T10:30:00Z",
  "git_head": "abc1234",
  "scope": "changed" | "all",
  "files_scanned": 42,
  "languages": ["Python", "TypeScript", "Go"],
  "findings": [
    {
      "id": 1,
      "category": "tests" | "dead_code" | "abstraction" | "style",
      "type": "dry_violation" | "unused_import" | "over_abstraction" | "verbose_comment" | ...,
      "file": "src/utils/helper.py",
      "line": 42,
      "description": "Repeated setup code in 5 test functions",
      "suggestion": "Extract to a pytest fixture",
      "risk": "Low" | "Medium" | "High",
      "fix_safety": "Safe" | "Needs review",
      "fix_action": "refactor" | "delete" | "simplify" | "extract"
    }
  ],
  "summary": {
    "total": 15,
    "by_category": {
      "tests": 4,
      "dead_code": 5,
      "abstraction": 3,
      "style": 3
    },
    "by_risk": {
      "High": 2,
      "Medium": 8,
      "Low": 5
    },
    "by_fix_safety": {
      "Safe": 10,
      "Needs review": 5
    }
  }
}
```

## Step 6: Display Summary

```markdown
## LLM Artifacts Review

**Scope:** Changed files from main | Entire codebase
**Files scanned:** 42
**Languages:** Python, TypeScript, Go

### Findings by Category

#### Tests (4 issues)

1. [src/tests/test_api.py:15] **DRY violation** (Medium, Safe)
   - Repeated setup code in 5 test functions
   - Suggestion: Extract to a pytest fixture

2. [src/tests/test_utils.py:42] **Wrong mock boundary** (High, Needs review)
   - Mocking internal implementation details
   - Suggestion: Mock at the adapter boundary instead

#### Dead Code (5 issues)

3. [src/utils/legacy.py:1] **Unused module** (Low, Safe)
   - Module imported nowhere in codebase
   - Suggestion: Delete file

...

#### Abstraction (3 issues)
...

#### Style (3 issues)
...

### Summary Table

| Category | Safe Fixes | Needs Review | Total |
|----------|------------|--------------|-------|
| Tests | 3 | 1 | 4 |
| Dead Code | 4 | 1 | 5 |
| Abstraction | 2 | 1 | 3 |
| Style | 1 | 2 | 3 |
| **Total** | **10** | **5** | **15** |

### Next Steps

- Run `/beagle:review-llm-artifacts --fix` to auto-fix Safe issues (coming soon)
- Review the JSON report at `.beagle/llm-artifacts-review.json`
```

## Output Format for Each Finding

```
[FILE:LINE] **ISSUE_TYPE** (Risk, Fix Safety)
- Description
- Suggestion: Specific fix recommendation
```

## Rules

- Always load the `beagle:llm-artifacts-detection` skill first
- Use `Task` tool for parallel subagents when >= 4 files
- Every finding MUST have file:line reference
- Categorize risk honestly (don't inflate or deflate)
- Mark fix safety as "Safe" only if change is mechanical and reversible
- Create `.beagle` directory if needed
- Write JSON report before displaying summary
