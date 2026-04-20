# Skills gates batch run manifest

**Duplicate / mirror policy:** **Independent** — each `SKILL.md` path in the queue is processed separately; duplicated content across plugins may have small wording drift between copies.

| Skill path | Status | Verdict | Summary |
|------------|--------|---------|---------|
| `plugins/beagle-ai/skills/deepagents-architecture/SKILL.md` | DONE | CHANGED | Sequenced Gates section with seven steps and **Pass:** artifact lines replacing honor-system checklist. |
| `plugins/beagle-ai/skills/deepagents-code-review/SKILL.md` | DONE | CHANGED | Review gates: Locate→Anchor→Classify→Runtime claims with **Pass** evidence requirements. |
| `plugins/beagle-ai/skills/deepagents-implementation/SKILL.md` | DONE | CHANGED | Implementation gates table for disk/shell, interrupt+resume, store/MCP secrets. |
| `plugins/beagle-ai/skills/langgraph-architecture/SKILL.md` | DONE | CHANGED | Gates (sequenced): four steps with **Pass** conditions; Decision Checklist tied to gates. |
| `plugins/beagle-ai/skills/langgraph-code-review/SKILL.md` | DONE | CHANGED | Review gates: locate graph, map state, trace persistence, file:line citations. |
| `plugins/beagle-ai/skills/langgraph-implementation/SKILL.md` | DONE | CHANGED | Implementation gates for thread_id, get_state, HITL, checkpointers; operator import fix. |
| `plugins/beagle-ai/skills/pydantic-ai-agent-creation/SKILL.md` | DONE | CHANGED | Verification gates with **Pass** lines; ModelSettings imports in snippet. |
| `plugins/beagle-ai/skills/pydantic-ai-common-pitfalls/SKILL.md` | DONE | CHANGED | Gates (ambiguous failures): three steps with **Pass** under Debugging Tips. |
| `plugins/beagle-ai/skills/pydantic-ai-dependency-injection/SKILL.md` | DONE | CHANGED | Gates: deps attrs vs deps_type; runs supply deps; test overrides match Deps. |
| `plugins/beagle-ai/skills/pydantic-ai-model-integration/SKILL.md` | DONE | CHANGED | Check gates before ship: FallbackModel order; env/secret keys. |
| `plugins/beagle-ai/skills/pydantic-ai-testing/SKILL.md` | DONE | CHANGED | Gates: VCR cassettes and inline snapshots—4-step workflow with **Pass**. |
| `plugins/beagle-ai/skills/pydantic-ai-tool-system/SKILL.md` | DONE | CHANGED | ### Gates under Critical Rules: three sequenced checks. |
| `plugins/beagle-ai/skills/vercel-ai-sdk/SKILL.md` | DONE | CHANGED | ## Gates: four ordered checks for stream/route/tool loop/UIMessage. |
| `plugins/beagle-analysis/skills/adr-decision-extraction/SKILL.md` | DONE | CHANGED | ## Hard gates after Extraction Workflow: JSON/schema, de-dup, low-confidence audit. |
| `plugins/beagle-analysis/skills/adr-writing/SKILL.md` | DONE | CHANGED | Gates table for Steps 2, 5, 7 with objective pass conditions; **Gate** pointers. |
| `plugins/beagle-analysis/skills/agent-architecture-analysis/SKILL.md` | DONE | CHANGED | Hard gates: scan → per-factor file/line evidence → synthesis; Output Format ties to gates. |
| `plugins/beagle-analysis/skills/artifact-analysis/SKILL.md` | DONE | CHANGED | Workflow **Hard gates**: plan.md, dispatch, report.md, exit; linked failure-modes. |
| `plugins/beagle-analysis/skills/brainstorm-beagle/SKILL.md` | DONE | CHANGED | Checkable pass blocks before user review and before write; template/leakage gates. |
| `plugins/beagle-analysis/skills/llm-judge/SKILL.md` | DONE | CHANGED | Hard gates A–E; Verification linked to gates D/E. |
| `plugins/beagle-analysis/skills/prfaq-beagle/SKILL.md` | DONE | CHANGED | Gates table: resume fork, reports, Ignition→PR, verdict artifacts. |
| `plugins/beagle-analysis/skills/resolve-beagle/SKILL.md` | DONE | CHANGED | § Gates: six objective locks through research and spec commit. |
| `plugins/beagle-analysis/skills/strategy-interview/SKILL.md` | DONE | CHANGED | Coherence gate; source discipline inventory→classify→handle; Phase 4 step 4. |
| `plugins/beagle-analysis/skills/strategy-review/SKILL.md` | DONE | CHANGED | Hard gates for ratings, findings, judge JSON, `.beagle/` ledger. |
| `plugins/beagle-analysis/skills/web-research/SKILL.md` | DONE | CHANGED | Hard gates G0–G5; fail-fast WebSearch-only clarified vs WebFetch. |
| `plugins/beagle-analysis/skills/write-adr/SKILL.md` | DONE | CHANGED | Gates table Steps 2–6; aligned with adr-writing paths/scripts. |
| `plugins/beagle-core/skills/commit-push/SKILL.md` | DONE | CHANGED | ## Gates: five steps with Pass-when tied to git output. |
| `plugins/beagle-core/skills/create-pr/SKILL.md` | DONE | CHANGED | Gates: branch, evidence range, no placeholders, gh success. |
| `plugins/beagle-core/skills/docling/SKILL.md` | DONE | CHANGED | ## Gates for ConversionStatus before export/chunking; example import fix. |
| `plugins/beagle-core/skills/fetch-pr-feedback/SKILL.md` | DONE | CHANGED | Gates: PR context, gh/jq success, formatted doc, load receive-feedback. |
| `plugins/beagle-core/skills/fix-llm-artifacts/SKILL.md` | DONE | CHANGED | Hard gates: stash, review JSON, stale abort, verification overlay, risky confirm. |
| `plugins/beagle-core/skills/gen-release-notes/SKILL.md` | DONE | CHANGED | ## Gates for tags, rev-parse, gh JSON, footer parity. |
| `plugins/beagle-core/skills/github-projects/SKILL.md` | DONE | CHANGED | Gates: confirm project; IDs from JSON; bulk adds smoke test first. |
| `plugins/beagle-core/skills/llm-artifacts-detection/SKILL.md` | DONE | CHANGED | Gates (reporting): anchor, defect title, dedup before emit. |
| `plugins/beagle-core/skills/prompt-improver/SKILL.md` | DONE | CHANGED | Step 1 Gates (audit/transform/output); Step 3 pointer. |
| `plugins/beagle-core/skills/receive-feedback/SKILL.md` | DONE | CHANGED | Hard gates: verify artifact, EVALUATION.md, RESPONSE.md template. |
| `plugins/beagle-core/skills/respond-pr-feedback/SKILL.md` | DONE | CHANGED | Hard gates: fetch/eval, gh context, empty queue stop, reply/resolve order. |
| `plugins/beagle-core/skills/review-feedback-schema/SKILL.md` | DONE | CHANGED | Gates for feedback log rows with **Pass when** and CSV shape. |
| `plugins/beagle-core/skills/review-llm-artifacts/SKILL.md` | DONE | CHANGED | Hard gates G1–G4; prerequisites on Steps 4/6. |
| `plugins/beagle-core/skills/review-plan/SKILL.md` | DONE | CHANGED | Hard gates: plan headers, skills before Task, five outputs, review file. |
| `plugins/beagle-core/skills/review-skill-improver/SKILL.md` | DONE | CHANGED | Hard gates: log path, schema, aggregation, Evidence before Proposed Fix. |
| `plugins/beagle-core/skills/review-verification-protocol/SKILL.md` | DONE | CHANGED | Hard gates table; checklist tied to gate 2; fixed step numbering. |
| `plugins/beagle-core/skills/skill-builder/SKILL.md` | DONE | CHANGED | §Gates: requirements, layout, draft YAML, trigger phrase. |
| `plugins/beagle-core/skills/sqlite-vec/SKILL.md` | DONE | CHANGED | ## Gates: dimension lock, round-trip MATCH, cite Resources URLs. |
| `plugins/beagle-core/skills/verify-llm-artifacts/SKILL.md` | DONE | CHANGED | Hard gates; strengthened steps 1/3/4; json.load validation in step 4. |
| `plugins/beagle-docs/skills/docs-style/SKILL.md` | DONE | NO_CHANGE | Style reference with checklist; orchestration: low gate value—no edit. |
| `plugins/beagle-docs/skills/draft-docs/SKILL.md` | DONE | CHANGED | Hard gates for draft and publish phases with **Pass** steps. |
| `plugins/beagle-docs/skills/ensure-docs/SKILL.md` | DONE | CHANGED | Six workflow steps with **Pass** checks; detection before verifiers, JSON merge. |
| `plugins/beagle-docs/skills/explanation-docs/SKILL.md` | DONE | CHANGED | Gates before done: classify → skeleton → rationale → checklist with **Pass**. |
| `plugins/beagle-docs/skills/howto-docs/SKILL.md` | DONE | CHANGED | Hard gates before publishing: five gates with **Pass** lines. |
| `plugins/beagle-docs/skills/humanize-beagle/SKILL.md` | DONE | CHANGED | Hard gates G1–G5; jq/json validation; Rules aligned. |
| `plugins/beagle-docs/skills/improve-doc/SKILL.md` | DONE | CHANGED | Gates before Phase 2, overwrite, Diataxis ambiguity. |
| `plugins/beagle-docs/skills/reference-docs/SKILL.md` | DONE | CHANGED | Gates (completion order): structure, tables, runnable example, related. |
| `plugins/beagle-docs/skills/review-ai-writing/SKILL.md` | DONE | CHANGED | Gates (5 passes); §10 tightened; Reference Material heading fix. |
| `plugins/beagle-docs/skills/tutorial-docs/SKILL.md` | DONE | CHANGED | Pre-publish gates: draft → outcomes → path → independent run. |
| `plugins/beagle-elixir/skills/elixir-code-review/SKILL.md` | DONE | CHANGED | Gates — before reporting; protocol anchors; Before Submitting ties to gates. |
| `plugins/beagle-elixir/skills/elixir-docs-review/SKILL.md` | DONE | CHANGED | Gates: scope, read, evidence/doctest; deduped Before Submitting. |
| `plugins/beagle-elixir/skills/elixir-performance-review/SKILL.md` | DONE | CHANGED | Gates — before reporting; anchors; performance claims thresholds. |
| `plugins/beagle-elixir/skills/elixir-security-review/SKILL.md` | DONE | CHANGED | Hard gates; added references/secrets.md for Quick Reference link. |
| `plugins/beagle-elixir/skills/elixir-writing-docs/SKILL.md` | DONE | CHANGED | Completing documentation gates: mix test, mix docs, @doc coverage. |
| `plugins/beagle-elixir/skills/exdoc-config/SKILL.md` | DONE | CHANGED | ## Gates: deps, extras paths, mix docs + index.html. |
| `plugins/beagle-elixir/skills/exunit-code-review/SKILL.md` | DONE | CHANGED | Gates sequence; ExUnit veto; Before Submitting points to gates. |
| `plugins/beagle-elixir/skills/liveview-code-review/SKILL.md` | DONE | CHANGED | Hard gates G1–G4; Before Submitting sequenced. |
| `plugins/beagle-elixir/skills/phoenix-code-review/SKILL.md` | DONE | CHANGED | Gates + fixed review-verification-protocol link to ../ |
| `plugins/beagle-elixir/skills/review-elixir/SKILL.md` | DONE | CHANGED | Hard gates; Step 7 requires gates; Post-Fix mirrors Step 2. |
| `plugins/beagle-elixir/skills/review-verification-protocol/SKILL.md` | DONE | CHANGED | Hard gates; checklist remapped; final step 0 to gates. |
| `plugins/beagle-go/skills/bubbletea-code-review/SKILL.md` | DONE | CHANGED | Hard gates G1–G3: NOT Issues, evidence, beagle-go protocol. |
| `plugins/beagle-go/skills/go-architect/SKILL.md` | DONE | CHANGED | Hard gates: go1.22+, composition root, Shutdown, no env DB in handlers. |
| `plugins/beagle-go/skills/go-code-review/SKILL.md` | DONE | CHANGED | Pass gates in workflow; Hard gates table; Before Submitting → step 4. |
| `plugins/beagle-go/skills/go-concurrency-web/SKILL.md` | DONE | CHANGED | Gates: race detector, bounded HTTP work, graceful teardown. |
| `plugins/beagle-go/skills/go-data-persistence/SKILL.md` | DONE | CHANGED | Gates: migrations, parameterized SQL, shared pool + Context. |
| `plugins/beagle-go/skills/go-middleware/SKILL.md` | DONE | CHANGED | Gates: recovery order, wrapped ResponseWriter, forward next. |
| `plugins/beagle-go/skills/go-testing-code-review/SKILL.md` | DONE | CHANGED | Review workflow Pass gates; Hard gates table; aligned with go-code-review. |
| `plugins/beagle-go/skills/go-web-expert/SKILL.md` | DONE | CHANGED | Hard gates for new HTTP handler; **Pass when** + Evidence per rule. |
| `plugins/beagle-go/skills/prometheus-go-code-review/SKILL.md` | DONE | CHANGED | Hard gates: scope, label cardinality, registration, finding shape. |
| `plugins/beagle-go/skills/review-go/SKILL.md` | DONE | CHANGED | Empty-diff gates; Step 4/6 hard gates before Critical/Major. |
| `plugins/beagle-go/skills/review-tui/SKILL.md` | DONE | CHANGED | Gates G1–G4: scope, skills, evidence, verification. |
| `plugins/beagle-go/skills/review-verification-protocol/SKILL.md` | DONE | CHANGED | Hard gates sequenced; five steps with **Pass**; linked checklist. |
| `plugins/beagle-go/skills/wish-ssh-code-review/SKILL.md` | DONE | CHANGED | Review gates: paths, host-key/middleware/shutdown, PTY evidence. |
| `plugins/beagle-ios/skills/app-intents-code-review/SKILL.md` | DONE | CHANGED | Hard gates before reporting; FILE:LINE; protocol; platform artifacts. |
| `plugins/beagle-ios/skills/cloudkit-code-review/SKILL.md` | DONE | CHANGED | Hard gates: file/line, CloudKit read, entitlements evidence, protocol. |
| `plugins/beagle-ios/skills/combine-code-review/SKILL.md` | DONE | CHANGED | Hard gates: scope, retention, cycles, UI scheduling, checklist linkage. |
| `plugins/beagle-ios/skills/healthkit-code-review/SKILL.md` | DONE | CHANGED | Review gates: scope, store, auth, queries, observers, threading. |
| `plugins/beagle-ios/skills/ios-animation-code-review/SKILL.md` | DONE | CHANGED | Hard gates table: inventory → anchor → evidence → report. |
| `plugins/beagle-ios/skills/ios-animation-design/SKILL.md` | DONE | CHANGED | Gates (sequenced): context, ≥2 options, implementation-ready spec. |
| `plugins/beagle-ios/skills/ios-animation-implementation/SKILL.md` | DONE | CHANGED | Gates before complete: API row, Reduce Motion, interruptibility, Instruments. |
| `plugins/beagle-ios/skills/review-ios/SKILL.md` | DONE | CHANGED | Hard gates: scope list, SwiftLint, protocol, Critical/Major re-read. |
| `plugins/beagle-ios/skills/review-verification-protocol/SKILL.md` | DONE | CHANGED | Hard gates; SwiftUI/Combine/Task guidance; iOS-tuned pre-report. |
| `plugins/beagle-ios/skills/swift-code-review/SKILL.md` | DONE | CHANGED | Review Workflow **Pass** lines; Hard gates table; [FILE:LINE] format. |
| `plugins/beagle-ios/skills/swift-testing-code-review/SKILL.md` | DONE | CHANGED | Hard gates: .swift scope; Swift Testing surface; protocol + [FILE:LINE]. |
| `plugins/beagle-ios/skills/swiftdata-code-review/SKILL.md` | DONE | CHANGED | Hard gates: scope → reference/N/A → path:line → report order. |
| `plugins/beagle-ios/skills/swiftui-code-review/SKILL.md` | DONE | CHANGED | Gates: anchor paths; open references or skip; findings need path+lines. |
| `plugins/beagle-ios/skills/urlsession-code-review/SKILL.md` | DONE | CHANGED | Hard gates: scope, HTTP evidence, session lifecycle, background APIs. |
| `plugins/beagle-ios/skills/watchos-code-review/SKILL.md` | DONE | CHANGED | Output Format + Hard gates; watchOS evidence or Review Questions. |
| `plugins/beagle-ios/skills/widgetkit-code-review/SKILL.md` | DONE | CHANGED | Hard gates: FILE:LINE, TimelineProvider scope, platform evidence, protocol. |
| `plugins/beagle-python/skills/fastapi-code-review/SKILL.md` | DONE | CHANGED | Gates (FastAPI-specific) tables; Before Submitting runs gates + protocol. |
| `plugins/beagle-python/skills/postgres-code-review/SKILL.md` | DONE | CHANGED | Gates before reporting: scope, SQL/DDL cites, binding verification. |
| `plugins/beagle-python/skills/pytest-code-review/SKILL.md` | DONE | CHANGED | Review gates: five ordered steps with **Pass** before checklist. |
| `plugins/beagle-python/skills/python-code-review/SKILL.md` | DONE | CHANGED | Gates (reporting workflow); pointer replaces Before Submitting. |
| `plugins/beagle-python/skills/review-python/SKILL.md` | DONE | CHANGED | Hard gates G1–G5; wired into Steps 1,2,7,8. |
| `plugins/beagle-python/skills/review-verification-protocol/SKILL.md` | DONE | CHANGED | Hard gates (sequence); checklist defers to gates. |
| `plugins/beagle-python/skills/sqlalchemy-code-review/SKILL.md` | DONE | CHANGED | SQLAlchemy gates: session, N+1, Alembic with file:line. |
| `plugins/beagle-react/skills/ai-elements/SKILL.md` | DONE | CHANGED | Gates: shadcn add, imports/tsc, Tool/Confirmation vs AI SDK. |
| `plugins/beagle-react/skills/dagre-react-flow/SKILL.md` | DONE | CHANGED | Hard gates: dims, centering, immutability, fitView timing. |
| `plugins/beagle-react/skills/react-flow-advanced/SKILL.md` | DONE | CHANGED | Gates (check before shipping): 7 **Pass** checks; DnD import fix. |
| `plugins/beagle-react/skills/react-flow-architecture/SKILL.md` | DONE | CHANGED | Decision workflow (gates): four steps with **Pass**; anchors. |
| `plugins/beagle-react/skills/react-flow-code-review/SKILL.md` | DONE | CHANGED | Review gates: locate, Provider, types, file:line, checklists. |
| `plugins/beagle-react/skills/react-flow-implementation/SKILL.md` | DONE | CHANGED | Implementation gates; Quick Start useCallback import. |
| `plugins/beagle-react/skills/react-flow/SKILL.md` | DONE | CHANGED | Implementation gates: CSS, stable types, Provider+useReactFlow. |
| `plugins/beagle-react/skills/react-router-code-review/SKILL.md` | DONE | CHANGED | Gates: scope, context rules, Valid Patterns, protocol. |
| `plugins/beagle-react/skills/react-router-v7/SKILL.md` | DONE | CHANGED | Gates (decision sequencing): Form vs fetcher, loader vs effect. |
| `plugins/beagle-react/skills/review-frontend/SKILL.md` | DONE | CHANGED | Gates: five pass conditions; Step 3/6 wired. |
| `plugins/beagle-react/skills/review-verification-protocol/SKILL.md` | DONE | CHANGED | Hard gates (sequenced): read, reference, mitigation, claim. |
| `plugins/beagle-react/skills/shadcn-code-review/SKILL.md` | DONE | CHANGED | Hard gates: location, exemptions, Radix/a11y, protocol. |
| `plugins/beagle-react/skills/shadcn-ui/SKILL.md` | DONE | CHANGED | CLI gates: app root, components.json, overwrite conditions. |
| `plugins/beagle-react/skills/tailwind-v4/SKILL.md` | DONE | CHANGED | Gates (setup verification): Vite plugin, v4 deps, @theme. |
| `plugins/beagle-react/skills/vitest-testing/SKILL.md` | DONE | CHANGED | Verification gates: CI-equivalent run, async matchers. |
| `plugins/beagle-react/skills/zustand-state/SKILL.md` | DONE | CHANGED | Gates: persist shape; DevTools dev-only or PR note. |
| `plugins/beagle-rust/skills/axum-code-review/SKILL.md` | DONE | CHANGED | Gates: Cargo.toml axum/edition, [FILE:LINE], protocol. |
| `plugins/beagle-rust/skills/ffi-code-review/SKILL.md` | DONE | CHANGED | Gates 1–4: edition, build/bindings, evidence, protocol+FFI. |
| `plugins/beagle-rust/skills/macros-code-review/SKILL.md` | DONE | CHANGED | Gates: Cargo.toml/edition, macro defs paths, [FILE:LINE], protocol+macro checks. |
| `plugins/beagle-rust/skills/review-rust/SKILL.md` | DONE | CHANGED | Hard gates: scope → compiler/linter → protocol → evidence. |
| `plugins/beagle-rust/skills/review-verification-protocol/SKILL.md` | DONE | CHANGED | Hard gates sequenced; Submission gate [FILE:LINE]+proof. |
| `plugins/beagle-rust/skills/rust-best-practices/SKILL.md` | DONE | CHANGED | ## Gates: Clippy, perf metrics, cargo doc/missing_docs. |
| `plugins/beagle-rust/skills/rust-code-review/SKILL.md` | DONE | CHANGED | Gates: Cargo context, full read, severity, protocol completion. |
| `plugins/beagle-rust/skills/rust-project-setup/SKILL.md` | DONE | CHANGED | Setup completion gates: metadata, clippy/fmt, CI, lockfile. |
| `plugins/beagle-rust/skills/rust-testing-code-review/SKILL.md` | DONE | CHANGED | Gates (hard): edition, dyn Trait/async, protocol before findings. |
| `plugins/beagle-rust/skills/serde-code-review/SKILL.md` | DONE | CHANGED | Gates: Cargo edition/serde; [FILE:LINE]; protocol; output shape. |
| `plugins/beagle-rust/skills/sqlx-code-review/SKILL.md` | DONE | CHANGED | Gates: scope, Cargo/sqlx evidence, [FILE:LINE], protocol. |
| `plugins/beagle-rust/skills/tokio-async-code-review/SKILL.md` | DONE | CHANGED | Gates: tokio surface, runtime, blocking search, protocol. |
| `plugins/beagle-testing/skills/gen-test-plan/SKILL.md` | DONE | CHANGED | Hard gates: diff/base, trace, valid YAML, no runner steps, behavioral. |
| `plugins/beagle-testing/skills/run-test-plan/SKILL.md` | DONE | CHANGED | Pre-test gates, artifact gate 4c, Verification pass conditions. |
