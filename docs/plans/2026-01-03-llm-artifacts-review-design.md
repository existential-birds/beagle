# LLM Artifacts Review Commands Design

## Overview

Two complementary commands to detect and fix common code artifacts left behind by LLM coding agents:

- **`/beagle:review-llm-artifacts`** - Detects issues using parallel subagents
- **`/beagle:fix-llm-artifacts`** - Applies fixes with safe/risky classification

Engineers run these commands before submitting PRs or when cleaning up legacy codebases.

## Detection Categories

### 1. Tests Agent
| Issue | Description |
|-------|-------------|
| DRY violations | Setup/teardown repeated across tests instead of fixtures |
| Library testing | Tests validating stdlib/framework behavior, not our code |
| Mock boundaries | Mocks placed too deep (internal methods) or too shallow |

### 2. Dead Code Agent
| Issue | Description |
|-------|-------------|
| Dead code | Functions/classes/variables never referenced |
| Unused imports | Imported but never used |
| TODO/FIXME | Unresolved placeholder comments |
| Backwards compat cruft | `_unused` renames, re-exports, `# removed` comments |
| Orphaned tests | Tests for code that no longer exists |

### 3. Abstraction Agent
| Issue | Description |
|-------|-------------|
| Over-abstraction | Wrapper classes adding no value, single-implementation interfaces |
| Copy-paste drift | 3+ similar code blocks that should be parameterized |
| Over-configuration | Feature flags for non-configurable things |

### 4. Style Agent
| Issue | Description |
|-------|-------------|
| Obvious comments | Comments restating what code clearly does |
| Over-documentation | Docstrings on trivial getters/setters |
| Defensive overkill | try/except around code that can't fail |
| Unnecessary type hints | Annotations on obvious locals (`x: int = 5`) |

## Command: review-llm-artifacts

### Arguments
- `--all`: Scan entire codebase (default: changed files from main)
- `--parallel`: Force parallel execution (default when 4+ files)
- Path: Target directory (default: cwd)

### Flow
1. Determine scope (git diff or all files)
2. Detect languages from file extensions
3. Spawn 4 subagents in parallel via `Task` tool
4. Each agent loads relevant language skills
5. Consolidate findings into categorized report
6. Write findings to `.beagle/llm-artifacts-review.json`
7. Display summary to user

### Output Format
```markdown
## LLM Artifact Review Summary

Scanned: 23 files (changed since main)
Languages: Python (18), TypeScript (5)

## Findings by Category

### Tests (3 issues)

1. [tests/test_api.py:45] DRY violation: repeated setup across 4 tests
   - Risk: Low | Fix: Safe
   - Suggestion: Extract to pytest fixture

2. [tests/test_utils.py:12] Testing library code
   - Risk: Medium | Fix: Needs review
   - Suggestion: Remove test (validates `json.loads` behavior)

### Dead Code (5 issues)
...

### Abstraction (2 issues)
...

### Style (4 issues)
...

## Summary

| Category | Safe to Auto-fix | Needs Review |
|----------|------------------|--------------|
| Tests | 1 | 2 |
| Dead Code | 4 | 1 |
| Abstraction | 0 | 2 |
| Style | 3 | 1 |
| **Total** | **8** | **6** |

Run `/beagle:fix-llm-artifacts` to apply fixes.
```

## Command: fix-llm-artifacts

### Arguments
- `--dry-run`: Show what would be fixed without changing files
- `--all`: Fix entire codebase (runs review with `--all` first)
- `--category <name>`: Only fix specific category (tests|dead-code|abstraction|style)

### Flow
1. Check for `.beagle/llm-artifacts-review.json`
   - If missing: run `review-llm-artifacts` first
   - If stale (git HEAD changed): warn and prompt to re-run
2. Partition findings by fix safety:
   - **Safe**: unused imports, TODO comments, obvious dead code, verbose comments
   - **Risky**: test refactors, abstraction changes, code removal
3. Auto-apply safe fixes in parallel (one agent per category)
4. For risky fixes, prompt per-item:
   ```
   [tests/test_utils.py:12] Remove test that only validates json.loads?
   This test doesn't exercise our code. (y/n/skip all risky)
   ```
5. After fixes applied:
   - Run linters (ruff, mypy, eslint based on language)
   - Run tests if available
   - Report results
6. Delete `.beagle/llm-artifacts-review.json`

### Safety
- Creates git stash before fixing (can restore with `git stash pop`)
- Shows diff summary after completion

## Review File Schema

`.beagle/llm-artifacts-review.json`:

```json
{
  "version": "1",
  "created_at": "2026-01-03T10:23:45Z",
  "git_head": "abc1234",
  "scope": "changed",
  "files_scanned": 23,
  "languages": ["python", "typescript"],
  "findings": [
    {
      "id": "test-001",
      "category": "tests",
      "type": "dry-violation",
      "file": "tests/test_api.py",
      "line": 45,
      "description": "Repeated setup across 4 tests",
      "suggestion": "Extract to pytest fixture",
      "risk": "low",
      "fix_safety": "safe",
      "fix_action": {
        "type": "refactor",
        "details": "Create fixture 'api_client' from repeated setup"
      }
    }
  ],
  "summary": {
    "total": 14,
    "by_category": {
      "tests": 3,
      "dead-code": 5,
      "abstraction": 2,
      "style": 4
    },
    "safe_fixes": 8,
    "risky_fixes": 6
  }
}
```

## File Structure

```
commands/
├── review-llm-artifacts.md    # Main review command
└── fix-llm-artifacts.md       # Fix command

skills/
└── llm-artifacts-detection/   # Shared detection criteria
    ├── SKILL.md               # Overview + agent prompt templates
    └── references/
        ├── tests-criteria.md
        ├── dead-code-criteria.md
        ├── abstraction-criteria.md
        └── style-criteria.md
```

## Subagent Prompts

### Tests Agent
```
Analyze test files for LLM-generated anti-patterns:

1. DRY violations: Setup/teardown code repeated across tests instead of fixtures
2. Library testing: Tests that validate standard library or framework behavior, not our code
3. Mock boundaries: Mocks placed too deep (internal methods) or too shallow (missing external calls)
   - Integration tests: mock at HTTP/DB boundary
   - Unit tests: mock direct dependencies only

Report each finding with file:line, category, and specific fix suggestion.
```

### Dead Code Agent
```
Find unused and leftover code:

1. Dead code: Functions/classes/variables never referenced
2. Unused imports: Imported but never used
3. TODO/FIXME comments: Unresolved placeholders
4. Backwards compat cruft: Variables renamed to _unused, re-exports of removed items, "# removed" comments
5. Orphaned tests: Tests for code that no longer exists

Report each with file:line and safe/risky classification.
```

### Abstraction Agent
```
Identify over-engineering patterns:

1. Over-abstraction: Wrapper classes/functions that add no value, single-implementation interfaces
2. Copy-paste drift: 3+ similar code blocks that should be a single function with parameters
3. Over-configuration: Feature flags for non-configurable things, env vars that never change

Report with file:line and refactoring suggestion.
```

### Style Agent
```
Find verbose LLM-style code:

1. Obvious comments: Comments restating what code clearly does
2. Over-documentation: Docstrings on trivial getters/setters
3. Defensive overkill: try/except around code that can't fail, null checks on non-nullable values
4. Unnecessary type hints: Type annotations on obvious local variables (x: int = 5)

Report with file:line. All style issues are safe to auto-fix.
```

## Implementation Notes

- Commands detect languages from file extensions and load appropriate skills (`python-code-review`, `go-code-review`, etc.)
- Subagents run via `Task` tool with `run_in_background: true` for parallelism
- `.beagle/` directory should be added to `.gitignore`
- Staleness detection compares `git_head` in JSON to current HEAD
