---
description: Comprehensive BubbleTea TUI code review for terminal applications
---

# TUI Code Review

## Arguments

- `--parallel`: Spawn specialized subagents per technology area
- Path: Target directory (default: current working directory)

## Step 1: Identify Changed Files

```bash
git diff --name-only $(git merge-base HEAD main)..HEAD | grep -E '\.go$'
```

## Step 2: Detect Technologies

```bash
# Detect BubbleTea (required for TUI review)
grep -r "charmbracelet/bubbletea" --include="*.go" -l | head -3

# Detect Lipgloss styling
grep -r "charmbracelet/lipgloss\|lipgloss\.Style" --include="*.go" -l | head -3

# Detect Bubbles components
grep -r "charmbracelet/bubbles\|list\.Model\|textinput\.Model\|viewport\.Model" --include="*.go" -l | head -3

# Detect Wish SSH server
grep -r "charmbracelet/wish\|ssh\.Session" --include="*.go" -l | head -3

# Check for test files
git diff --name-only $(git merge-base HEAD main)..HEAD | grep -E '_test\.go$'
```

## Step 3: Load Skills

**Always load:**
- `beagle:go-code-review`
- `beagle:bubbletea-code-review`

**Conditionally load based on detection:**

| Condition | Skill |
|-----------|-------|
| Test files changed | `beagle:go-testing-code-review` |
| Wish SSH detected | `beagle:wish-ssh-code-review` |

## Step 4: Review Focus Areas

### Model/Update/View (Elm Architecture)

- [ ] Model is immutable (Update returns new model)
- [ ] Init returns proper initial command
- [ ] Update handles all message types
- [ ] View is pure function (no side effects)
- [ ] tea.Quit used correctly for exit

### Lipgloss Styling

- [ ] Styles defined once at package level
- [ ] Styles not created in View function
- [ ] Colors use AdaptiveColor for light/dark themes
- [ ] Layout responds to WindowSizeMsg

### Component Composition

- [ ] Sub-component updates propagated
- [ ] WindowSizeMsg passed to resizable components
- [ ] Focus management for multiple components
- [ ] Clear state machine for view transitions

### SSH Server (if applicable)

- [ ] Host keys persisted
- [ ] Graceful shutdown implemented
- [ ] PTY window size passed to TUI
- [ ] Per-session Lipgloss renderer

## Step 5: Review

**Sequential (default):**
1. Load applicable skills
2. Review Go code quality
3. Review BubbleTea patterns (Model/Update/View)
4. Review Lipgloss styling
5. Review component composition
6. Review SSH server (if applicable)
7. Consolidate findings

**Parallel (--parallel flag):**
1. Detect all technologies upfront
2. Spawn subagents for: Go quality, BubbleTea, SSH
3. Wait for all agents
4. Consolidate findings

## Output Format

```markdown
## Review Summary

[1-2 sentence overview of findings]

## Issues

### Critical (Blocking)

1. [FILE:LINE] ISSUE_TITLE
   - Issue: Description of what's wrong
   - Why: Why this matters (UI freeze, crash, resource leak)
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
- Pay special attention to:
  - Blocking operations in Update (freezes UI)
  - Style creation in View (performance)
  - Missing WindowSizeMsg handling (broken resize)
- Run verification after fixes
