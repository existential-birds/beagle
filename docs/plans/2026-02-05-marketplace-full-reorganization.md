# Marketplace Full Reorganization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Split the monolithic beagle plugin into 10 focused marketplace plugins so users install only what they need. Remove the monolith `beagle` option entirely.

**Architecture:** Each domain plugin is a self-contained directory under `plugins/` with its own `.claude-plugin/plugin.json`, `skills/`, and `commands/`. Shared skills (like `review-verification-protocol`) are copied into each plugin that needs them. The root marketplace.json lists all plugins. Root-level `skills/` and `commands/` directories are removed after extraction.

**Tech Stack:** Claude Code plugin system, marketplace.json, plugin.json manifests

---

## Plugin Assignment Map

This is the authoritative mapping of every skill and command to its target plugin.

### beagle-core (shared workflows)

**Skills:**
- `review-verification-protocol`
- `receive-feedback`
- `review-feedback-schema`
- `review-skill-improver`
- `llm-artifacts-detection`
- `github-projects`
- `docling`
- `sqlite-vec`

**Commands:**
- `commit-push.md`
- `create-pr.md`
- `gen-release-notes.md`
- `fetch-pr-feedback.md`
- `respond-pr-feedback.md`
- `receive-feedback.md`
- `review-llm-artifacts.md`
- `fix-llm-artifacts.md`
- `prompt-improver.md`
- `skill-builder.md`
- `review-plan.md`

### beagle-elixir (already done)

**Skills:** `elixir-code-review`, `elixir-security-review`, `elixir-performance-review`, `phoenix-code-review`, `liveview-code-review`, `exunit-code-review`, `review-verification-protocol` (copy)

**Commands:** `review-elixir.md`

### beagle-python

**Skills:** `python-code-review`, `fastapi-code-review`, `sqlalchemy-code-review`, `postgres-code-review`, `pytest-code-review`, `review-verification-protocol` (copy)

**Commands:** `review-python.md`

### beagle-go

**Skills:** `go-code-review`, `go-testing-code-review`, `bubbletea-code-review`, `wish-ssh-code-review`, `prometheus-go-code-review`, `review-verification-protocol` (copy)

**Commands:** `review-go.md`, `review-tui.md`

### beagle-ios

**Skills:** `swift-code-review`, `swift-testing-code-review`, `swiftui-code-review`, `swiftdata-code-review`, `urlsession-code-review`, `healthkit-code-review`, `cloudkit-code-review`, `watchos-code-review`, `widgetkit-code-review`, `app-intents-code-review`, `combine-code-review`, `review-verification-protocol` (copy)

**Commands:** `review-ios.md`

### beagle-react

**Skills:** `react-flow`, `react-flow-advanced`, `react-flow-architecture`, `react-flow-code-review`, `react-flow-implementation`, `react-router-code-review`, `react-router-v7`, `shadcn-code-review`, `shadcn-ui`, `tailwind-v4`, `vitest-testing`, `zustand-state`, `dagre-react-flow`, `ai-elements`, `review-verification-protocol` (copy)

**Commands:** `review-frontend.md`

### beagle-ai

**Skills:** `pydantic-ai-agent-creation`, `pydantic-ai-common-pitfalls`, `pydantic-ai-dependency-injection`, `pydantic-ai-model-integration`, `pydantic-ai-testing`, `pydantic-ai-tool-system`, `langgraph-architecture`, `langgraph-code-review`, `langgraph-implementation`, `deepagents-architecture`, `deepagents-code-review`, `deepagents-implementation`, `vercel-ai-sdk`

**Commands:** (none)

### beagle-docs

**Skills:** `docs-style`, `tutorial-docs`, `howto-docs`, `reference-docs`, `explanation-docs`

**Commands:** `draft-docs.md`, `ensure-docs.md`, `improve-doc.md`

### beagle-analysis

**Skills:** `12-factor-apps`, `agent-architecture-analysis`, `llm-judge`, `adr-decision-extraction`, `adr-writing`

**Commands:** `12-factor-apps-analysis.md`, `llm-judge.md`, `write-adr.md`

### beagle-testing

**Skills:** (none)

**Commands:** `gen-test-plan.md`, `run-test-plan.md`

---

## Task 1: Create beagle-core Plugin

**Files:**
- Create: `plugins/beagle-core/.claude-plugin/plugin.json`
- Create: `plugins/beagle-core/skills/` (8 skill directories, copied from root)
- Create: `plugins/beagle-core/commands/` (11 command files, copied from root)

**Step 1: Create plugin directory structure**

```bash
mkdir -p plugins/beagle-core/.claude-plugin
mkdir -p plugins/beagle-core/skills
mkdir -p plugins/beagle-core/commands
```

**Step 2: Create plugin.json**

Create `plugins/beagle-core/.claude-plugin/plugin.json`:

```json
{
  "name": "beagle-core",
  "description": "Shared code review workflows, verification protocol, git commands, and feedback handling. Recommended as a base for all beagle plugins.",
  "version": "1.0.0",
  "author": {
    "name": "Existential Birds, LLC",
    "email": "tech@existentialbirds.com"
  },
  "repository": "https://github.com/existential-birds/beagle",
  "keywords": [
    "code-review",
    "verification",
    "git",
    "feedback",
    "llm-artifacts"
  ]
}
```

**Step 3: Copy skills**

```bash
cp -r skills/review-verification-protocol plugins/beagle-core/skills/
cp -r skills/receive-feedback plugins/beagle-core/skills/
cp -r skills/review-feedback-schema plugins/beagle-core/skills/
cp -r skills/review-skill-improver plugins/beagle-core/skills/
cp -r skills/llm-artifacts-detection plugins/beagle-core/skills/
cp -r skills/github-projects plugins/beagle-core/skills/
cp -r skills/docling plugins/beagle-core/skills/
cp -r skills/sqlite-vec plugins/beagle-core/skills/
```

**Step 4: Copy commands**

```bash
cp commands/commit-push.md plugins/beagle-core/commands/
cp commands/create-pr.md plugins/beagle-core/commands/
cp commands/gen-release-notes.md plugins/beagle-core/commands/
cp commands/fetch-pr-feedback.md plugins/beagle-core/commands/
cp commands/respond-pr-feedback.md plugins/beagle-core/commands/
cp commands/receive-feedback.md plugins/beagle-core/commands/
cp commands/review-llm-artifacts.md plugins/beagle-core/commands/
cp commands/fix-llm-artifacts.md plugins/beagle-core/commands/
cp commands/prompt-improver.md plugins/beagle-core/commands/
cp commands/skill-builder.md plugins/beagle-core/commands/
cp commands/review-plan.md plugins/beagle-core/commands/
```

**Step 5: Update skill references in copied commands**

In all copied commands under `plugins/beagle-core/commands/`, replace `beagle:` skill references with `beagle-core:` for skills that live in beagle-core:

- `beagle:review-verification-protocol` → `beagle-core:review-verification-protocol`
- `beagle:receive-feedback` → `beagle-core:receive-feedback`
- `beagle:review-feedback-schema` → `beagle-core:review-feedback-schema`
- `beagle:review-skill-improver` → `beagle-core:review-skill-improver`
- `beagle:llm-artifacts-detection` → `beagle-core:llm-artifacts-detection`

For `review-plan.md`, the dynamic skill references (e.g. `beagle:python-code-review`) should be updated to their new plugin prefixes:
- `beagle:python-code-review` → `beagle-python:python-code-review`
- `beagle:fastapi-code-review` → `beagle-python:fastapi-code-review`
- `beagle:sqlalchemy-code-review` → `beagle-python:sqlalchemy-code-review`
- `beagle:postgres-code-review` → `beagle-python:postgres-code-review`
- `beagle:pytest-code-review` → `beagle-python:pytest-code-review`
- `beagle:react-router-code-review` → `beagle-react:react-router-code-review`
- `beagle:react-flow-code-review` → `beagle-react:react-flow-code-review`
- `beagle:shadcn-code-review` → `beagle-react:shadcn-code-review`
- `beagle:vitest-testing` → `beagle-react:vitest-testing`
- `beagle:go-code-review` → `beagle-go:go-code-review`
- `beagle:bubbletea-code-review` → `beagle-go:bubbletea-code-review`

For `fetch-pr-feedback.md` and `receive-feedback.md`:
- `beagle:receive-feedback` → `beagle-core:receive-feedback`

For `review-llm-artifacts.md`:
- `beagle:llm-artifacts-detection` → `beagle-core:llm-artifacts-detection`

For `llm-judge.md` (in beagle-analysis — but note this command is NOT in beagle-core, it's in beagle-analysis. Double-check: llm-judge command goes to beagle-analysis, not beagle-core.)

**Step 6: Verify**

```bash
ls plugins/beagle-core/skills/ | wc -l
# Expected: 8
ls plugins/beagle-core/commands/ | wc -l
# Expected: 11
```

**Step 7: Commit**

```bash
git add plugins/beagle-core/
git commit -m "feat(beagle-core): create core plugin with shared workflows"
```

---

## Task 2: Create beagle-python Plugin

**Files:**
- Create: `plugins/beagle-python/.claude-plugin/plugin.json`
- Create: `plugins/beagle-python/skills/` (6 skill directories)
- Create: `plugins/beagle-python/commands/` (1 command file)

**Step 1: Create plugin directory structure**

```bash
mkdir -p plugins/beagle-python/.claude-plugin
mkdir -p plugins/beagle-python/skills
mkdir -p plugins/beagle-python/commands
```

**Step 2: Create plugin.json**

Create `plugins/beagle-python/.claude-plugin/plugin.json`:

```json
{
  "name": "beagle-python",
  "description": "Python, FastAPI, SQLAlchemy, PostgreSQL, and pytest code review. Pairs with beagle-core for full workflow.",
  "version": "1.0.0",
  "author": {
    "name": "Existential Birds, LLC",
    "email": "tech@existentialbirds.com"
  },
  "repository": "https://github.com/existential-birds/beagle",
  "keywords": [
    "python",
    "fastapi",
    "sqlalchemy",
    "postgres",
    "pytest",
    "code-review"
  ]
}
```

**Step 3: Copy skills**

```bash
cp -r skills/python-code-review plugins/beagle-python/skills/
cp -r skills/fastapi-code-review plugins/beagle-python/skills/
cp -r skills/sqlalchemy-code-review plugins/beagle-python/skills/
cp -r skills/postgres-code-review plugins/beagle-python/skills/
cp -r skills/pytest-code-review plugins/beagle-python/skills/
cp -r skills/review-verification-protocol plugins/beagle-python/skills/
```

**Step 4: Copy command**

```bash
cp commands/review-python.md plugins/beagle-python/commands/
```

**Step 5: Update skill references in command**

In `plugins/beagle-python/commands/review-python.md`, replace:
- `beagle:python-code-review` → `beagle-python:python-code-review`
- `beagle:fastapi-code-review` → `beagle-python:fastapi-code-review`
- `beagle:sqlalchemy-code-review` → `beagle-python:sqlalchemy-code-review`
- `beagle:postgres-code-review` → `beagle-python:postgres-code-review`
- `beagle:pytest-code-review` → `beagle-python:pytest-code-review`
- `beagle:review-verification-protocol` → `beagle-python:review-verification-protocol`

Keep `beagle:pydantic-ai-common-pitfalls` → `beagle-ai:pydantic-ai-common-pitfalls` (cross-plugin reference, optional dependency).

**Step 6: Verify**

```bash
ls plugins/beagle-python/skills/ | wc -l
# Expected: 6
ls plugins/beagle-python/commands/ | wc -l
# Expected: 1
```

**Step 7: Commit**

```bash
git add plugins/beagle-python/
git commit -m "feat(beagle-python): create Python/FastAPI code review plugin"
```

---

## Task 3: Create beagle-go Plugin

**Files:**
- Create: `plugins/beagle-go/.claude-plugin/plugin.json`
- Create: `plugins/beagle-go/skills/` (6 skill directories)
- Create: `plugins/beagle-go/commands/` (2 command files)

**Step 1: Create plugin directory structure**

```bash
mkdir -p plugins/beagle-go/.claude-plugin
mkdir -p plugins/beagle-go/skills
mkdir -p plugins/beagle-go/commands
```

**Step 2: Create plugin.json**

Create `plugins/beagle-go/.claude-plugin/plugin.json`:

```json
{
  "name": "beagle-go",
  "description": "Go, BubbleTea TUI, Wish SSH, and Prometheus code review. Pairs with beagle-core for full workflow.",
  "version": "1.0.0",
  "author": {
    "name": "Existential Birds, LLC",
    "email": "tech@existentialbirds.com"
  },
  "repository": "https://github.com/existential-birds/beagle",
  "keywords": [
    "go",
    "bubbletea",
    "wish",
    "prometheus",
    "tui",
    "code-review"
  ]
}
```

**Step 3: Copy skills**

```bash
cp -r skills/go-code-review plugins/beagle-go/skills/
cp -r skills/go-testing-code-review plugins/beagle-go/skills/
cp -r skills/bubbletea-code-review plugins/beagle-go/skills/
cp -r skills/wish-ssh-code-review plugins/beagle-go/skills/
cp -r skills/prometheus-go-code-review plugins/beagle-go/skills/
cp -r skills/review-verification-protocol plugins/beagle-go/skills/
```

**Step 4: Copy commands**

```bash
cp commands/review-go.md plugins/beagle-go/commands/
cp commands/review-tui.md plugins/beagle-go/commands/
```

**Step 5: Update skill references in commands**

In `plugins/beagle-go/commands/review-go.md`, replace:
- `beagle:go-code-review` → `beagle-go:go-code-review`
- `beagle:go-testing-code-review` → `beagle-go:go-testing-code-review`
- `beagle:bubbletea-code-review` → `beagle-go:bubbletea-code-review`
- `beagle:wish-ssh-code-review` → `beagle-go:wish-ssh-code-review`
- `beagle:prometheus-go-code-review` → `beagle-go:prometheus-go-code-review`
- `beagle:review-verification-protocol` → `beagle-go:review-verification-protocol`

In `plugins/beagle-go/commands/review-tui.md`, replace:
- `beagle:go-code-review` → `beagle-go:go-code-review`
- `beagle:bubbletea-code-review` → `beagle-go:bubbletea-code-review`
- `beagle:go-testing-code-review` → `beagle-go:go-testing-code-review`
- `beagle:wish-ssh-code-review` → `beagle-go:wish-ssh-code-review`
- `beagle:review-verification-protocol` → `beagle-go:review-verification-protocol`

**Step 6: Verify**

```bash
ls plugins/beagle-go/skills/ | wc -l
# Expected: 6
ls plugins/beagle-go/commands/ | wc -l
# Expected: 2
```

**Step 7: Commit**

```bash
git add plugins/beagle-go/
git commit -m "feat(beagle-go): create Go/BubbleTea/Wish code review plugin"
```

---

## Task 4: Create beagle-ios Plugin

**Files:**
- Create: `plugins/beagle-ios/.claude-plugin/plugin.json`
- Create: `plugins/beagle-ios/skills/` (12 skill directories)
- Create: `plugins/beagle-ios/commands/` (1 command file)

**Step 1: Create plugin directory structure**

```bash
mkdir -p plugins/beagle-ios/.claude-plugin
mkdir -p plugins/beagle-ios/skills
mkdir -p plugins/beagle-ios/commands
```

**Step 2: Create plugin.json**

Create `plugins/beagle-ios/.claude-plugin/plugin.json`:

```json
{
  "name": "beagle-ios",
  "description": "Swift, SwiftUI, SwiftData, and iOS framework code review (HealthKit, CloudKit, WidgetKit, watchOS, App Intents). Pairs with beagle-core for full workflow.",
  "version": "1.0.0",
  "author": {
    "name": "Existential Birds, LLC",
    "email": "tech@existentialbirds.com"
  },
  "repository": "https://github.com/existential-birds/beagle",
  "keywords": [
    "swift",
    "swiftui",
    "swiftdata",
    "ios",
    "healthkit",
    "cloudkit",
    "widgetkit",
    "watchos",
    "code-review"
  ]
}
```

**Step 3: Copy skills**

```bash
cp -r skills/swift-code-review plugins/beagle-ios/skills/
cp -r skills/swift-testing-code-review plugins/beagle-ios/skills/
cp -r skills/swiftui-code-review plugins/beagle-ios/skills/
cp -r skills/swiftdata-code-review plugins/beagle-ios/skills/
cp -r skills/urlsession-code-review plugins/beagle-ios/skills/
cp -r skills/healthkit-code-review plugins/beagle-ios/skills/
cp -r skills/cloudkit-code-review plugins/beagle-ios/skills/
cp -r skills/watchos-code-review plugins/beagle-ios/skills/
cp -r skills/widgetkit-code-review plugins/beagle-ios/skills/
cp -r skills/app-intents-code-review plugins/beagle-ios/skills/
cp -r skills/combine-code-review plugins/beagle-ios/skills/
cp -r skills/review-verification-protocol plugins/beagle-ios/skills/
```

**Step 4: Copy command**

```bash
cp commands/review-ios.md plugins/beagle-ios/commands/
```

**Step 5: Update skill references in command**

In `plugins/beagle-ios/commands/review-ios.md`, replace all `beagle:` prefixes with `beagle-ios:`:
- `beagle:swift-code-review` → `beagle-ios:swift-code-review`
- `beagle:swiftui-code-review` → `beagle-ios:swiftui-code-review`
- `beagle:swiftdata-code-review` → `beagle-ios:swiftdata-code-review`
- `beagle:swift-testing-code-review` → `beagle-ios:swift-testing-code-review`
- `beagle:combine-code-review` → `beagle-ios:combine-code-review`
- `beagle:urlsession-code-review` → `beagle-ios:urlsession-code-review`
- `beagle:cloudkit-code-review` → `beagle-ios:cloudkit-code-review`
- `beagle:widgetkit-code-review` → `beagle-ios:widgetkit-code-review`
- `beagle:app-intents-code-review` → `beagle-ios:app-intents-code-review`
- `beagle:healthkit-code-review` → `beagle-ios:healthkit-code-review`
- `beagle:watchos-code-review` → `beagle-ios:watchos-code-review`
- `beagle:review-verification-protocol` → `beagle-ios:review-verification-protocol`

**Step 6: Verify**

```bash
ls plugins/beagle-ios/skills/ | wc -l
# Expected: 12
ls plugins/beagle-ios/commands/ | wc -l
# Expected: 1
```

**Step 7: Commit**

```bash
git add plugins/beagle-ios/
git commit -m "feat(beagle-ios): create iOS/Swift code review plugin"
```

---

## Task 5: Create beagle-react Plugin

**Files:**
- Create: `plugins/beagle-react/.claude-plugin/plugin.json`
- Create: `plugins/beagle-react/skills/` (15 skill directories)
- Create: `plugins/beagle-react/commands/` (1 command file)

**Step 1: Create plugin directory structure**

```bash
mkdir -p plugins/beagle-react/.claude-plugin
mkdir -p plugins/beagle-react/skills
mkdir -p plugins/beagle-react/commands
```

**Step 2: Create plugin.json**

Create `plugins/beagle-react/.claude-plugin/plugin.json`:

```json
{
  "name": "beagle-react",
  "description": "React, React Flow, React Router, shadcn/ui, Tailwind v4, Vitest, and Zustand code review. Pairs with beagle-core for full workflow.",
  "version": "1.0.0",
  "author": {
    "name": "Existential Birds, LLC",
    "email": "tech@existentialbirds.com"
  },
  "repository": "https://github.com/existential-birds/beagle",
  "keywords": [
    "react",
    "react-flow",
    "react-router",
    "shadcn",
    "tailwind",
    "vitest",
    "zustand",
    "typescript",
    "code-review"
  ]
}
```

**Step 3: Copy skills**

```bash
cp -r skills/react-flow plugins/beagle-react/skills/
cp -r skills/react-flow-advanced plugins/beagle-react/skills/
cp -r skills/react-flow-architecture plugins/beagle-react/skills/
cp -r skills/react-flow-code-review plugins/beagle-react/skills/
cp -r skills/react-flow-implementation plugins/beagle-react/skills/
cp -r skills/react-router-code-review plugins/beagle-react/skills/
cp -r skills/react-router-v7 plugins/beagle-react/skills/
cp -r skills/shadcn-code-review plugins/beagle-react/skills/
cp -r skills/shadcn-ui plugins/beagle-react/skills/
cp -r skills/tailwind-v4 plugins/beagle-react/skills/
cp -r skills/vitest-testing plugins/beagle-react/skills/
cp -r skills/zustand-state plugins/beagle-react/skills/
cp -r skills/dagre-react-flow plugins/beagle-react/skills/
cp -r skills/ai-elements plugins/beagle-react/skills/
cp -r skills/review-verification-protocol plugins/beagle-react/skills/
```

**Step 4: Copy command**

```bash
cp commands/review-frontend.md plugins/beagle-react/commands/
```

**Step 5: Update skill references in command**

In `plugins/beagle-react/commands/review-frontend.md`, replace:
- `beagle:react-router-code-review` → `beagle-react:react-router-code-review`
- `beagle:react-flow-code-review` → `beagle-react:react-flow-code-review`
- `beagle:shadcn-code-review` → `beagle-react:shadcn-code-review`
- `beagle:zustand-state` → `beagle-react:zustand-state`
- `beagle:tailwind-v4` → `beagle-react:tailwind-v4`
- `beagle:vitest-testing` → `beagle-react:vitest-testing`
- `beagle:review-verification-protocol` → `beagle-react:review-verification-protocol`

**Step 6: Verify**

```bash
ls plugins/beagle-react/skills/ | wc -l
# Expected: 15
ls plugins/beagle-react/commands/ | wc -l
# Expected: 1
```

**Step 7: Commit**

```bash
git add plugins/beagle-react/
git commit -m "feat(beagle-react): create React/TypeScript code review plugin"
```

---

## Task 6: Create beagle-ai Plugin

**Files:**
- Create: `plugins/beagle-ai/.claude-plugin/plugin.json`
- Create: `plugins/beagle-ai/skills/` (13 skill directories)

**Step 1: Create plugin directory structure**

```bash
mkdir -p plugins/beagle-ai/.claude-plugin
mkdir -p plugins/beagle-ai/skills
```

**Step 2: Create plugin.json**

Create `plugins/beagle-ai/.claude-plugin/plugin.json`:

```json
{
  "name": "beagle-ai",
  "description": "Pydantic AI, LangGraph, DeepAgents, and Vercel AI SDK skills for building and reviewing AI applications.",
  "version": "1.0.0",
  "author": {
    "name": "Existential Birds, LLC",
    "email": "tech@existentialbirds.com"
  },
  "repository": "https://github.com/existential-birds/beagle",
  "keywords": [
    "pydantic-ai",
    "langgraph",
    "deepagents",
    "vercel-ai",
    "ai",
    "agents",
    "code-review"
  ]
}
```

**Step 3: Copy skills**

```bash
cp -r skills/pydantic-ai-agent-creation plugins/beagle-ai/skills/
cp -r skills/pydantic-ai-common-pitfalls plugins/beagle-ai/skills/
cp -r skills/pydantic-ai-dependency-injection plugins/beagle-ai/skills/
cp -r skills/pydantic-ai-model-integration plugins/beagle-ai/skills/
cp -r skills/pydantic-ai-testing plugins/beagle-ai/skills/
cp -r skills/pydantic-ai-tool-system plugins/beagle-ai/skills/
cp -r skills/langgraph-architecture plugins/beagle-ai/skills/
cp -r skills/langgraph-code-review plugins/beagle-ai/skills/
cp -r skills/langgraph-implementation plugins/beagle-ai/skills/
cp -r skills/deepagents-architecture plugins/beagle-ai/skills/
cp -r skills/deepagents-code-review plugins/beagle-ai/skills/
cp -r skills/deepagents-implementation plugins/beagle-ai/skills/
cp -r skills/vercel-ai-sdk plugins/beagle-ai/skills/
```

**Step 4: Verify**

```bash
ls plugins/beagle-ai/skills/ | wc -l
# Expected: 13
```

**Step 5: Commit**

```bash
git add plugins/beagle-ai/
git commit -m "feat(beagle-ai): create AI frameworks plugin"
```

---

## Task 7: Create beagle-docs Plugin

**Files:**
- Create: `plugins/beagle-docs/.claude-plugin/plugin.json`
- Create: `plugins/beagle-docs/skills/` (5 skill directories)
- Create: `plugins/beagle-docs/commands/` (3 command files)

**Step 1: Create plugin directory structure**

```bash
mkdir -p plugins/beagle-docs/.claude-plugin
mkdir -p plugins/beagle-docs/skills
mkdir -p plugins/beagle-docs/commands
```

**Step 2: Create plugin.json**

Create `plugins/beagle-docs/.claude-plugin/plugin.json`:

```json
{
  "name": "beagle-docs",
  "description": "Documentation quality, generation, and improvement using Diataxis principles. Pairs with beagle-core for full workflow.",
  "version": "1.0.0",
  "author": {
    "name": "Existential Birds, LLC",
    "email": "tech@existentialbirds.com"
  },
  "repository": "https://github.com/existential-birds/beagle",
  "keywords": [
    "documentation",
    "diataxis",
    "docs",
    "technical-writing"
  ]
}
```

**Step 3: Copy skills**

```bash
cp -r skills/docs-style plugins/beagle-docs/skills/
cp -r skills/tutorial-docs plugins/beagle-docs/skills/
cp -r skills/howto-docs plugins/beagle-docs/skills/
cp -r skills/reference-docs plugins/beagle-docs/skills/
cp -r skills/explanation-docs plugins/beagle-docs/skills/
```

**Step 4: Copy commands**

```bash
cp commands/draft-docs.md plugins/beagle-docs/commands/
cp commands/ensure-docs.md plugins/beagle-docs/commands/
cp commands/improve-doc.md plugins/beagle-docs/commands/
```

**Step 5: Update skill references in commands**

In `plugins/beagle-docs/commands/draft-docs.md`, replace:
- `beagle:docs-style` → `beagle-docs:docs-style`
- `beagle:reference-docs` → `beagle-docs:reference-docs`
- `beagle:howto-docs` → `beagle-docs:howto-docs`

In `plugins/beagle-docs/commands/improve-doc.md`, replace:
- `beagle:docs-style` → `beagle-docs:docs-style`
- `beagle:tutorial-docs` → `beagle-docs:tutorial-docs`
- `beagle:howto-docs` → `beagle-docs:howto-docs`
- `beagle:reference-docs` → `beagle-docs:reference-docs`
- `beagle:explanation-docs` → `beagle-docs:explanation-docs`

**Step 6: Verify**

```bash
ls plugins/beagle-docs/skills/ | wc -l
# Expected: 5
ls plugins/beagle-docs/commands/ | wc -l
# Expected: 3
```

**Step 7: Commit**

```bash
git add plugins/beagle-docs/
git commit -m "feat(beagle-docs): create documentation quality plugin"
```

---

## Task 8: Create beagle-analysis Plugin

**Files:**
- Create: `plugins/beagle-analysis/.claude-plugin/plugin.json`
- Create: `plugins/beagle-analysis/skills/` (5 skill directories)
- Create: `plugins/beagle-analysis/commands/` (3 command files)

**Step 1: Create plugin directory structure**

```bash
mkdir -p plugins/beagle-analysis/.claude-plugin
mkdir -p plugins/beagle-analysis/skills
mkdir -p plugins/beagle-analysis/commands
```

**Step 2: Create plugin.json**

Create `plugins/beagle-analysis/.claude-plugin/plugin.json`:

```json
{
  "name": "beagle-analysis",
  "description": "Architecture analysis, 12-Factor compliance, ADR generation, and LLM-as-judge comparison.",
  "version": "1.0.0",
  "author": {
    "name": "Existential Birds, LLC",
    "email": "tech@existentialbirds.com"
  },
  "repository": "https://github.com/existential-birds/beagle",
  "keywords": [
    "12-factor",
    "architecture",
    "adr",
    "llm-judge",
    "analysis"
  ]
}
```

**Step 3: Copy skills**

```bash
cp -r skills/12-factor-apps plugins/beagle-analysis/skills/
cp -r skills/agent-architecture-analysis plugins/beagle-analysis/skills/
cp -r skills/llm-judge plugins/beagle-analysis/skills/
cp -r skills/adr-decision-extraction plugins/beagle-analysis/skills/
cp -r skills/adr-writing plugins/beagle-analysis/skills/
```

**Step 4: Copy commands**

```bash
cp commands/12-factor-apps-analysis.md plugins/beagle-analysis/commands/
cp commands/llm-judge.md plugins/beagle-analysis/commands/
cp commands/write-adr.md plugins/beagle-analysis/commands/
```

**Step 5: Update skill references in commands**

In `plugins/beagle-analysis/commands/12-factor-apps-analysis.md`, replace:
- `beagle:12-factor-apps` → `beagle-analysis:12-factor-apps`

In `plugins/beagle-analysis/commands/llm-judge.md`, replace:
- `beagle:llm-judge` → `beagle-analysis:llm-judge`
- `beagle:llm-artifacts-detection` → `beagle-core:llm-artifacts-detection` (cross-plugin ref)

In `plugins/beagle-analysis/commands/write-adr.md`, replace:
- `beagle:adr-decision-extraction` → `beagle-analysis:adr-decision-extraction`
- `beagle:adr-writing` → `beagle-analysis:adr-writing`

**Step 6: Verify**

```bash
ls plugins/beagle-analysis/skills/ | wc -l
# Expected: 5
ls plugins/beagle-analysis/commands/ | wc -l
# Expected: 3
```

**Step 7: Commit**

```bash
git add plugins/beagle-analysis/
git commit -m "feat(beagle-analysis): create architecture analysis plugin"
```

---

## Task 9: Create beagle-testing Plugin

**Files:**
- Create: `plugins/beagle-testing/.claude-plugin/plugin.json`
- Create: `plugins/beagle-testing/commands/` (2 command files)

**Step 1: Create plugin directory structure**

```bash
mkdir -p plugins/beagle-testing/.claude-plugin
mkdir -p plugins/beagle-testing/commands
```

**Step 2: Create plugin.json**

Create `plugins/beagle-testing/.claude-plugin/plugin.json`:

```json
{
  "name": "beagle-testing",
  "description": "Language-agnostic test plan generation and execution.",
  "version": "1.0.0",
  "author": {
    "name": "Existential Birds, LLC",
    "email": "tech@existentialbirds.com"
  },
  "repository": "https://github.com/existential-birds/beagle",
  "keywords": [
    "testing",
    "test-plan",
    "qa"
  ]
}
```

**Step 3: Copy commands**

```bash
cp commands/gen-test-plan.md plugins/beagle-testing/commands/
cp commands/run-test-plan.md plugins/beagle-testing/commands/
```

**Step 4: Update references in commands**

In `plugins/beagle-testing/commands/gen-test-plan.md`, update any `/beagle:run-test-plan` references to `/beagle-testing:run-test-plan`.

In `plugins/beagle-testing/commands/run-test-plan.md`, no beagle skill references (uses `agent-browser:agent-browser` which is external).

**Step 5: Verify**

```bash
ls plugins/beagle-testing/commands/ | wc -l
# Expected: 2
```

**Step 6: Commit**

```bash
git add plugins/beagle-testing/
git commit -m "feat(beagle-testing): create test plan plugin"
```

---

## Task 10: Update beagle-elixir Skill References

The existing `beagle-elixir` plugin was created before the new naming convention. Update it to be consistent.

**Files:**
- Modify: `plugins/beagle-elixir/commands/review-elixir.md`

**Step 1: Check current references**

```bash
grep -n "beagle:" plugins/beagle-elixir/commands/review-elixir.md
grep -n "beagle-elixir:" plugins/beagle-elixir/commands/review-elixir.md
```

Verify that elixir skill references use `beagle-elixir:` prefix and `review-verification-protocol` uses `beagle-elixir:review-verification-protocol` (since it bundles its own copy).

**Step 2: Fix any remaining `beagle:` references**

If `review-verification-protocol` still references `beagle:`, update to `beagle-elixir:review-verification-protocol`.

**Step 3: Commit (if changes needed)**

```bash
git add plugins/beagle-elixir/
git commit -m "fix(beagle-elixir): update verification protocol reference to local copy"
```

---

## Task 11: Update marketplace.json

**Files:**
- Modify: `.claude-plugin/marketplace.json`

**Step 1: Replace marketplace.json with full plugin list**

Replace `.claude-plugin/marketplace.json` with:

```json
{
  "name": "existential-birds",
  "owner": {
    "name": "Existential Birds, LLC",
    "email": "tech@existentialbirds.com"
  },
  "metadata": {
    "description": "Framework-aware code review skills and workflows for modern development",
    "version": "2.0.0",
    "pluginRoot": "./plugins"
  },
  "plugins": [
    {
      "name": "beagle-core",
      "source": "beagle-core",
      "description": "Shared code review workflows, verification protocol, git commands, and feedback handling",
      "version": "1.0.0",
      "category": "workflow",
      "tags": ["code-review", "verification", "git", "feedback"]
    },
    {
      "name": "beagle-python",
      "source": "beagle-python",
      "description": "Python, FastAPI, SQLAlchemy, PostgreSQL, and pytest code review",
      "version": "1.0.0",
      "category": "backend",
      "tags": ["python", "fastapi", "sqlalchemy", "postgres", "pytest", "code-review"]
    },
    {
      "name": "beagle-go",
      "source": "beagle-go",
      "description": "Go, BubbleTea TUI, Wish SSH, and Prometheus code review",
      "version": "1.0.0",
      "category": "backend",
      "tags": ["go", "bubbletea", "wish", "prometheus", "tui", "code-review"]
    },
    {
      "name": "beagle-elixir",
      "source": "beagle-elixir",
      "description": "Elixir, Phoenix, LiveView, and ExUnit code review",
      "version": "1.0.0",
      "category": "backend",
      "tags": ["elixir", "phoenix", "liveview", "exunit", "code-review"]
    },
    {
      "name": "beagle-ios",
      "source": "beagle-ios",
      "description": "Swift, SwiftUI, SwiftData, and iOS framework code review",
      "version": "1.0.0",
      "category": "mobile",
      "tags": ["swift", "swiftui", "ios", "healthkit", "cloudkit", "widgetkit", "code-review"]
    },
    {
      "name": "beagle-react",
      "source": "beagle-react",
      "description": "React, React Flow, React Router, shadcn/ui, Tailwind, Vitest, and Zustand code review",
      "version": "1.0.0",
      "category": "frontend",
      "tags": ["react", "typescript", "tailwind", "shadcn", "vitest", "code-review"]
    },
    {
      "name": "beagle-ai",
      "source": "beagle-ai",
      "description": "Pydantic AI, LangGraph, DeepAgents, and Vercel AI SDK skills",
      "version": "1.0.0",
      "category": "ai",
      "tags": ["pydantic-ai", "langgraph", "deepagents", "vercel-ai", "agents"]
    },
    {
      "name": "beagle-docs",
      "source": "beagle-docs",
      "description": "Documentation quality, generation, and improvement using Diataxis principles",
      "version": "1.0.0",
      "category": "documentation",
      "tags": ["documentation", "diataxis", "technical-writing"]
    },
    {
      "name": "beagle-analysis",
      "source": "beagle-analysis",
      "description": "Architecture analysis, 12-Factor compliance, ADR generation, and LLM-as-judge",
      "version": "1.0.0",
      "category": "analysis",
      "tags": ["12-factor", "architecture", "adr", "llm-judge"]
    },
    {
      "name": "beagle-testing",
      "source": "beagle-testing",
      "description": "Language-agnostic test plan generation and execution",
      "version": "1.0.0",
      "category": "testing",
      "tags": ["testing", "test-plan", "qa"]
    }
  ]
}
```

**Step 2: Verify**

```bash
cat .claude-plugin/marketplace.json | python3 -c "import json,sys; d=json.load(sys.stdin); print(f'{len(d[\"plugins\"])} plugins registered')"
# Expected: 10 plugins registered
```

**Step 3: Commit**

```bash
git add .claude-plugin/marketplace.json
git commit -m "feat(marketplace): register all 10 plugins"
```

---

## Task 12: Remove Root-Level skills/ and commands/

Now that all skills and commands are in their respective plugins, remove the root-level directories and the root plugin.json (the repo is now a marketplace only, not a plugin itself).

**Files:**
- Delete: `skills/` (entire directory)
- Delete: `commands/` (entire directory)
- Modify: `.claude-plugin/plugin.json` → delete (marketplace repos don't need a plugin.json at root)

**Step 1: Remove root skills directory**

```bash
rm -rf skills/
```

**Step 2: Remove root commands directory**

```bash
rm -rf commands/
```

**Step 3: Remove root plugin.json**

```bash
rm .claude-plugin/plugin.json
```

**Step 4: Verify marketplace still valid**

```bash
ls .claude-plugin/
# Should only contain: marketplace.json
ls plugins/
# Should contain: beagle-ai beagle-analysis beagle-core beagle-docs beagle-elixir beagle-go beagle-ios beagle-python beagle-react beagle-testing
```

**Step 5: Commit**

```bash
git add -A
git commit -m "refactor(marketplace): remove monolith plugin, repo is now marketplace-only"
```

---

## Task 13: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Update CLAUDE.md to reflect new structure**

Update the architecture section, plugin list, skill categories, and installation instructions to reflect the marketplace-only structure with 10 plugins. Remove references to root-level skills/ and commands/ directories.

Key changes:
- Architecture diagram: `plugins/` with 10 subdirectories instead of root `skills/` and `commands/`
- Skill categories: organized by plugin name
- Installation: show marketplace add + selective install
- Remove "No Build System" section reference to root skills count
- Update commands table with plugin prefixes

**Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md for marketplace structure"
```

---

## Task 14: Update CHANGELOG.md and README.md

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `README.md`

**Step 1: Add changelog entry**

Add under a new version section (2.0.0 — breaking change since monolith is removed):

```markdown
## [2.0.0] - 2026-02-05

### Breaking Changes
- Removed monolith `beagle` plugin. Users must now install individual plugins.
- All skill references use new plugin prefixes (e.g., `beagle-python:python-code-review`)

### Added
- `beagle-core` plugin: shared workflows, verification protocol, git commands, feedback handling
- `beagle-python` plugin: Python, FastAPI, SQLAlchemy, PostgreSQL, pytest code review
- `beagle-go` plugin: Go, BubbleTea, Wish SSH, Prometheus code review
- `beagle-ios` plugin: Swift, SwiftUI, SwiftData, iOS frameworks code review
- `beagle-react` plugin: React, React Flow, React Router, shadcn/ui, Tailwind, Vitest, Zustand
- `beagle-ai` plugin: Pydantic AI, LangGraph, DeepAgents, Vercel AI SDK
- `beagle-docs` plugin: documentation quality using Diataxis principles
- `beagle-analysis` plugin: 12-Factor compliance, ADRs, LLM-as-judge
- `beagle-testing` plugin: test plan generation and execution

### Changed
- Repository is now a marketplace-only structure under `plugins/`
- Root-level `skills/` and `commands/` directories removed
```

**Step 2: Update README.md**

Update installation instructions and plugin list.

**Step 3: Commit**

```bash
git add CHANGELOG.md README.md
git commit -m "chore(release): v2.0.0 marketplace reorganization"
```

---

## Summary

After completing all 14 tasks:

1. 10 focused plugins under `plugins/`
2. No monolith option — root has only `.claude-plugin/marketplace.json`
3. Each domain plugin bundles its own `review-verification-protocol` copy
4. `beagle-core` recommended as base in every plugin description
5. Cross-plugin references use correct prefixes (e.g., `beagle-core:llm-artifacts-detection`)
6. Version bumped to 2.0.0 (breaking change)

**Installation for users:**

```bash
# Add marketplace
/plugin marketplace add existential-birds/beagle

# Install what you need
/plugin install beagle-core@existential-birds
/plugin install beagle-python@existential-birds
/plugin install beagle-react@existential-birds
```

**Plugin inventory:**

| Plugin | Skills | Commands | Category |
|--------|--------|----------|----------|
| beagle-core | 8 | 11 | workflow |
| beagle-python | 6 | 1 | backend |
| beagle-go | 6 | 2 | backend |
| beagle-elixir | 7 | 1 | backend |
| beagle-ios | 12 | 1 | mobile |
| beagle-react | 15 | 1 | frontend |
| beagle-ai | 13 | 0 | ai |
| beagle-docs | 5 | 3 | documentation |
| beagle-analysis | 5 | 3 | analysis |
| beagle-testing | 0 | 2 | testing |
| **Total** | **77** | **25** | |
