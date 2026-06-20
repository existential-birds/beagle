# Skill Catalog

Every skill in the [beagle](README.md) Agent Skills marketplace, grouped by plugin. Each plugin's own README has fuller descriptions and install notes; this page is the at-a-glance index.

Skills are invoked automatically by any compatible coding agent, or run directly by name (for example `review-python`). The deprecated `beagle-ai` plugin is not listed.

## beagle-core

Shared workflows, verification, git, and skill tooling.

| Skill | Description |
|-------|-------------|
| `commit-push` | Commit and push local changes |
| `create-pr` | Open a PR with a standardized description |
| `gen-release-notes` | Generate release notes since a tag |
| `review-plan` | Review an implementation plan before execution |
| `review-structure` | Repo-wide structural-maintainability review |
| `review-llm-artifacts` | Detect LLM coding artifacts across tests, dead code, abstraction, and style |
| `verify-llm-artifacts` | Confirm or reject artifact findings before deletes |
| `fix-llm-artifacts` | Apply fixes from a review-llm-artifacts run (safe/risky) |
| `receive-feedback` | Process external review feedback, verifying claims first |
| `fetch-pr-feedback` | Fetch unresolved PR review comments and evaluate them |
| `respond-pr-feedback` | Reply to PR review comments after fixes |
| `skill-builder` | Create Agent Skills with best practices and validation |
| `review-skill` | Review PRs that add or modify Agent Skills |
| `subagent-prompt` | Hand off the session to a fresh orchestrator-plus-subagents session |
| `prompt-improver` | Optimize prompts for code-related tasks |
| `llm-artifacts-detection` | Reference: detection patterns for LLM coding artifacts |
| `review-feedback-schema` | Reference: schema for tracking review outcomes |
| `review-skill-improver` | Reference: suggest review-skill improvements from feedback logs |
| `review-verification-protocol` | Reference: mandatory verification steps for reviews |

## beagle-python

Python, FastAPI, SQLAlchemy, PostgreSQL, pytest.

| Skill | Description |
|-------|-------------|
| `review-python` | Comprehensive Python/FastAPI code review |
| `python-code-review` | Type safety, async patterns, error handling |
| `fastapi-code-review` | Routing, dependency injection, validation, async handlers |
| `sqlalchemy-code-review` | Sessions, relationships, N+1 queries, migrations |
| `postgres-code-review` | Indexing, JSONB, connection pooling, transactions |
| `pytest-code-review` | Async tests, fixtures, parametrize, mocking |
| `review-verification-protocol` | Reference: mandatory verification steps for reviews |

## beagle-go

Go, BubbleTea, Wish SSH, Prometheus.

| Skill | Description |
|-------|-------------|
| `review-go` | Comprehensive Go backend review (detects BubbleTea, Wish, Prometheus) |
| `review-tui` | BubbleTea TUI review (Elm architecture, Lipgloss) |
| `go-code-review` | Idiomatic patterns, error handling, concurrency safety |
| `go-testing-code-review` | Table-driven tests, assertions, coverage |
| `go-architect` | App architecture, routing, project layout, DI |
| `go-web-expert` | Production-quality Go web development persona |
| `go-concurrency-web` | Worker pools, rate limiting, race-safe shared state |
| `go-data-persistence` | SQL, ORMs, pooling, migrations, transactions |
| `go-middleware` | Context propagation, slog, error handling, recovery |
| `bubbletea-code-review` | Model/update/view patterns and Lipgloss styling |
| `wish-ssh-code-review` | SSH middleware, session handling, security |
| `prometheus-go-code-review` | Metric types, labels, instrumentation patterns |
| `review-verification-protocol` | Reference: mandatory verification steps for reviews |

## beagle-rust

Rust, tokio, axum, sqlx, serde.

| Skill | Description |
|-------|-------------|
| `review-rust` | Comprehensive Rust review across detected tech areas |
| `rust-code-review` | Ownership, borrowing, lifetimes, traits, unsafe |
| `rust-testing-code-review` | Unit/integration/async tests, mocking, property tests |
| `rust-best-practices` | Idiomatic Rust development guidance |
| `rust-project-setup` | Scaffolding new projects, Cargo.toml, CI, workspaces |
| `axum-code-review` | Routing, extractors, middleware, state, errors |
| `tokio-async-code-review` | Tasks, sync primitives, channels, runtime config |
| `sqlx-code-review` | Compile-time queries, pools, migrations, Postgres |
| `serde-code-review` | Derive patterns, enum representations, custom impls |
| `ffi-code-review` | Type safety and unsafe boundary correctness |
| `macros-code-review` | Macro hygiene, fragments, proc-macro patterns |
| `review-verification-protocol` | Reference: mandatory verification steps for reviews |

## beagle-elixir

Elixir, Phoenix, LiveView, ExUnit, ExDoc.

| Skill | Description |
|-------|-------------|
| `review-elixir` | Comprehensive Elixir/Phoenix review |
| `elixir-code-review` | Idiomatic patterns, OTP basics, documentation |
| `phoenix-code-review` | Controllers, context boundaries, routing, plugs |
| `liveview-code-review` | Lifecycle, assigns/streams, components, security |
| `exunit-code-review` | Test patterns and boundary mocking with Mox |
| `elixir-performance-review` | GenServer bottlenecks, memory, concurrency |
| `elixir-security-review` | Code injection, atom exhaustion, secret handling |
| `elixir-docs-review` | @moduledoc/@doc/@spec coverage and doctests |
| `elixir-writing-docs` | Writing Elixir docs with metadata and cross-refs |
| `exdoc-config` | Configure ExDoc generation |
| `review-verification-protocol` | Reference: mandatory verification steps for reviews |

## beagle-react

React, React Flow, shadcn/ui, Tailwind, Vitest, Remix v2.

| Skill | Description |
|-------|-------------|
| `review-frontend` | Comprehensive React/TypeScript review |
| `review-remix-v2` | Comprehensive Remix v2 review |
| `react-router-v7` | Data-driven routing best practices |
| `react-router-code-review` | Data loading, mutations, navigation |
| `react-flow` | Workflow visualization with custom nodes and edges |
| `react-flow-implementation` | Build node-based UIs with @xyflow/react |
| `react-flow-advanced` | Sub-flows, drag-and-drop, undo/redo |
| `react-flow-architecture` | Designing node-based UI architecture |
| `react-flow-code-review` | React Flow anti-patterns and performance |
| `dagre-react-flow` | Automatic graph layout with dagre |
| `shadcn-ui` | shadcn/ui component patterns with Radix + Tailwind |
| `shadcn-code-review` | CVA patterns, composition, accessibility |
| `tailwind-v4` | Tailwind v4 CSS-first config and design tokens |
| `ai-elements` | Vercel AI Elements for workflow UI |
| `zustand-state` | Zustand state management |
| `vitest-testing` | Vitest patterns and best practices |
| `remix-v2-routing` | Flat-routes v2 conventions and layouts |
| `remix-v2-routing-review` | Route naming, layouts, resource-route shape |
| `remix-v2-data-flow` | Loaders, actions, deferred data, revalidation |
| `remix-v2-data-flow-review` | Mutations-in-loader, validation, return helpers |
| `remix-v2-forms` | Form submissions, optimistic UI, uploads |
| `remix-v2-forms-review` | Manual-fetch mutations, pending state, intents |
| `remix-v2-meta-sessions` | Meta/SEO, sessions, auth, CSRF |
| `remix-v2-meta-sessions-review` | v1 meta shape, cookie security, auth layer |
| `remix-v2-perf-ssr` | Performance, streaming, caching, server/client split |
| `remix-v2-perf-ssr-review` | Caching headers, hydration, prefetch hygiene |
| `remix-v2-error-boundaries-review` | Unified ErrorBoundary and v1 holdovers |
| `review-verification-protocol` | Reference: mandatory verification steps for reviews |

## beagle-ios

Swift, SwiftUI, SwiftData, iOS frameworks.

| Skill | Description |
|-------|-------------|
| `review-ios` | Comprehensive iOS/SwiftUI review |
| `swift-code-review` | Concurrency safety, error handling, memory |
| `swiftui-code-review` | View composition, state, performance, accessibility |
| `swiftdata-code-review` | Model design, queries, concurrency, migrations |
| `swift-testing-code-review` | #expect/#require, parameterized and async tests |
| `combine-code-review` | Memory leaks, operator misuse, error handling |
| `urlsession-code-review` | Async networking, requests, caching, background |
| `app-intents-code-review` | Intents, entities, shortcuts, parameters |
| `cloudkit-code-review` | Containers, records, subscriptions, sharing |
| `healthkit-code-review` | Authorization, queries, background delivery |
| `widgetkit-code-review` | Timelines, view composition, configurable intents |
| `watchos-code-review` | Lifecycle, complications, WatchConnectivity |
| `ios-animation-design` | Plan and spec iOS animations |
| `ios-animation-implementation` | Write SwiftUI/Core Animation/UIKit animations |
| `ios-animation-code-review` | Animation correctness, performance, accessibility |
| `review-verification-protocol` | Reference: mandatory verification steps for reviews |

## beagle-docs

Documentation quality and AI-writing detection (Diataxis).

| Skill | Description |
|-------|-------------|
| `improve-doc` | Analyze and improve existing docs (Diataxis) |
| `draft-docs` | Generate first-draft docs from code analysis |
| `ensure-docs` | Check doc coverage and fill gaps interactively |
| `review-ai-writing` | Detect AI-writing patterns in developer text |
| `humanize-beagle` | Rewrite AI-generated text to sound human |
| `docs-style` | Core documentation writing principles |
| `tutorial-docs` | Patterns for learning-oriented tutorials |
| `howto-docs` | Patterns for task-oriented how-to guides |
| `reference-docs` | Patterns for API and reference docs |
| `explanation-docs` | Patterns for conceptual explanation docs |

## beagle-analysis

Brainstorming, ADRs, strategy, LLM-as-judge, planning, research.

| Skill | Description |
|-------|-------------|
| `brainstorm-beagle` | Shape a fuzzy idea into a concrete project spec |
| `resolve-beagle` | Close open questions and gaps in a brainstorm spec |
| `prfaq-beagle` | Working Backwards PRFAQ filter (pass/fail a concept) |
| `write-plan` | Turn a brainstorm spec into a TDD implementation plan |
| `quick-plan` | TDD plan with no spec, reconstructed from the conversation |
| `write-adr` | Generate ADRs from the current session |
| `adr-writing` | Write/format an ADR using the MADR template |
| `adr-decision-extraction` | Mine a conversation for architectural decisions |
| `agent-architecture-analysis` | Audit a codebase against 12-Factor Agents |
| `strategy-interview` | Build strategy through guided conversation |
| `strategy-review` | Pressure-test an existing strategy document |
| `web-research` | Parallel web research with a cited synthesis report |
| `artifact-analysis` | Cited, structured read of local docs |
| `llm-judge` | Compare 2+ implementations against a spec with scoring |

## beagle-testing

Test plan generation and execution.

| Skill | Description |
|-------|-------------|
| `gen-test-plan` | Detect stack, trace changes, generate an E2E YAML test plan |
| `run-test-plan` | Execute a YAML test plan, stop on first failure |
