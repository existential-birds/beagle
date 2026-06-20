# beagle-ios

Swift, SwiftUI, SwiftData, and iOS framework code review. Part of the [beagle](https://github.com/existential-birds/beagle) Agent Skills marketplace — see the [full skill catalog](../../SKILLS.md).

## Installation

For any coding agent that supports [Agent Skills](https://agentskills.io):

```bash
npx skills add existential-birds/beagle
```

For Claude Code:

```bash
claude plugin marketplace add https://github.com/existential-birds/beagle
claude plugin install beagle-ios@existential-birds
```

## Skills

| Skill | Description |
|-------|-------------|
| `review-ios` | Comprehensive iOS/SwiftUI code review with optional parallel per-technology subagents |
| `swift-code-review` | Concurrency safety, actor isolation, Sendable, error handling, and memory management |
| `swiftui-code-review` | View composition, state management, performance, and accessibility |
| `swiftdata-code-review` | Model design, queries, concurrency, and migrations |
| `swift-testing-code-review` | #expect/#require usage, parameterized tests, async testing, and organization |
| `combine-code-review` | Publisher/operator misuse, retain cycles, and error handling |
| `urlsession-code-review` | Async/await networking, request building, error handling, and caching |
| `app-intents-code-review` | Intent structure, entities, shortcuts, and parameters |
| `cloudkit-code-review` | Container setup, record handling, subscriptions, and sharing |
| `healthkit-code-review` | Authorization, queries, background delivery, and data types |
| `widgetkit-code-review` | Timeline management, view composition, configurable intents, and performance |
| `watchos-code-review` | App lifecycle, complications, WatchConnectivity, and performance constraints |
| `ios-animation-code-review` | Animation correctness, performance, accessibility, and Apple API best practices |
| `ios-animation-design` | Plan and spec iOS animations covering transitions, micro-interactions, and gesture-driven motion |
| `ios-animation-implementation` | Write Swift animation code with first-party SwiftUI, Core Animation, and UIKit APIs |
| `review-verification-protocol` | Reference: mandatory verification steps to reduce false positives |

## See Also

- [Skill catalog](../../SKILLS.md) — every skill in the marketplace
- [beagle-core](../beagle-core/README.md) — shared workflows, verification, and git skills
- [beagle marketplace](https://github.com/existential-birds/beagle) — the full Agent Skills marketplace
