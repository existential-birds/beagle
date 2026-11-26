# beagle

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/existential-birds/beagle)

![Apollo 10 astronaut Thomas P. Stafford pats the nose of a stuffed Snoopy](assets/Stafford_and_Snoopy.jpg)

*Image: NASA, Public Domain. [Source](https://www.nasa.gov/multimedia/imagegallery/image_feature_572.html)*

Beagle is a curated [Agent Skills](https://agentskills.io/specification) repository with **82** framework-aware code review, planning, documentation, testing, and architectural analysis skills for any compatible coding agent. Skills cover Python, Go, Rust, Elixir, React/TypeScript, and iOS/Swift.

Install for any compatible agent with [`npx skills add existential-birds/beagle`](https://skills.sh/docs/cli). Once installed, your agent loads the right skill automatically, or you can invoke one by name (for example `review-python`).

## Installation

**Prerequisites:**
- A coding agent that supports [Agent Skills](https://agentskills.io)
- [agent-browser](https://github.com/vercel-labs/agent-browser) for the `run-test-plan` skill (optional)

Install with the [skills CLI](https://skills.sh/docs/cli):

```bash
# Install all 82 skills interactively
npx skills add existential-birds/beagle

# Preview available skills without installing
npx skills add existential-birds/beagle --list

# Install a single skill (or install globally with -g)
npx skills add existential-birds/beagle --skill review-python
```

Skills are stored in flat `skills/<skill-name>/SKILL.md` directories so repository paths match the installed `.agents/skills/<skill-name>/` layout.

## Domains

All 82 skills are organized into 10 domains in the [full catalog](SKILLS.md):

| Domain | Count | Coverage |
|--------|------:|----------|
| [Core Review, PR Feedback & Skill Tooling](SKILLS.md#core-review-pr-feedback--skill-tooling) | 12 | Plan/structure review, verification protocol, PR feedback triage, LLM-artifact cleanup, skill authoring & review |
| [Analysis, Strategy & Planning](SKILLS.md#analysis-strategy--planning) | 12 | PRFAQ filter, brainstorming specs, gap resolution, TDD planning, ADRs, 12-Factor Agents, strategy, research, LLM-as-judge |
| [Documentation & Writing Quality](SKILLS.md#documentation--writing-quality) | 3 | Diataxis auditing & type balance (`improve-doc`), AI-writing detection (`review-ai-writing`) & humanization |
| [End-to-End Testing](SKILLS.md#end-to-end-testing) | 2 | Stack-aware E2E YAML test plan generation and stop-on-first-failure execution |
| [Python](SKILLS.md#python) | 5 | Python backend review, FastAPI, SQLAlchemy 2.0, PostgreSQL, pytest |
| [Frontend (React & TypeScript)](SKILLS.md#frontend-react--typescript) | 10 | React/TS review, React Router v7, `@xyflow/react`, shadcn/ui, Tailwind v4, Zustand v5, Vitest v4, legacy Remix v2 maintenance |
| [Go](SKILLS.md#go) | 9 | Go backend review, BubbleTea v1/v2 TUIs, `net/http` architecture, persistence, Wish SSH, Prometheus |
| [Rust](SKILLS.md#rust) | 10 | Rust Edition 2024 review & best practices, tokio, axum, sqlx, serde, FFI, macros |
| [Elixir & Phoenix](SKILLS.md#elixir--phoenix) | 8 | Elixir/Phoenix 1.8 review, LiveView, ExUnit, BEAM performance & security, ExDoc |
| [iOS & Swift](SKILLS.md#ios--swift) | 11 | iOS/Swift 6.2 review, SwiftUI, SwiftData, Swift Testing, animations, App Intents, CloudKit, HealthKit, WidgetKit, watchOS |

## Key skills

Your agent discovers every skill automatically; these are the main entry points by workflow. See the [full catalog](SKILLS.md) for all 82 skills.

**Code review** — `review-python`, `review-frontend`, `review-go`, `review-tui`, `review-rust`, `review-elixir`, `review-ios`, `review-remix-v2` (legacy Remix v2 maintenance).

**PR feedback & structure** — `fetch-pr-feedback`, `receive-feedback`, `respond-pr-feedback`, `review-plan`, `review-structure`.

**LLM artifacts** — `review-llm-artifacts`, `verify-llm-artifacts`, `fix-llm-artifacts`.

**Docs & writing** — `improve-doc`, `review-ai-writing`, `humanize-beagle`.

**Analysis & planning** — `prfaq-beagle`, `brainstorm-beagle`, `resolve-beagle`, `write-plan`, `quick-plan`, `write-adr`, `llm-judge`, `strategy-interview`, `web-research`, `artifact-analysis`.

**Testing** — `gen-test-plan`, `run-test-plan`.

**Skill tooling** — `skill-builder`, `review-skill`.
