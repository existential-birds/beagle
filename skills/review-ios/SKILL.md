---
name: review-ios
description: Performs comprehensive iOS, iPadOS, watchOS, and SwiftUI code reviews across Swift concurrency, Apple frameworks, testing, and animations. Use when reviewing Swift or Xcode projects, iOS pull requests, or SwiftUI/UIKit changes.
---

# iOS Code Review

## Arguments

- `--parallel`: If the agent supports subagents, dispatch one specialized subagent per technology area
- Path: Target directory (default: current working directory)

## Hard gates

Complete in order before writing **Issues** in the output (empty scope is allowed; fabricated findings are not).

1. **Scope gate:** You have an explicit list of `.swift` paths under review (from Step 1 or a user-provided path). **Pass:** List captured in working notes **or** one line: `No Swift files in scope` — then stop with no Issues.
2. **Linter gate (style):** Step 2 commands ran for this tree; if no `.swiftlint.yml` / `.swiftlint.yaml`, note that in one line. **Pass:** You do not report a style issue that SwiftLint would already enforce for that line when config exists and `swiftlint` succeeds.
3. **Protocol gate:** Apply the `review-verification-protocol` skill ([review-verification-protocol](../review-verification-protocol/SKILL.md) when sibling skills are installed; otherwise apply the verification rules in this file) before Step 6. **Pass:** If you report any Issues, at least one finding was checked against that checklist (name the item in Review Summary or on that Issue); if you report zero Issues, state `Protocol applied; no issues` in Review Summary.
4. **Evidence gate (Critical/Major):** For each Critical or Major item, you re-read the file at `FILE:LINE` (full surrounding context, not only the diff hunk). **Pass:** The Issue text matches observable code at that location.

Do not begin Step 6 until **Gates 1–3** are satisfied (skills load order stays Steps 4–5).

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
# SwiftUI (always load when SwiftUI is imported)
grep -r "import SwiftUI" --include="*.swift" -l | head -3

# SwiftData
grep -r "import SwiftData\|@Model\|@Query" --include="*.swift" -l | head -3

# Swift Testing
grep -r "import Testing\|@Test\|#expect" --include="*.swift" -l | head -3

# CloudKit
grep -r "import CloudKit\|CKContainer\|CKRecord\|CKSyncEngine" --include="*.swift" -l | head -3

# WidgetKit
grep -r "import WidgetKit\|TimelineProvider\|WidgetFamily\|ControlWidget" --include="*.swift" -l | head -3

# App Intents
grep -r "import AppIntents\|AppIntent\|AppEntity\|AppShortcutsProvider" --include="*.swift" -l | head -3

# HealthKit
grep -r "import HealthKit\|HKHealthStore\|HKQuery\|HKSampleQueryDescriptor" --include="*.swift" -l | head -3

# watchOS / WatchKit / WatchConnectivity
grep -r "import WatchKit\|import WatchConnectivity\|WKApplicationDelegate\|WKExtendedRuntimeSession\|WCSession\|os(watchOS)\|WKExtension\|WKInterfaceController" --include="*.swift" -l | head -3

# Animations (beyond basic withAnimation)
grep -r "PhaseAnimator\|KeyframeAnimator\|matchedGeometryEffect\|navigationTransition\|scrollTransition\|CABasicAnimation\|CASpringAnimation\|CAKeyframeAnimation\|UIViewPropertyAnimator\|UIDynamicAnimator\|\.symbolEffect\|\.contentTransition\|CustomAnimation\|MeshGradient" --include="*.swift" -l | head -3

# URLSession / legacy Combine (checked inline using subsections below)
grep -r "URLSession\|URLRequest\|URLCache\|import Combine\|AnyCancellable\|\.sink(" --include="*.swift" -l | head -3
```

## Step 4: Load Verification Protocol

Load the `review-verification-protocol` skill ([../review-verification-protocol/SKILL.md](../review-verification-protocol/SKILL.md) if installed) and keep its checklist in mind throughout the review.

## Step 5: Load Skills

Load each applicable sibling skill below (read its `SKILL.md` if installed; if running single-skill `--skill review-ios`, apply the domain checks directly).

**Always load:**
- `swift-code-review`: [../swift-code-review/SKILL.md](../swift-code-review/SKILL.md)
- `swiftui-code-review`: [../swiftui-code-review/SKILL.md](../swiftui-code-review/SKILL.md)

**Conditionally load based on detection:**

| Condition | Skill |
|-----------|-------|
| SwiftData detected | `swiftdata-code-review` ([../swiftdata-code-review/SKILL.md](../swiftdata-code-review/SKILL.md)) |
| Swift Testing detected | `swift-testing-code-review` ([../swift-testing-code-review/SKILL.md](../swift-testing-code-review/SKILL.md)) |
| CloudKit detected | `cloudkit-code-review` ([../cloudkit-code-review/SKILL.md](../cloudkit-code-review/SKILL.md)) |
| WidgetKit detected | `widgetkit-code-review` ([../widgetkit-code-review/SKILL.md](../widgetkit-code-review/SKILL.md)) |
| App Intents detected | `app-intents-code-review` ([../app-intents-code-review/SKILL.md](../app-intents-code-review/SKILL.md)) |
| HealthKit detected | `healthkit-code-review` ([../healthkit-code-review/SKILL.md](../healthkit-code-review/SKILL.md)) |
| watchOS / WatchKit detected | `watchos-code-review` ([../watchos-code-review/SKILL.md](../watchos-code-review/SKILL.md)) |
| Animation code detected | `ios-animation-code-review` ([../ios-animation-code-review/SKILL.md](../ios-animation-code-review/SKILL.md)) |

## Step 6: Review

**If the agent supports subagents** (and `--parallel` is requested), dispatch one subagent per technology area in parallel; **otherwise** run sequentially. Both paths produce identical output — the same consolidated findings.

**Sequential (default):**
1. Load applicable skills
2. Review Swift quality issues first (concurrency, memory, error handling)
3. Review SwiftUI patterns (view composition, state management, accessibility)
4. Review detected technology areas (and inline `URLSession` / legacy Combine checks below if present)
5. Consolidate findings

**Parallel (when supported, via --parallel):**
1. Detect all technologies upfront
2. Dispatch one subagent per technology area
3. Each agent loads its skill and reviews its domain
4. Wait for all agents
5. Consolidate findings

### Inline Checks: `URLSession` Apple Platform Traps

If `URLSession`, `URLRequest`, or `URLCache` appears in scope, check these non-obvious Apple platform pitfalls:
- **HTTP status codes don't throw**: `URLSession` only throws on transport errors (`URLError`), not `4xx`/`5xx`. Cast to `HTTPURLResponse` and validate `statusCode` (e.g., `200...299`).
- **Async `download(from:)` temp files are NOT auto-deleted**: Unlike legacy completion handlers, async `download(from:)` / `download(for:)` leaves the file at `tempURL` — verify it is moved or deleted (`defer { try? FileManager.default.removeItem(at: tempURL) }`).
- **Strong delegate retain cycles**: `URLSession(configuration:delegate:delegateQueue:)` retains its `delegate` strongly until `finishTasksAndInvalidate()` or `invalidateAndCancel()` is called.
- **Timeout & cache defaults**: Default `timeoutIntervalForResource` is **7 days** (set an explicit bound for user-facing calls); `URLCache.shared` defaults are small (~512 KB memory / 10 MB disk) and responses exceeding **5% of disk capacity** are not cached.
- **Background sessions**: Require unique identifiers across the main app and app extensions, `uploadTask(with:fromFile:)` (not `Data`), delegate callbacks (completion handlers fail), and `handleEventsForBackgroundURLSession` + `urlSessionDidFinishEvents`.
- **Connection pooling**: Reuse `URLSession` instances across requests to preserve HTTP/2 multiplexing and TLS session reuse instead of allocating a session per call.

### Inline Checks: Legacy Combine Code

If `import Combine`, `AnyCancellable`, or `.sink(` appears in legacy code:
- **Retain cycles & `assign(to:on:self)`**: Flag `assign(to: \.prop, on: self)` stored on `self` (always captures `self` strongly; prefer `assign(to: &$prop)` or `sink { [weak self] ... }`) and `sink` closures strongly capturing `self` when `self` owns the `AnyCancellable`.
- **Subscription retention**: Verify every `AnyCancellable` from `sink`/`assign(to:on:)` is stored in a `Set<AnyCancellable>` or property (discarding it cancels immediately, often surfacing as `URLError.cancelled` / `-999`).

### Before Flagging Issues

1. **Check SwiftLint output** - don't duplicate linter findings
2. **Check code comments** for intentional patterns (`// MARK:`, `// NOTE:`, etc.)
3. **Unused-symbol runtime & target surfaces** - before flagging unused symbols, check `public`/`open` symbols used by SPM modules or app extensions, `@objc`/`#selector`/key paths/dynamic dispatch, Interface Builder outlets/actions, `#Preview`, asset catalogs, and SwiftUI `@State`/`@Binding`/`@Observable` bindings.
4. **Swift/Apple idioms (do NOT flag)** - `@IBOutlet` implicitly unwrapped optionals, `!` or `try!` in tests/prototypes, `PreferenceKey` child-to-parent data flow, upstream error handling via `Result`/Combine/alert coordinators, and `Task` cancellation via `.task`/`onDisappear` or Combine teardown in `deinit`.
5. **View body complexity threshold** - only flag `View.body` complexity when the body exceeds **40 lines** and extraction preserves clarity (do not flag small leaf views).
6. **Trace async code paths** before claiming missing error handling or race conditions.

## Step 7: Verify Findings

Before reporting any issue:
1. Re-read the actual code (not just diff context)
2. For "unused" claims - did you search all references and target surfaces?
3. For "missing" claims - did you check framework/parent handling?
4. For syntax issues - did you verify against current version docs?
5. Remove any findings that are style preferences, not actual issues

## Step 8: Review Convergence

### Single-Pass Completeness

You MUST report ALL issues across ALL categories (style, logic, types, tests, security, performance) in a single review pass. Do not hold back issues for later rounds.

Before submitting findings, ask yourself:
- "If all my recommended fixes are applied, will I find NEW issues in the fixed code?"
- "Am I requesting new code (tests, types, modules) that will itself need review?"

If yes to either: include those anticipated downstream issues NOW, in this review, so the author can address everything at once.

### Scope Rules

- Review ONLY the code in the diff and directly related existing code
- Do NOT request new features, test infrastructure, or architectural changes that didn't exist before the diff
- If test coverage is missing, flag it as ONE Minor issue ("Missing test coverage for X, Y, Z") — do NOT specify implementation details like mock libraries, protocol extraction, or dependency injection patterns that would introduce substantial new code
- Typespecs, documentation, and naming issues are Minor unless they affect public API contracts
- Do NOT request adding new dependencies (e.g., third-party packages, testing libraries, linter plugins)

### Fix Complexity Budget

Fixes to existing code should be flagged at their real severity regardless of size.

However, requests for **net-new code that didn't exist before the diff** must be classified as Informational:
- Adding a new dependency (e.g., a third-party package, a linter plugin)
- Creating entirely new modules, files, or test suites
- Extracting new protocols or abstractions

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

After fixes are applied, run the project's build, lint, and test commands:

```bash
# SwiftLint (if configured)
if [ -f ".swiftlint.yml" ] || [ -f ".swiftlint.yaml" ]; then
    swiftlint lint --quiet
fi

# Xcode workspace/project (standard iOS/macOS/watchOS apps)
# Replace <WorkspaceOrProject> and <Scheme> with the repo's actual values
xcodebuild -workspace <Workspace>.xcworkspace -scheme <Scheme> -destination 'platform=iOS Simulator,name=iPhone 16' test
# Or for .xcodeproj without a workspace:
# xcodebuild -project <Project>.xcodeproj -scheme <Scheme> -destination 'platform=iOS Simulator,name=iPhone 16' test

# Swift Package Manager (if Package.swift is the root target)
swift build
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
- Report ALL issues in a single pass — do not hold back findings for later iterations
- Re-reviews verify previous fixes ONLY — no new discovery
- Requests for net-new code (new modules, dependencies, test suites) are Informational, not blocking
- The Verdict ignores Minor and Informational items — only Critical and Major block approval
