# beagle-ios

Swift, SwiftUI, SwiftData, and iOS framework code review skills for [Claude Code](https://claude.ai/code). Part of the [beagle](https://github.com/existential-birds/beagle) plugin marketplace.

## Installation

```bash
# Add the marketplace (if not already added)
claude plugin marketplace add https://github.com/existential-birds/beagle

# Install the plugin
claude plugin install beagle-ios@existential-birds
```

## Commands

| Command | Usage | Description |
|---------|-------|-------------|
| **review-ios** | `/beagle-ios:review-ios` | Comprehensive iOS/SwiftUI code review with optional parallel agents |

Reviews changed `.swift` files against `main`. Runs SwiftLint (if configured) before flagging style issues. Use `--parallel` to spawn specialized subagents per technology area.

## Skills

| Skill | Description |
|-------|-------------|
| **swift-code-review** | Concurrency safety, error handling, memory management, and common mistakes |
| **swiftui-code-review** | View composition, state management, performance, and accessibility |
| **swiftdata-code-review** | Model design, queries, concurrency, and migrations |
| **healthkit-code-review** | Authorization patterns, query usage, background delivery, and data types |
| **cloudkit-code-review** | Container setup, record handling, subscriptions, and sharing |
| **widgetkit-code-review** | Timeline management, view composition, configurable intents, and performance |
| **watchos-code-review** | App lifecycle, complications, WatchConnectivity, and performance constraints |
| **app-intents-code-review** | Intent structure, entities, shortcuts, and parameters |
| **combine-code-review** | Memory leaks, operator misuse, and error handling |
| **urlsession-code-review** | Async/await patterns, request building, error handling, and caching |
| **swift-testing-code-review** | #expect/#require usage, parameterized tests, async testing, and organization |
| **review-verification-protocol** | Mandatory verification steps to reduce false positives |

### Reference Material

Each review skill includes detailed reference documents:

**swift-code-review**: concurrency, observable patterns, error handling, common mistakes

**swiftui-code-review**: view composition, state management, performance, accessibility

**swiftdata-code-review**: model design, queries, concurrency, migrations

**healthkit-code-review**: authorization, queries, background delivery, data types

**cloudkit-code-review**: container setup, records, subscriptions, sharing

**widgetkit-code-review**: timeline, views, intents, performance

**watchos-code-review**: lifecycle, complications, connectivity, performance

**app-intents-code-review**: intent structure, entities, shortcuts, parameters

**combine-code-review**: publishers, operators, memory, error handling

**urlsession-code-review**: async networking, request building, error handling, caching

**swift-testing-code-review**: expect macro, parameterized tests, async testing, organization

## See Also

- [beagle-core](../beagle-core) - Shared workflows, verification protocol, and git commands
- [beagle marketplace](https://github.com/existential-birds/beagle) - Full plugin marketplace with 10 focused plugins
