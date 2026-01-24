# iOS Code Review Skills - Design & Build Plan

## Overview

Create a comprehensive iOS/SwiftUI code review system following beagle's progressive disclosure pattern: one command (`review-ios`) that detects technologies and loads specialized skills.

## Architecture

### Command: `review-ios`

- Detects changed .swift files
- Runs SwiftLint if configured
- Detects technologies via import statements
- Loads applicable skills
- Supports --parallel for subagent-per-technology

### Skills (11 total)

| Skill | Detection | Always/Conditional |
|-------|-----------|-------------------|
| swift-code-review | *.swift | Always |
| swiftui-code-review | import SwiftUI | Always |
| swiftdata-code-review | import SwiftData | Conditional |
| swift-testing-code-review | import Testing | Conditional |
| combine-code-review | import Combine | Conditional |
| urlsession-code-review | URLSession patterns | Conditional |
| cloudkit-code-review | import CloudKit | Conditional |
| widgetkit-code-review | import WidgetKit | Conditional |
| app-intents-code-review | import AppIntents | Conditional |
| healthkit-code-review | import HealthKit | Conditional |
| watchos-code-review | import WatchKit | Conditional |

### Skill Structure (each)

```
skills/<name>/
├── SKILL.md           # Quick reference + checklist (~50 lines)
└── references/
    ├── <topic-1>.md   # Deep dive (~100 lines each)
    ├── <topic-2>.md
    └── ...
```

## Build Sessions

### Session 1: swift-code-review

**Research targets:**

- https://developer.apple.com/documentation/swift/concurrency
- https://developer.apple.com/documentation/observation
- Swift 6 language guide (error handling, optionals)

**Reference files:**

- concurrency.md - async/await, actors, Sendable, @MainActor, Task
- observable.md - @Observable, @ObservationIgnored, @Bindable
- error-handling.md - Result, typed throws, do/catch patterns
- common-mistakes.md - force unwraps, retain cycles, naming

---

### Session 2: swiftui-code-review

**Research targets:**

- https://developer.apple.com/documentation/swiftui
- WWDC 2024 SwiftUI sessions
- Apple HIG for SwiftUI patterns

**Reference files:**

- view-composition.md - extraction, modifiers, body complexity
- state-management.md - @State, @Binding, @Environment, @Bindable
- performance.md - LazyStacks, view identity, AnyView avoidance
- accessibility.md - labels, hints, traits, Dynamic Type

---

### Session 3: swiftdata-code-review

**Research targets:**

- https://developer.apple.com/documentation/swiftdata
- WWDC 2024/2025 SwiftData sessions

**Reference files:**

- model-design.md - @Model, @Attribute, @Relationship
- queries.md - @Query, predicates, sorting, filtering
- concurrency.md - @ModelActor, background contexts
- migrations.md - schema versioning, lightweight migration

---

### Session 4: swift-testing-code-review

**Research targets:**

- https://developer.apple.com/documentation/testing
- WWDC 2024 Swift Testing introduction

**Reference files:**

- expect-macro.md - #expect vs XCTAssert, expression capture
- parameterized.md - @Test with arguments, traits
- async-testing.md - confirmation, async sequences
- organization.md - @Suite, tags, parallel execution

---

### Session 5: combine-code-review

**Research targets:**

- https://developer.apple.com/documentation/combine

**Reference files:**

- publishers.md - built-in publishers, custom publishers
- operators.md - map, flatMap, merge, combineLatest
- memory.md - cancellables, AnyCancellable, retain cycles
- error-handling.md - tryMap, catch, replaceError

---

### Session 6: urlsession-code-review

**Research targets:**

- https://developer.apple.com/documentation/foundation/urlsession

**Reference files:**

- async-networking.md - async/await data tasks, download tasks
- request-building.md - URLRequest, headers, body encoding
- error-handling.md - URLError, response validation
- caching.md - URLCache, configuration, background sessions

---

### Session 7: cloudkit-code-review

**Research targets:**

- https://developer.apple.com/documentation/cloudkit

**Reference files:**

- container-setup.md - CKContainer, databases, zones
- records.md - CKRecord, references, assets
- subscriptions.md - CKSubscription, push notifications
- sharing.md - CKShare, participants, permissions

---

### Session 8: widgetkit-code-review

**Research targets:**

- https://developer.apple.com/documentation/widgetkit

**Reference files:**

- timeline.md - TimelineProvider, entries, reload policies
- views.md - widget families, containerBackground, sizing
- intents.md - configurable widgets, AppIntentTimelineProvider
- performance.md - budget, data fetching, caching

---

### Session 9: app-intents-code-review

**Research targets:**

- https://developer.apple.com/documentation/appintents

**Reference files:**

- intent-structure.md - @AppIntent, perform(), parameters
- entities.md - AppEntity, EntityQuery, identifiers
- shortcuts.md - AppShortcutsProvider, phrases
- parameters.md - @Parameter, validation, dynamic options

---

### Session 10: healthkit-code-review

**Research targets:**

- https://developer.apple.com/documentation/healthkit

**Reference files:**

- authorization.md - HKHealthStore, permissions, status checks
- queries.md - HKQuery types, predicates, anchored queries
- background.md - background delivery, observer queries
- data-types.md - HKQuantityType, HKCategoryType, workouts

---

### Session 11: watchos-code-review

**Research targets:**

- https://developer.apple.com/documentation/watchkit
- https://developer.apple.com/documentation/watchconnectivity

**Reference files:**

- lifecycle.md - App lifecycle, scenes, background modes
- complications.md - ClockKit, timeline entries, templates
- connectivity.md - WCSession, message passing, file transfer
- performance.md - memory limits, background refresh, battery

---

### Session 12: review-ios command

**Depends on:** All 11 skills complete

**Create:** `commands/review-ios.md`

- Detection logic for all technologies
- Skill loading table
- Sequential and parallel review modes
- Output format matching other review commands
- Post-fix verification commands

## Detection Commands

```bash
# SwiftUI (always with swift files)
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

## Output Format (consistent with beagle)

```markdown
## Review Summary

[1-2 sentence overview]

## Issues

### Critical (Blocking)

1. [FILE:LINE] ISSUE_TITLE
   - Issue: Description
   - Why: Impact (crash, data loss, security)
   - Fix: Specific recommendation

### Major (Should Fix)

...

### Minor (Nice to Have)

...

## Good Patterns

- [FILE:LINE] Pattern description (preserve this)

## Verdict

Ready: Yes | No | With fixes 1-N
Rationale: [1-2 sentences]
```

## Per-Session Workflow

1. **Start session** with: "Building `<skill-name>` from iOS review plan"
2. **Spawn research subagents** for Apple docs + web search
3. **Synthesize** findings into SKILL.md + references/
4. **Validate** against beagle patterns
5. **Commit** with: `feat(ios): add <skill-name> skill`

## Research Strategy

Each session spawns parallel subagents to fetch:

1. **Apple Developer Documentation** - Primary source for API patterns and best practices
2. **WWDC sessions** - Latest guidance and new features (2024/2025)
3. **Web search** - Community anti-patterns and real-world issues

Subagents use WebFetch for Apple docs and WebSearch for broader patterns.

## Validation Checklist

Before committing each skill:

- [ ] SKILL.md under 60 lines
- [ ] Quick reference table links to all reference files
- [ ] Review checklist has 8-12 actionable items
- [ ] Each reference file has "Critical Anti-Patterns" section
- [ ] Each reference file has "Review Questions" section
- [ ] Issue format matches `[FILE:LINE] ISSUE_TITLE`
- [ ] No overlap with swift-code-review (core skill)
