---
description: Comprehensive Rust code review with optional parallel agents
---

# Rust Code Review

## Arguments

- `--parallel`: Spawn specialized subagents per technology area
- Path: Target directory (default: current working directory)

## Step 1: Identify Changed Files

```bash
git diff --name-only $(git merge-base HEAD main)..HEAD | grep -E '\.rs$'
```

## Step 2: Check Rust Edition and MSRV

```bash
# Check Cargo.toml for edition and rust-version
grep -E 'edition|rust-version' Cargo.toml

# Check workspace members if workspace
grep -A 20 '\[workspace\]' Cargo.toml
```

## Step 3: Verify Linter Status

CRITICAL: Run clippy and check BEFORE flagging style or correctness issues. Do NOT flag issues that clippy or the compiler already catches.

```bash
cargo clippy --all-targets --all-features -- -D warnings 2>&1 | head -50
cargo check --all-targets 2>&1 | head -50
```

## Step 4: Detect Technologies

```bash
# Detect tokio async runtime
grep -r "tokio" --include="Cargo.toml" -l | head -3

# Detect axum web framework
grep -r "axum" --include="Cargo.toml" -l | head -3

# Detect sqlx database
grep -r "sqlx" --include="Cargo.toml" -l | head -3

# Detect serde serialization
grep -r "serde" --include="Cargo.toml" -l | head -3

# Detect thiserror / anyhow
grep -r "thiserror\|anyhow" --include="Cargo.toml" -l | head -3

# Detect tracing
grep -r "tracing" --include="Cargo.toml" -l | head -3

# Check for test files in diff
git diff --name-only $(git merge-base HEAD main)..HEAD | grep -E '(test|tests).*\.rs$\|_test\.rs$'

# Check for unsafe code in diff
git diff $(git merge-base HEAD main)..HEAD -- '*.rs' | grep -c 'unsafe'
```

## Step 5: Load Verification Protocol

Load `beagle-rust:review-verification-protocol` skill and keep its checklist in mind throughout the review.

## Step 6: Load Skills

Use the `Skill` tool to load each applicable skill (e.g., `Skill(skill: "beagle-rust:rust-code-review")`).

**Always load:**
- `beagle-rust:rust-code-review`

**Conditionally load based on detection:**

| Condition | Skill |
|-----------|-------|
| Tokio detected | `beagle-rust:tokio-async-code-review` |
| Axum detected | `beagle-rust:axum-code-review` |
| sqlx detected | `beagle-rust:sqlx-code-review` |
| Serde detected | `beagle-rust:serde-code-review` |
| Test files changed | `beagle-rust:rust-testing-code-review` |

## Step 7: Review

**Sequential (default):**
1. Load applicable skills
2. Review core Rust quality (ownership, error handling, unsafe, traits)
3. Review detected technology areas
4. Consolidate findings

**Parallel (--parallel flag):**
1. Detect all technologies upfront
2. Spawn one subagent per technology area with `Task` tool
3. Each agent loads its skill and reviews its domain
4. Wait for all agents
5. Consolidate findings

## Step 8: Verify Findings

Before reporting any issue:
1. Re-read the actual code (not just diff context)
2. For "unused" claims - did you search all references across the workspace?
3. For "missing" claims - did you check trait definitions, derive macros, and `#[cfg]` gated code?
4. For "unnecessary clone" - did you verify the borrow checker allows a reference?
5. For "unsafe" issues - did you check the safety comments and surrounding invariants?
6. Remove any findings that are style preferences, not actual issues

## Step 9: Review Convergence

### Single-Pass Completeness

You MUST report ALL issues across ALL categories (ownership, error handling, async, types, tests, security, performance) in a single review pass. Do not hold back issues for later rounds.

Before submitting findings, ask yourself:
- "If all my recommended fixes are applied, will I find NEW issues in the fixed code?"
- "Am I requesting new code (tests, types, modules) that will itself need review?"

If yes to either: include those anticipated downstream issues NOW, in this review, so the author can address everything at once.

### Scope Rules

- Review ONLY the code in the diff and directly related existing code
- Do NOT request new features, test infrastructure, or architectural changes that didn't exist before the diff
- If test coverage is missing, flag it as ONE Minor issue ("Missing test coverage for X, Y, Z") — do NOT specify implementation details
- Doc comments, naming issues are Minor unless they affect public API contracts
- Do NOT request adding new dependencies (e.g., proptest, mockall, criterion)

### Fix Complexity Budget

Fixes to existing code should be flagged at their real severity regardless of size.

However, requests for **net-new code that didn't exist before the diff** must be classified as Informational:
- Adding a new dependency
- Creating entirely new modules, files, or test suites
- Extracting new traits or abstractions
- Adding benchmark suites

These are improvement suggestions for the author to consider in future work, not review blockers.

### Iteration Policy

If this is a re-review after fixes were applied:
- ONLY verify that previously flagged issues were addressed correctly
- Do NOT introduce new findings unrelated to the previous review's issues
- Accept Minor/Nice-to-Have issues that weren't fixed — do not re-flag them
- The goal of re-review is VERIFICATION, not discovery

## Output Format

```markdown
## Review Summary

[1-2 sentence overview of findings]

## Issues

### Critical (Blocking)

1. [FILE:LINE] ISSUE_TITLE
   - Issue: Description of what's wrong
   - Why: Why this matters (unsound unsafe, data race, panic, security)
   - Fix: Specific recommended fix

### Major (Should Fix)

2. [FILE:LINE] ISSUE_TITLE
   - Issue: ...
   - Why: ...
   - Fix: ...

### Minor (Nice to Have)

N. [FILE:LINE] ISSUE_TITLE
   - Issue: ...
   - Why: ...
   - Fix: ...

### Informational (For Awareness)

N. [FILE:LINE] SUGGESTION_TITLE
   - Suggestion: ...
   - Rationale: ...

## Good Patterns

- [FILE:LINE] Pattern description (preserve this)

## Verdict

Ready: Yes | No | With fixes 1-N (Critical/Major only; Minor items are acceptable)
Rationale: [1-2 sentences]
```

## Post-Fix Verification

After fixes are applied, run:

```bash
cargo check --all-targets
cargo clippy --all-targets --all-features -- -D warnings
cargo test --all-targets
```

All checks must pass before approval.

## Rules

- Load skills BEFORE reviewing (not after)
- Number every issue sequentially (1, 2, 3...)
- Include FILE:LINE for each issue
- Separate Issue/Why/Fix clearly
- Categorize by actual severity
- Run clippy before flagging style issues
- Run verification after fixes
- Report ALL issues in a single pass — do not hold back findings for later iterations
- Re-reviews verify previous fixes ONLY — no new discovery
- Requests for net-new code (new modules, dependencies, test suites) are Informational, not blocking
- The Verdict ignores Minor and Informational items — only Critical and Major block approval
