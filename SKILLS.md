# Skill Catalog

All **82** skills in [Beagle](README.md), organized by domain. Every skill lives under `skills/<skill-name>/SKILL.md` and follows the [Agent Skills specification](https://agentskills.io/specification).

Install all skills or pick individual ones with the [skills CLI](https://skills.sh/docs/cli):

```bash
npx skills add existential-birds/beagle
npx skills add existential-birds/beagle --skill review-python
```

Once installed, compatible coding agents load relevant skills automatically or when invoked by name.

## Core Review, PR Feedback & Skill Tooling

Cross-language code review, verification, PR comment triage, LLM-artifact cleanup, and skill authoring/validation (12 skills).

| Skill | Description |
|-------|-------------|
| [`review-plan`](skills/review-plan/SKILL.md) | Review implementation plans for parallelization, TDD adherence, type/API accuracy, best practices, and security before execution |
| [`review-structure`](skills/review-structure/SKILL.md) | Repo-wide structural-maintainability review covering code-judo simplifications, 1k-line guards, branching, canonical layers, and boundary contracts |
| [`review-verification-protocol`](skills/review-verification-protocol/SKILL.md) | Mandatory verification steps for code reviews and static audits to eliminate false positives and confabulated findings |
| [`fetch-pr-feedback`](skills/fetch-pr-feedback/SKILL.md) | Fetch unresolved GitHub PR review comments, strip bot noise, format by reviewer, and triage via `receive-feedback` |
| [`receive-feedback`](skills/receive-feedback/SKILL.md) | Process external PR, LLM, or CI review feedback with verification-first rigor and isolated fixes |
| [`respond-pr-feedback`](skills/respond-pr-feedback/SKILL.md) | Post concise technical replies to unreplied PR review comments and resolve threads via GitHub REST and GraphQL APIs |
| [`review-llm-artifacts`](skills/review-llm-artifacts/SKILL.md) | Detect LLM coding artifacts across tests, dead code, abstraction, and style (changed files since main by default, or `--all`) |
| [`verify-llm-artifacts`](skills/verify-llm-artifacts/SKILL.md) | Confirm or reject findings from `review-llm-artifacts` before deletes or risky refactors |
| [`fix-llm-artifacts`](skills/fix-llm-artifacts/SKILL.md) | Apply fixes from a prior `review-llm-artifacts` run with safe/risky classification, honoring `verify-llm-artifacts` output |
| [`llm-artifacts-detection`](skills/llm-artifacts-detection/SKILL.md) | Reference catalog of detection patterns for LLM coding agent cruft across tests, dead code, over-abstraction, and style |
| [`skill-builder`](skills/skill-builder/SKILL.md) | Create and refine Agent Skills with `agentskills.io` compliance, progressive disclosure, validation, and testing |
| [`review-skill`](skills/review-skill/SKILL.md) | Review PRs that add or modify Agent Skills for structural validity, design quality, spec compliance, and repository consistency |

## Analysis, Strategy & Planning

Concept filtering, spec brainstorming, gap resolution, TDD planning, ADRs, strategy, research, and implementation comparison (12 skills).

| Skill | Description |
|-------|-------------|
| [`prfaq-beagle`](skills/prfaq-beagle/SKILL.md) | Working Backwards PRFAQ gauntlet to pass/fail a product, tool, or OSS concept before `brainstorm-beagle` |
| [`brainstorm-beagle`](skills/brainstorm-beagle/SKILL.md) | Shape a fuzzy idea into a concrete WHAT/WHY project spec at `.beagle/concepts/<slug>/spec.md` |
| [`resolve-beagle`](skills/resolve-beagle/SKILL.md) | Close Open Questions and latent gaps in a `brainstorm-beagle` spec before planning or implementation |
| [`write-plan`](skills/write-plan/SKILL.md) | Turn a finalized `brainstorm-beagle` spec into a bite-sized, TDD-driven implementation plan |
| [`quick-plan`](skills/quick-plan/SKILL.md) | Produce a bite-sized TDD implementation plan reconstructed from conversation when no spec exists |
| [`write-adr`](skills/write-adr/SKILL.md) | Extract architectural decisions from discussions and generate/verify MADR Architecture Decision Records |
| [`agent-architecture-analysis`](skills/agent-architecture-analysis/SKILL.md) | Deep per-factor codebase audit against the 12-Factor Agents methodology with file-level evidence |
| [`llm-judge`](skills/llm-judge/SKILL.md) | Compare two or more code implementations against a spec or requirements doc with structured scoring |
| [`strategy-interview`](skills/strategy-interview/SKILL.md) | Build or clarify product, company, or initiative strategy through guided conversation |
| [`strategy-review`](skills/strategy-review/SKILL.md) | Pressure-test an existing strategy document across seven dimensions and optional strategic lenses |
| [`web-research`](skills/web-research/SKILL.md) | Gather multi-angle web evidence into a written plan and cited synthesis report on disk |
| [`artifact-analysis`](skills/artifact-analysis/SKILL.md) | Scan local documents and project knowledge into a path-cited synthesis report on disk |

## Documentation & Writing Quality

Diataxis documentation auditing and AI-writing detection/humanization (3 skills).

| Skill | Description |
|-------|-------------|
| [`improve-doc`](skills/improve-doc/SKILL.md) | Audit and refactor Markdown documentation using Diataxis principles, split mixed sections, and check type balance (`--balance`) |
| [`review-ai-writing`](skills/review-ai-writing/SKILL.md) | Detect AI-generated writing patterns across docs, docstrings, commit messages, PR descriptions, and comments |
| [`humanize-beagle`](skills/humanize-beagle/SKILL.md) | Rewrite AI-generated developer text to fix inflated language, filler, and robotic tone with safe/risky controls |

## End-to-End Testing

Language-agnostic E2E test plan generation and execution, including browser testing via `agent-browser` (2 skills).

| Skill | Description |
|-------|-------------|
| [`gen-test-plan`](skills/gen-test-plan/SKILL.md) | Analyze repo, detect stack, trace changes to user-facing entry points, and generate an E2E YAML test plan |
| [`run-test-plan`](skills/run-test-plan/SKILL.md) | Execute a YAML test plan, stop on first failure, and output a structured debug prompt |

## Python

Python, FastAPI, SQLAlchemy 2.0, PostgreSQL, and pytest (5 skills).

| Skill | Description |
|-------|-------------|
| [`review-python`](skills/review-python/SKILL.md) | Comprehensive Python backend code review across FastAPI, SQLAlchemy, PostgreSQL, and pytest |
| [`fastapi-code-review`](skills/fastapi-code-review/SKILL.md) | FastAPI routing, dependency injection (`Depends`/`Annotated`), Pydantic v2 validation, and async/sync handler safety |
| [`sqlalchemy-code-review`](skills/sqlalchemy-code-review/SKILL.md) | SQLAlchemy 2.0 `Mapped` models, session lifecycle, N+1 queries, bulk DML, and safe Alembic migrations |
| [`postgres-code-review`](skills/postgres-code-review/SKILL.md) | PostgreSQL indexing strategies, JSONB operations, connection pooling, and transaction safety |
| [`pytest-code-review`](skills/pytest-code-review/SKILL.md) | `pytest-asyncio` configuration, async resource cleanup, fixture scoping, parametrize, and mock correctness |

## Frontend (React & TypeScript)

React 19, React Router v7, `@xyflow/react`, shadcn/ui, Tailwind CSS v4, Zustand v5, Vitest v4, and legacy Remix v2 maintenance (10 skills).

| Skill | Description |
|-------|-------------|
| [`review-frontend`](skills/review-frontend/SKILL.md) | Comprehensive React/TypeScript review with tech detection across React Router, React Flow, shadcn/ui, Tailwind v4, Zustand, and Vitest |
| [`react-router-v7`](skills/react-router-v7/SKILL.md) | React Router v7 best practices for data-driven routing, loaders, actions, forms, fetchers, and search params |
| [`react-router-code-review`](skills/react-router-code-review/SKILL.md) | React Router v7 (and v6.4+ Data Router) code review for data loading, mutations, error handling, and navigation |
| [`react-flow`](skills/react-flow/SKILL.md) | Implement and structure node-based UIs with `@xyflow/react` v12/v13, sub-flows, store subscriptions, and `@dagrejs/dagre` layout |
| [`react-flow-code-review`](skills/react-flow-code-review/SKILL.md) | Review `@xyflow/react` v12/v13 code for re-render traps, SSR/measurement bugs, coordinate offsets, and deprecated APIs |
| [`shadcn-code-review`](skills/shadcn-code-review/SKILL.md) | Review shadcn/ui components for CVA patterns, `asChild` or Base UI `render` composition, accessibility states, and `data-slot` usage |
| [`tailwind-v4`](skills/tailwind-v4/SKILL.md) | Tailwind CSS v4 CSS-first configuration, OKLCH design tokens, `@theme`, `@utility`, `@custom-variant` dark mode, and v3-to-v4 updates |
| [`zustand-state`](skills/zustand-state/SKILL.md) | Zustand v5 state management with curried `create<T>()(...)`, `useShallow`, `partialize`, middleware, and React Context injection |
| [`vitest-testing`](skills/vitest-testing/SKILL.md) | Vitest v4 testing patterns, `vitest.config`, mocking (`vi.mock`/`vi.hoisted`/`vi.fn`), coverage, and Browser Mode |
| [`review-remix-v2`](skills/review-remix-v2/SKILL.md) | Legacy maintenance review for EOL Remix v2 (`@remix-run/*`) apps covering routing, loaders/actions, forms, sessions, and SSR |

## Go

Go backend services, `net/http` 1.22+, BubbleTea/Wish v1 & v2 TUIs, persistence, and Prometheus instrumentation (9 skills).

| Skill | Description |
|-------|-------------|
| [`review-go`](skills/review-go/SKILL.md) | Comprehensive Go backend code review; detects BubbleTea, Wish SSH, and Prometheus and loads matching skills |
| [`review-tui`](skills/review-tui/SKILL.md) | Comprehensive BubbleTea TUI review for `charmbracelet` and `charm.land/v2` terminal applications and Wish SSH servers |
| [`go-code-review`](skills/go-code-review/SKILL.md) | Idiomatic Go review covering error handling, concurrency safety, generics, `errors.Join`, `slog`, and Go 1.22+ loop semantics |
| [`go-testing-code-review`](skills/go-testing-code-review/SKILL.md) | Go test code review for table-driven tests, `t.Helper()`, assertions, benchmarks, and coverage patterns |
| [`go-architect`](skills/go-architect/SKILL.md) | Go application architecture with `net/http` 1.22+ routing, middleware, project layout, graceful shutdown, and dependency injection |
| [`go-data-persistence`](skills/go-data-persistence/SKILL.md) | Go persistence patterns covering `sqlx`/`pgx`, Ent/GORM, connection pooling, `golang-migrate`, and transactions |
| [`bubbletea-code-review`](skills/bubbletea-code-review/SKILL.md) | BubbleTea Elm architecture, model/update/view patterns, and Lipgloss styling across v1 and `charm.land/bubbletea/v2` |
| [`wish-ssh-code-review`](skills/wish-ssh-code-review/SKILL.md) | Wish SSH server middleware, PTY/session handling, and security patterns for `charmbracelet/wish` and `charm.land/wish/v2` |
| [`prometheus-go-code-review`](skills/prometheus-go-code-review/SKILL.md) | Prometheus instrumentation in Go (`prometheus/client_golang`) for metric types, route labels, and custom registries |

## Rust

Rust Edition 2024, tokio, axum 0.7/0.8+, sqlx, serde, FFI, and macros (10 skills).

| Skill | Description |
|-------|-------------|
| [`review-rust`](skills/review-rust/SKILL.md) | Comprehensive Rust code review that detects technology areas and coordinates sub-reviews |
| [`rust-code-review`](skills/rust-code-review/SKILL.md) | Rust review for ownership, lifetimes, error handling, traits, memory ordering, lock-free patterns, and `unsafe` usage |
| [`rust-testing-code-review`](skills/rust-testing-code-review/SKILL.md) | Rust unit/integration/async tests, `tokio::test`, mocking, property testing, `loom`/Miri concurrency tests, and `#[expect]` |
| [`rust-best-practices`](skills/rust-best-practices/SKILL.md) | Idiomatic, performant, safe Rust authoring, API design, Cargo workspace lints/features, and Rust Edition 2024 migration |
| [`axum-code-review`](skills/axum-code-review/SKILL.md) | Axum web framework review for routing, extractors (`State`, `Path`, `Query`, `Json`), Tower middleware, and axum 0.7/0.8+ |
| [`tokio-async-code-review`](skills/tokio-async-code-review/SKILL.md) | Tokio async runtime tasks, synchronization primitives, channels, cancellation safety, and runtime configuration |
| [`sqlx-code-review`](skills/sqlx-code-review/SKILL.md) | Compile-time `sqlx` query checking, connection pools, migrations, offline mode, and PostgreSQL usage |
| [`serde-code-review`](skills/serde-code-review/SKILL.md) | Serde derive patterns, enum representations, custom `Serialize`/`Deserialize` impls, and format pitfalls |
| [`ffi-code-review`](skills/ffi-code-review/SKILL.md) | Rust FFI type safety, `#[repr(C)]` layout, `CStr`/`CString`, callbacks, atomics, and `unsafe` boundary correctness |
| [`macros-code-review`](skills/macros-code-review/SKILL.md) | Rust `macro_rules!` hygiene, fragment specifiers, compile-time impact, and procedural/derive macro patterns |

## Elixir & Phoenix

Elixir 1.17–1.18, Phoenix 1.8, LiveView 1.1+, ExUnit, BEAM performance/security, and ExDoc (8 skills).

| Skill | Description |
|-------|-------------|
| [`review-elixir`](skills/review-elixir/SKILL.md) | Comprehensive Elixir and Phoenix codebase review with Mix linter gates and technology detection |
| [`phoenix-code-review`](skills/phoenix-code-review/SKILL.md) | Phoenix controller patterns, context boundaries, Phoenix 1.8 `Scope`, routing pipelines, and plugs |
| [`liveview-code-review`](skills/liveview-code-review/SKILL.md) | Phoenix LiveView lifecycle, assigns/streams (`stream_async`), `.heex` templates, LiveComponents, and security |
| [`exunit-code-review`](skills/exunit-code-review/SKILL.md) | ExUnit async safety, Ecto Sandbox, boundary mocking with `Req.Test` and `Mox`, and test adapters |
| [`elixir-performance-review`](skills/elixir-performance-review/SKILL.md) | BEAM performance review for GenServer bottlenecks, binary memory, ETS concurrency, and task supervision |
| [`elixir-security-review`](skills/elixir-security-review/SKILL.md) | Elixir/BEAM security review for code injection, atom exhaustion, secret handling, and process exposure |
| [`elixir-writing-docs`](skills/elixir-writing-docs/SKILL.md) | Authoring Elixir documentation with `@moduledoc`, `@doc`, `@typedoc`, `@spec`, doctests, and ExDoc cross-references |
| [`exdoc-config`](skills/exdoc-config/SKILL.md) | Configuring ExDoc in `mix.exs` including extras, groups, cheatsheets, livebooks, and annotations |

## iOS & Swift

Swift 6.2 concurrency, SwiftUI, SwiftData, Swift Testing, animations, and Apple system frameworks (11 skills).

| Skill | Description |
|-------|-------------|
| [`review-ios`](skills/review-ios/SKILL.md) | Comprehensive iOS, iPadOS, watchOS, and SwiftUI review covering concurrency, networking, testing, animations, and frameworks |
| [`swift-code-review`](skills/swift-code-review/SKILL.md) | Swift 6/6.2 concurrency safety, actor isolation, `Sendable`, `@Observable`, error handling, and memory management |
| [`swiftui-code-review`](skills/swiftui-code-review/SKILL.md) | SwiftUI view composition, `@Observable`/`@State`/`@Bindable` state management, performance, and accessibility |
| [`swiftdata-code-review`](skills/swiftdata-code-review/SKILL.md) | SwiftData `@Model` design, `#Predicate` queries, `@ModelActor` concurrency, `#Unique`, and `VersionedSchema` migrations |
| [`swift-testing-code-review`](skills/swift-testing-code-review/SKILL.md) | Swift Testing (`@Test`, `@Suite`, `#expect`/`#require`, parameterized, async, and exit tests) |
| [`ios-animation-code-review`](skills/ios-animation-code-review/SKILL.md) | iOS animation correctness, performance, Reduce Motion accessibility, `PhaseAnimator`, transitions, and UIKit/Core Animation |
| [`app-intents-code-review`](skills/app-intents-code-review/SKILL.md) | Apple App Intents structure, `@AppIntent(schema:)`, `AppEntity`, `AppShortcutsProvider`, queries, and `@Parameter` |
| [`cloudkit-code-review`](skills/cloudkit-code-review/SKILL.md) | CloudKit containers, records, `CKSyncEngine`, subscriptions, `CKAsset`, and `CKShare` sharing patterns |
| [`healthkit-code-review`](skills/healthkit-code-review/SKILL.md) | HealthKit authorization, `HKSampleQueryDescriptor` async queries, `HKObserverQuery` background delivery, and data types |
| [`widgetkit-code-review`](skills/widgetkit-code-review/SKILL.md) | WidgetKit `TimelineProvider`, `ControlWidget`, interactive `Button(intent:)` views, configurable intents, and memory limits |
| [`watchos-code-review`](skills/watchos-code-review/SKILL.md) | watchOS app lifecycle, `WKApplicationDelegate`, WidgetKit complications, `WCSession`, Always-On, and workouts |
