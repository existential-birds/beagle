# Spec Document Template

Use this template when writing the final spec document. Save to `docs/specs/YYYY-MM-DD-<topic>.md`.

## Template

```markdown
# [Project Name]

**Created:** [YYYY-MM-DD]
**Status:** Ready for planning

## Core Value

[ONE sentence — the single most important thing this project delivers. If everything else fails, this must work. Drives prioritization when tradeoffs arise.]

## Problem Statement

[What problem exists, who has it, and why it matters now. 2-4 sentences. Include what people do today without this (the status quo) and why that's insufficient.]

## Requirements

### Must Have

[Concrete, testable, user-centric. These define v1 — the project isn't done without them.]

- [Requirement — observable, verifiable outcome]
- [Requirement — observable, verifiable outcome]

### Should Have

[Important but not blocking v1. Build these if time allows, defer if not.]

- [Requirement — observable, verifiable outcome]

### Out of Scope

[Explicit exclusions with reasoning. Prevents scope creep and re-litigation.]

- [Exclusion] — [why not]
- [Exclusion] — [why not]

## Constraints

[Hard limits on the solution space. Each must include WHY — constraints without rationale get questioned.]

- **[Type]:** [What] — [Why]
- **[Type]:** [What] — [Why]

Common types: Tech stack, Timeline, Compatibility, Performance, Security, Regulatory, Team

## Key Decisions

[Significant choices made during brainstorming. Captures the reasoning so downstream work doesn't relitigate.]

### [Decision Area]
- **Decision:** [What was decided]
- **Alternatives considered:** [What else was on the table]
- **Rationale:** [Why this choice]

### [Decision Area]
- **Decision:** [What was decided]
- **Alternatives considered:** [What else was on the table]
- **Rationale:** [Why this choice]

## Reference Points

[Inspiration, external docs, "I want it like X" moments, specific behaviors or patterns the user referenced. Not implementation instructions — direction and taste.]

[If none: "No specific references — open to standard approaches."]

## Open Questions

[Unresolved items that need research or future discussion before or during implementation. Flag what's unknown so downstream systems can investigate.]

- [Question — what needs to be figured out and why it matters]

[If none: "No open questions — spec is self-contained."]

## Future Considerations

[Ideas that emerged during brainstorming but belong in later phases or separate projects. Captured so they're not lost, explicitly deferred.]

[If none: "None — brainstorming stayed within scope."]
```

## Guidelines

**Core Value:**
- Rarely more than one sentence
- Not a tagline — a prioritization tool
- Should resolve ambiguity when two requirements compete

**Requirements — quality checklist:**
- Can someone verify this was met? (testable)
- Does it describe what the user experiences? (user-centric)
- Is it one thing, not a bundle? (atomic)
- Could it be interpreted two ways? If so, pick one.

**Requirements — what NOT to write:**
- Implementation tasks disguised as requirements ("Create a REST API")
- Vague qualities ("Good performance", "Modern UI")
- Compound requirements ("Users can search AND filter AND sort")
- Technical jargon the user didn't use

**Constraints vs Key Decisions:**
- Constraint: imposed externally, limits the solution space ("Must run on iOS 16+")
- Key Decision: chosen during brainstorming, shapes the direction ("Mobile-first, desktop secondary")

**Key Decisions — when to record:**
- When 2+ viable options existed and one was chosen
- When the user expressed a strong preference
- When a direction was explicitly rejected (alternatives section)
- When the user said "you decide" — record it as "Claude's discretion" with the area

**Reference Points — good content:**
- "I want the search to feel like Spotlight — instant, forgiving of typos"
- "The onboarding should be like Linear's — minimal, progressive, no tutorial walls"
- External docs the user wants to be followed: `path/to/spec.md` with what it covers

**Future Considerations — the redirect:**
When an idea is captured here during brainstorming, it was explicitly deferred. Note what it is and why it's deferred (too complex for v1, depends on other work, nice-to-have, etc.).

## Examples

### Example 1: Developer Tool

```markdown
# Logwatch — Spec

**Created:** 2026-03-26
**Status:** Ready for planning

## Core Value

Developers see exactly what happened in production without leaving their terminal.

## Problem Statement

When a production incident occurs, developers switch between Grafana, CloudWatch, and Slack to piece together what happened. This context-switching wastes 10-15 minutes per incident and often means important log lines are missed. Logwatch brings structured log tailing and search into the terminal where developers already work.

## Requirements

### Must Have

- User can tail logs from multiple services simultaneously in a split-pane view
- User can search logs by time range, service name, and log level
- User can bookmark a log line and return to it later in the same session
- Log output is syntax-highlighted by log level (error=red, warn=yellow, info=default)
- User can filter to a single service from the multi-service view without losing scroll position
- Connection drops are detected within 5 seconds and auto-reconnected

### Should Have

- User can save a search query and replay it in a future session
- User can export a time range of logs to a file
- User can share a permalink to a specific log line with teammates

### Out of Scope

- Alerting or notification — this is a viewing tool, not a monitoring tool
- Log aggregation or storage — reads from existing infrastructure
- Dashboard creation — Grafana already handles this well
- Mobile support — terminal-first, desktop only

## Constraints

- **Compatibility:** Must work with CloudWatch Logs and Datadog — these are our two log backends
- **Performance:** Must handle 10k log lines/second without dropping frames
- **Distribution:** Single binary, no runtime dependencies — devs install via brew or curl
- **Auth:** Must support SSO via existing Okta setup — no separate credentials

## Key Decisions

### Primary interface
- **Decision:** TUI with vim-style keybindings
- **Alternatives considered:** Web UI, VS Code extension, plain CLI with flags
- **Rationale:** Developers are already in the terminal during incidents. TUI keeps them in flow. Vim bindings match muscle memory for the team.

### Multi-service display
- **Decision:** Vertical split panes, one per service, synchronized by timestamp
- **Alternatives considered:** Interleaved single stream with service prefixes, tabbed view per service
- **Rationale:** Side-by-side makes cross-service correlation visual and immediate. Interleaved gets noisy above 3 services. Tabs hide context.

## Reference Points

- "I want it to feel like `lazygit` — fast, keyboard-driven, just works"
- "The search should be like ripgrep — regex by default, fast enough to feel instant"
- Okta SSO integration spec: `docs/infra/sso-integration.md` (sections 2-3 cover token flow)

## Open Questions

- Can we get sub-second latency from CloudWatch's API, or do we need a local cache layer? Needs benchmarking.
- Datadog's log query API has rate limits — need to verify they're sufficient for real-time tailing.

## Future Considerations

- Alerting integration (pipe to PagerDuty) — separate project, depends on core being stable
- Log annotation ("this line caused the outage") — great idea, v2 feature
- Team sharing of saved queries — requires backend, save for later
```

### Example 2: Minimal Project

```markdown
# Markdown Link Checker — Spec

**Created:** 2026-03-26
**Status:** Ready for planning

## Core Value

Broken links in docs are caught before they reach readers.

## Problem Statement

Our documentation has 200+ external links. We discover broken links when users report them, sometimes weeks after the target page moved. An automated checker in CI catches these before merge.

## Requirements

### Must Have

- Scans all `.md` files in a directory recursively
- Checks HTTP status of external links (follows redirects up to 3 hops)
- Reports broken links with file path, line number, URL, and HTTP status
- Exit code 1 if any links are broken (for CI gating)
- Completes scan of 200 files with 500 links in under 60 seconds

### Should Have

- User can exclude URLs by pattern (regex allowlist)
- User can set a custom timeout per link

### Out of Scope

- Checking anchor fragments (#section-name) — parsing target HTML is too complex for v1
- Fixing broken links — detection only
- Checking internal cross-file links — separate concern

## Constraints

- **CI:** Must run in GitHub Actions — no external service dependencies
- **Language:** Team prefers Go for CLI tools — aligns with existing tooling

## Key Decisions

### Concurrency model
- **Decision:** Concurrent link checking with configurable parallelism
- **Alternatives considered:** Sequential checking (simple but slow), unbounded parallelism (risks rate limiting)
- **Rationale:** Need to finish in 60s but also avoid hammering external servers. Default 10 concurrent, configurable via flag.

## Reference Points

- "Like `markdown-link-check` npm package but faster and no Node dependency"

## Open Questions

- Should rate-limited responses (429) be treated as broken or retried? Need to decide retry policy.

## Future Considerations

- Anchor fragment checking — worth a follow-up if teams request it
- Cache layer for recently-checked URLs — would speed up repeated CI runs
```
