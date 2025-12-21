---
description: Comprehensive Go backend code review with optional parallel agents
---

# Go Backend Code Review

## Arguments

- `--parallel`: Spawn specialized subagents per technology area
- Path: Target directory (default: current working directory)

## Step 1: Identify Changed Files

```bash
git diff --name-only $(git merge-base HEAD main)..HEAD | grep -E '\.go$'
```

## Step 2: Detect Technologies

```bash
# Detect BubbleTea TUI
grep -r "charmbracelet/bubbletea\|tea\.Model\|tea\.Cmd" --include="*.go" -l | head -3

# Detect Wish SSH
grep -r "charmbracelet/wish\|ssh\.Session\|wish\.Middleware" --include="*.go" -l | head -3

# Detect Prometheus
grep -r "prometheus/client_golang\|promauto\|prometheus\.Counter" --include="*.go" -l | head -3

# Detect ZeroLog
grep -r "rs/zerolog\|zerolog\.Logger" --include="*.go" -l | head -3

# Check for test files
git diff --name-only $(git merge-base HEAD main)..HEAD | grep -E '_test\.go$'
```

## Step 3: Load Skills

**Always load:**
- `beagle:go-code-review`

**Conditionally load based on detection:**

| Condition | Skill |
|-----------|-------|
| Test files changed | `beagle:go-testing-code-review` |
| BubbleTea detected | `beagle:bubbletea-code-review` |
| Wish SSH detected | `beagle:wish-ssh-code-review` |
| Prometheus detected | `beagle:prometheus-go-code-review` |

## Step 4: Review

**Sequential (default):**
1. Load applicable skills
2. Review Go quality issues first (error handling, concurrency, interfaces)
3. Review detected technology areas
4. Consolidate findings

**Parallel (--parallel flag):**
1. Detect all technologies upfront
2. Spawn one subagent per technology area with `Task` tool
3. Each agent loads its skill and reviews its domain
4. Wait for all agents
5. Consolidate findings

## Output Format

```markdown
## Review Summary

[1-2 sentence overview of findings]

## Issues

### Critical (Blocking)

1. [FILE:LINE] ISSUE_TITLE
   - Issue: Description of what's wrong
   - Why: Why this matters (bug, race condition, resource leak, security)
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

## Good Patterns

- [FILE:LINE] Pattern description (preserve this)

## Verdict

Ready: Yes | No | With fixes 1-N
Rationale: [1-2 sentences]
```

## Post-Fix Verification

After fixes are applied, run:

```bash
go build ./...
go vet ./...
golangci-lint run
go test -v -race ./...
```

All checks must pass before approval.

## Rules

- Load skills BEFORE reviewing (not after)
- Number every issue sequentially (1, 2, 3...)
- Include FILE:LINE for each issue
- Separate Issue/Why/Fix clearly
- Categorize by actual severity
- Check for race conditions with `-race` flag
- Run verification after fixes
