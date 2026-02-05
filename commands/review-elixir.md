---
description: Comprehensive Elixir/Phoenix code review with optional parallel agents
---

# Elixir Code Review

## Arguments

- `--parallel`: Spawn specialized subagents per technology area
- Path: Target directory (default: current working directory)

## Step 1: Identify Changed Files

```bash
git diff --name-only $(git merge-base HEAD main)..HEAD | grep -E '\.ex$|\.exs$|\.heex$'
```

## Step 2: Verify Linter/Formatter Status

**CRITICAL**: Run project linters BEFORE flagging any style issues.

```bash
# Check formatting
mix format --check-formatted

# Check Credo if present
if [ -f ".credo.exs" ] || grep -q ":credo" mix.exs 2>/dev/null; then
    mix credo --strict
fi

# Check Dialyzer if configured
if grep -q ":dialyxir" mix.exs 2>/dev/null; then
    mix dialyzer --format short
fi
```

**Rules:**
- If a linter passes for a specific rule, DO NOT flag that issue manually
- Linter configuration is authoritative for style rules
- Only flag issues that linters cannot detect (semantic issues, architectural problems)

## Step 3: Detect Technologies

```bash
# Detect Phoenix
grep -r "use Phoenix\|Phoenix.Router\|Phoenix.Controller" --include="*.ex" -l | head -3

# Detect LiveView
grep -r "use Phoenix.LiveView\|Phoenix.LiveComponent\|~H" --include="*.ex" -l | head -3

# Detect Oban
grep -r "use Oban.Worker\|Oban.insert" --include="*.ex" -l | head -3

# Check for test files
git diff --name-only $(git merge-base HEAD main)..HEAD | grep -E '_test\.exs$'
```

## Step 4: Load Verification Protocol

Load `beagle:review-verification-protocol` skill and keep its checklist in mind throughout the review.

## Step 5: Load Skills

Use the `Skill` tool to load each applicable skill.

**Always load:**
- `beagle:elixir-code-review`

**Conditionally load based on detection:**

| Condition | Skill |
|-----------|-------|
| Phoenix detected | `beagle:phoenix-code-review` |
| LiveView detected | `beagle:liveview-code-review` |
| Performance focus requested | `beagle:elixir-performance-review` |
| Security focus requested | `beagle:elixir-security-review` |
| Test files changed | `beagle:exunit-code-review` |

## Step 6: Review

**Sequential (default):**
1. Load applicable skills
2. Review Elixir quality issues first
3. Review Phoenix patterns (if detected)
4. Review LiveView patterns (if detected)
5. Review detected technology areas
6. Consolidate findings

**Parallel (--parallel flag):**
1. Detect all technologies upfront
2. Spawn one subagent per technology area with `Task` tool
3. Each agent loads its skill and reviews its domain
4. Wait for all agents
5. Consolidate findings

### Before Flagging Issues

1. **Check CLAUDE.md** for documented intentional patterns
2. **Check code comments** around the flagged area for "intentional", "optimization", or "NOTE:"
3. **Trace the code path** before claiming missing coverage
4. **Consider framework idioms** - what looks wrong generically may be correct for Elixir/Phoenix

## Step 7: Verify Findings

Before reporting any issue:
1. Re-read the actual code (not just diff context)
2. For "unused" claims - did you search all references?
3. For "missing" claims - did you check framework/parent handling?
4. For syntax issues - did you verify against current version docs?
5. Remove any findings that are style preferences, not actual issues

## Output Format

```markdown
## Review Summary

[1-2 sentence overview of findings]

## Issues

### Critical (Blocking)

1. [FILE:LINE] ISSUE_TITLE
   - Issue: Description of what's wrong
   - Why: Why this matters (bug, type safety, security)
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
mix format --check-formatted
mix credo --strict
mix dialyzer
mix test
```

All checks must pass before approval.

## Rules

- Load skills BEFORE reviewing (not after)
- Number every issue sequentially (1, 2, 3...)
- Include FILE:LINE for each issue
- Separate Issue/Why/Fix clearly
- Categorize by actual severity
- Run verification after fixes
