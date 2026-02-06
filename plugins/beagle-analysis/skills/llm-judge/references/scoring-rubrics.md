# Scoring Rubrics

Detailed rubrics for each of the 5 judging dimensions. Judges use these to assign consistent 1-5 scores.

## General Scoring Scale

| Score | Meaning | General Criteria |
|-------|---------|------------------|
| 5 | Excellent | Exceeds expectations, best practices throughout |
| 4 | Good | Meets all requirements, minor issues only |
| 3 | Average | Functional but notable gaps or issues |
| 2 | Below Average | Significant issues affecting quality |
| 1 | Poor | Fails to meet basic requirements |

---

## Functionality (30% weight)

Evaluates whether the implementation meets the spec requirements and works correctly.

| Score | Criteria |
|-------|----------|
| 5 | All spec requirements implemented. All tests pass. No obvious bugs. |
| 4 | All requirements implemented. Tests pass with minor failures (< 5%). Edge cases may be missing. |
| 3 | Most requirements implemented (> 75%). Some test failures. Core functionality works. |
| 2 | Partial implementation (50-75%). Significant test failures. Core features have bugs. |
| 1 | Minimal implementation (< 50%). Tests fail or don't exist. Core functionality broken. |

**Key Evidence:**
- `functionality.implemented` vs `functionality.spec_requirements`
- `functionality.test_results.passed` vs `functionality.test_results.failed`
- `functionality.missing` and `functionality.partially_implemented`

---

## Security (25% weight)

Evaluates security posture and absence of vulnerabilities.

| Score | Criteria |
|-------|----------|
| 5 | No security findings. Positive security patterns present. OWASP Top 10 addressed. |
| 4 | No high-severity findings. 1-2 low/medium issues. Good security hygiene. |
| 3 | 1-2 medium-severity issues OR 3+ low-severity. Basic security present. |
| 2 | 1+ high-severity issue OR 3+ medium. Security gaps evident. |
| 1 | Multiple high-severity issues. Critical vulnerabilities. No security consideration. |

**Severity Weights:**
- High: SQL injection, command injection, auth bypass, secrets in code
- Medium: XSS, CSRF, insecure deserialization, missing input validation
- Low: Information disclosure, verbose errors, missing security headers

**Key Evidence:**
- `security.findings` (count and severity)
- `security.patterns_observed`

---

## Test Quality (20% weight)

Evaluates test coverage, DRY adherence, and testing practices.

| Score | Criteria |
|-------|----------|
| 5 | High coverage. No DRY violations. Good mock boundaries. Tests are maintainable. |
| 4 | Moderate-high coverage. Minor DRY issues (1-2). Good testing practices. |
| 3 | Moderate coverage. Some DRY violations (3-5). Acceptable mocking. |
| 2 | Low coverage. Significant DRY violations. Poor mock boundaries. |
| 1 | Minimal/no tests. Severe DRY problems. Tests don't follow best practices. |

**Key Evidence:**
- `tests.coverage_estimate`
- `tests.dry_violations` (count)
- `tests.mocking_approach`
- `tests.test_count` relative to codebase size

---

## Overengineering (15% weight)

Evaluates simplicity and absence of unnecessary complexity.

| Score | Criteria |
|-------|----------|
| 5 | Clean, simple code. No unnecessary abstractions. YAGNI followed. |
| 4 | Mostly simple. 1-2 minor over-abstractions. Code is readable. |
| 3 | Some complexity. 3-5 abstraction issues. Config complexity medium. |
| 2 | Significant over-engineering. 6+ abstraction issues. Unnecessary patterns. |
| 1 | Severely over-engineered. Abstractions everywhere. Simple tasks made complex. |

**Key Evidence:**
- `overengineering.abstractions` (count)
- `overengineering.defensive_code` (count)
- `overengineering.config_complexity`

---

## Dead Code (10% weight)

Evaluates cleanliness and absence of unused/obsolete code.

| Score | Criteria |
|-------|----------|
| 5 | No dead code. No TODOs. Clean codebase. |
| 4 | 1-3 minor issues (unused imports). No significant dead code. |
| 3 | 4-6 issues. Some unused functions or TODOs. |
| 2 | 7-10 issues. Unused functions/classes. Multiple TODOs. |
| 1 | 10+ issues. Significant dead code. Many TODOs/commented blocks. |

**Key Evidence:**
- `dead_code.unused_imports` (count)
- `dead_code.unused_functions` (count)
- `dead_code.todo_comments`
- `dead_code.commented_code_blocks`
