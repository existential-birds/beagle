---
description: Comprehensive iOS/SwiftUI code review with optional parallel agents
---

# iOS Code Review

## Arguments

- `--parallel`: Spawn specialized subagents per technology area
- Path: Target directory (default: current working directory)

## Step 1: Identify Changed Files

```bash
git diff --name-only $(git merge-base HEAD main)..HEAD | grep -E '\.swift$'
```

## Step 2: Verify Linter Status

**CRITICAL**: Run SwiftLint BEFORE flagging any style issues.

```bash
# Check if SwiftLint config exists and run it
if [ -f ".swiftlint.yml" ] || [ -f ".swiftlint.yaml" ]; then
    swiftlint lint --quiet <changed_files>
fi
```

**Rules:**
- If SwiftLint passes for a specific rule, DO NOT flag that issue manually
- SwiftLint configuration is authoritative for style rules
- Only flag issues that linters cannot detect (semantic issues, architectural problems)

## Step 3: Detect Technologies

```bash
# SwiftUI (always with swift files that import it)
grep -r "import SwiftUI" --include="*.swift" -l | head -3

# SwiftData
grep -r "import SwiftData\|@Model\|@Query" --include="*.swift" -l | head -3

# Swift Testing
grep -r "import Testing\|@Test\|#expect" --include="*.swift" -l | head -3

# Combine
grep -r "import Combine\|AnyPublisher\|@Published" --include="*.swift" -l | head -3

# URLSession (explicit async patterns)
grep -r "URLSession\.shared\|\.data(from:\|\.download(from:" --include="*.swift" -l | head -3

# CloudKit
grep -r "import CloudKit\|CKContainer\|CKRecord" --include="*.swift" -l | head -3

# WidgetKit
grep -r "import WidgetKit\|TimelineProvider\|WidgetFamily" --include="*.swift" -l | head -3

# App Intents
grep -r "import AppIntents\|@AppIntent\|AppEntity" --include="*.swift" -l | head -3

# HealthKit
grep -r "import HealthKit\|HKHealthStore\|HKQuery" --include="*.swift" -l | head -3

# WatchKit
grep -r "import WatchKit\|WKExtension\|WKInterfaceController" --include="*.swift" -l | head -3
```

## Step 4: Load Verification Protocol

Load `beagle:review-verification-protocol` skill and keep its checklist in mind throughout the review.

## Step 5: Load Skills

Use the `Skill` tool to load each applicable skill (e.g., `Skill(skill: "beagle:swift-code-review")`).

**Always load:**
- `beagle:swift-code-review`
- `beagle:swiftui-code-review`

**Conditionally load based on detection:**

| Condition | Skill |
|-----------|-------|
| SwiftData detected | `beagle:swiftdata-code-review` |
| Swift Testing detected | `beagle:swift-testing-code-review` |
| Combine detected | `beagle:combine-code-review` |
| URLSession detected | `beagle:urlsession-code-review` |
| CloudKit detected | `beagle:cloudkit-code-review` |
| WidgetKit detected | `beagle:widgetkit-code-review` |
| App Intents detected | `beagle:app-intents-code-review` |
| HealthKit detected | `beagle:healthkit-code-review` |
| WatchKit detected | `beagle:watchos-code-review` |

## Step 6: Review

**Sequential (default):**
1. Load applicable skills
2. Review Swift quality issues first (concurrency, memory, error handling)
3. Review SwiftUI patterns (view composition, state management, accessibility)
4. Review detected technology areas
5. Consolidate findings

**Parallel (--parallel flag):**
1. Detect all technologies upfront
2. Spawn one subagent per technology area with `Task` tool
3. Each agent loads its skill and reviews its domain
4. Wait for all agents
5. Consolidate findings

### Before Flagging Issues

1. **Check SwiftLint output** - don't duplicate linter findings
2. **Check code comments** for intentional patterns (// MARK:, // NOTE:, etc.)
3. **Consider Apple framework idioms** - what looks wrong generically may be correct for the framework
4. **Trace async code paths** before claiming missing error handling or race conditions

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
   - Why: Why this matters (crash, data loss, security, race condition)
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
# Swift build and lint
swift build
swiftlint lint --quiet

# Run tests if present
swift test
```

All checks must pass before approval.

## Rules

- Load skills BEFORE reviewing (not after)
- Number every issue sequentially (1, 2, 3...)
- Include FILE:LINE for each issue
- Separate Issue/Why/Fix clearly
- Categorize by actual severity
- Check for Swift 6 strict concurrency issues
- Run verification after fixes
