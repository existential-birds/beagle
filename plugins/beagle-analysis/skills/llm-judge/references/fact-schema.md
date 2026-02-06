# Fact Schema

JSON schema for structured facts gathered by Phase 1 Repo Agents.

## Full Schema

```json
{
  "repo_label": "string - Display name for this repo",
  "repo_path": "string - Absolute path to repo",
  "git_info": {
    "branch": "string - Current branch name",
    "base": "string - Base branch (usually main)",
    "files_changed": "number - Count of changed files",
    "additions": "number - Lines added",
    "deletions": "number - Lines deleted",
    "diff_summary": "string - Brief description of changes"
  },
  "functionality": {
    "spec_requirements": ["array of requirement strings extracted from spec"],
    "implemented": ["array of requirements found implemented"],
    "missing": ["array of requirements not found"],
    "partially_implemented": ["array of requirements with incomplete implementation"],
    "test_results": {
      "ran": "boolean - Whether tests were executed",
      "framework": "string - pytest, jest, go test, etc.",
      "passed": "number",
      "failed": "number",
      "skipped": "number",
      "error_summary": "string - Brief description of failures if any"
    }
  },
  "security": {
    "findings": [
      {
        "file": "string - File path",
        "line": "number - Line number",
        "issue": "string - Description of security issue",
        "severity": "high | medium | low",
        "category": "string - OWASP category if applicable"
      }
    ],
    "patterns_observed": ["array of positive security patterns found"]
  },
  "tests": {
    "test_count": "number - Total test count",
    "coverage_estimate": "none | low | moderate | high",
    "dry_violations": [
      {
        "file": "string",
        "line": "number",
        "description": "string"
      }
    ],
    "mocking_approach": "string - Description of mocking strategy",
    "test_quality_notes": "string - General observations"
  },
  "overengineering": {
    "abstractions": [
      {
        "file": "string",
        "line": "number",
        "issue": "string - Description of over-abstraction"
      }
    ],
    "defensive_code": [
      {
        "file": "string",
        "line": "number",
        "issue": "string"
      }
    ],
    "config_complexity": "low | medium | high"
  },
  "dead_code": {
    "unused_imports": ["array of file:line references"],
    "unused_functions": ["array of file:line references"],
    "unused_variables": ["array of file:line references"],
    "todo_comments": "number - Count of TODO/FIXME",
    "commented_code_blocks": "number - Count of commented code"
  }
}
```

## Example

```json
{
  "repo_label": "Claude",
  "repo_path": "/path/to/repo-a",
  "git_info": {
    "branch": "main",
    "base": "main",
    "files_changed": 42,
    "additions": 1250,
    "deletions": 380,
    "diff_summary": "Adds auth flow and data export features"
  },
  "functionality": {
    "spec_requirements": ["auth flow", "data export", "rate limiting"],
    "implemented": ["auth flow", "data export"],
    "missing": ["rate limiting"],
    "partially_implemented": [],
    "test_results": {
      "ran": true,
      "framework": "pytest",
      "passed": 45,
      "failed": 2,
      "skipped": 1,
      "error_summary": "2 tests fail on edge case validation"
    }
  },
  "security": {
    "findings": [
      {
        "file": "src/api.py",
        "line": 42,
        "issue": "SQL string concatenation instead of parameterized query",
        "severity": "high",
        "category": "Injection"
      }
    ],
    "patterns_observed": ["input validation present", "no secrets in code", "HTTPS enforced"]
  },
  "tests": {
    "test_count": 48,
    "coverage_estimate": "moderate",
    "dry_violations": [
      {
        "file": "tests/test_api.py",
        "line": 15,
        "description": "Setup code repeated in 5 test functions"
      }
    ],
    "mocking_approach": "Mocks at adapter boundary, uses pytest fixtures",
    "test_quality_notes": "Good isolation, some DRY issues"
  },
  "overengineering": {
    "abstractions": [
      {
        "file": "src/factory.py",
        "line": 1,
        "issue": "Factory pattern for single implementation"
      }
    ],
    "defensive_code": [],
    "config_complexity": "low"
  },
  "dead_code": {
    "unused_imports": ["src/utils.py:3"],
    "unused_functions": [],
    "unused_variables": [],
    "todo_comments": 2,
    "commented_code_blocks": 1
  }
}
```
