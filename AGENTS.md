# AGENTS.md

This file provides guidance to coding agents and contributors working in this repository.

## What This Is

Beagle is a vanilla [Agent Skills](https://agentskills.io/specification) repository providing **84** framework-aware code review, planning, documentation, testing, and analysis skills installed via `npx skills add existential-birds/beagle`.

## Repository Layout

```text
beagle/
├── skills/                      # 84 flat Agent Skills (skills/<skill-name>/SKILL.md)
│   ├── <skill-name>/
│   │   ├── SKILL.md             # Required entrypoint (<500 lines, valid YAML frontmatter)
│   │   ├── references/          # Optional progressive-disclosure reference files
│   │   ├── scripts/             # Optional helper scripts (e.g. write-adr/scripts/)
│   │   └── assets/              # Optional static assets
│   └── ...
├── scripts/
│   └── check-portability.sh     # 5-gate layout, portability, frontmatter, and link validator
├── assets/                      # Repository assets (e.g. README hero image)
├── .github/                     # PR and issue templates
├── SKILLS.md                    # Full 84-skill catalog grouped into 10 domains
├── README.md                    # Overview and installation instructions
├── AGENTS.md                    # Contributor & agent instructions (this file)
├── CONTRIBUTING.md              # Contribution and validation guide
├── CHANGELOG.md                 # Keep a Changelog history
└── llms.txt                     # Concise LLM catalog index
```

Each skill lives directly under `skills/<skill-name>/SKILL.md`. Domain groupings are maintained in `SKILLS.md`, `README.md`, and `llms.txt` rather than nested subdirectories so the repo layout matches `.agents/skills/<skill-name>/` 1:1.

## Local Development & Validation

Preview skill discovery locally with the `skills` CLI (non-destructive) and run the portability suite before every commit or PR:

```bash
# Validate layout, portability, legacy patterns, frontmatter, and relative links
./scripts/check-portability.sh

# Verify skill discovery with the skills CLI
npx skills add . --list
```

`./scripts/check-portability.sh` enforces 5 gates:
1. **Layout preconditions**: ensures the legacy plugin tree does not exist, `skills/` is non-empty, no `__pycache__`/`.pyc`/`.DS_Store` caches exist, no extra root `.md` files sit beside `SKILL.md`, and only `references/`, `scripts/`, or `assets/` subdirectories exist.
2. **Harness portability**: blocks harness-specific tool names, slash invocations, namespace tokens, and non-spec frontmatter keys in `skills/**/*.md`.
3. **Legacy install/harness references**: blocks legacy marketplace/plugin install instructions, deleted plugin references, and non-spec frontmatter extensions across skills, active docs, and `.github/` templates.
4. **`agentskills.io` frontmatter & line count**: checks `< 500` lines per `SKILL.md`, required `name` (`^[a-z0-9]+(-[a-z0-9]+)*$`, `<= 64` chars, matching parent dir, unique) and `description` (`1–1024` chars, no unquoted `#` truncation), only allowed spec keys (`name`, `description`, `license`, `compatibility`, `metadata`, `allowed-tools`), and no `metadata.internal: true` on catalog skills.
5. **Relative markdown links & anchors**: checks every relative file target and `#heading-anchor` fragment across `skills/**/*.md` and active root docs/templates.

## Authoring & Updating Skills

See the [Agent Skills specification](https://agentskills.io/specification) and `skills/skill-builder/SKILL.md` for full authoring guidance.

Beagle-specific rules:
- Place every skill in `skills/<skill-name>/SKILL.md` (single-level `references/`, `scripts/`, `assets/` subdirectories only — no extra root `.md` files beside `SKILL.md`).
- Keep `SKILL.md` under 500 lines; move deep material to `references/`.
- Use only `agentskills.io` core frontmatter fields (`name`, `description`, and optional `license`, `compatibility`, `metadata`, `allowed-tools`). Do not add harness-specific frontmatter extension keys.
- Code review skills: report findings with `[FILE:LINE] ISSUE_TITLE` and link `../review-verification-protocol/SKILL.md` (naming `review-verification-protocol` in prose for single-skill installs).
- Link sibling skills with `../<target-skill>/SKILL.md` (or `../../<target-skill>/...` from `references/`), and avoid harness-specific tool phrasing.

## Key Entry-Point Skills

| Domain | Skill | Purpose |
|--------|-------|---------|
| Python | `review-python` | Python/FastAPI/SQLAlchemy/PostgreSQL/pytest code review |
| Frontend | `review-frontend` | React/TypeScript code review with stack detection |
| Frontend (legacy) | `review-remix-v2` | Legacy maintenance review for EOL Remix v2 apps |
| Go | `review-go` | Go backend review with BubbleTea/Wish/Prometheus detection |
| Go | `review-tui` | BubbleTea v1/v2 & Wish SSH TUI code review |
| Rust | `review-rust` | Rust Edition 2024 review with axum/tokio/sqlx/serde/FFI/macros routing |
| Elixir | `review-elixir` | Elixir/Phoenix 1.8/LiveView/ExUnit code review |
| iOS/Swift | `review-ios` | Swift 6.2/SwiftUI/SwiftData/Apple frameworks code review |
| Core | `review-plan` | Review implementation plans before execution |
| Core | `review-structure` | Repo-wide structural-maintainability review |
| Core | `refactor-repo` | Evidence-backed repository refactoring survey and GitHub issue workflow |
| Core | `skill-builder` | Guided `agentskills.io` skill authoring and validation |
| Core | `review-skill` | Skill PR review for structural validity, design quality, and portability |
| Core | `receive-feedback` | Verification-first external review feedback triage and fixing |
| Core | `fetch-pr-feedback` | Fetch unresolved GitHub PR review comments for triage |
| Core | `respond-pr-feedback` | Post replies and resolve GitHub PR review threads |
| Core | `review-llm-artifacts` | Detect LLM coding artifacts across changed or repo files |
| Core | `verify-llm-artifacts` | Adjudicate artifact findings before deletes |
| Core | `fix-llm-artifacts` | Apply verified safe/risky artifact cleanups |
| Analysis | `prfaq-beagle` | Working Backwards PRFAQ pass/fail concept filter |
| Analysis | `brainstorm-beagle` | Turn fuzzy ideas into structured `.beagle/concepts/<slug>/spec.md` specs |
| Analysis | `resolve-beagle` | Close Open Questions and latent gaps in a spec |
| Analysis | `write-plan` | Generate spec-grounded TDD implementation plans |
| Analysis | `quick-plan` | Generate TDD implementation plans from conversation intent without a spec |
| Analysis | `write-adr` | Extract decisions and generate/validate MADR ADRs |
| Analysis | `agent-architecture-analysis` | Audit LLM agent codebases against 12-Factor Agents |
| Analysis | `llm-judge` | Compare 2+ implementations against a spec with rubric scoring |
| Analysis | `strategy-interview` | Build strategy through guided conversation |
| Analysis | `strategy-review` | Pressure-test existing strategy documents |
| Analysis | `web-research` | Cited multi-angle web research reports |
| Analysis | `artifact-analysis` | Cited structured scans of local docs |
| Docs | `improve-doc` | Audit and refactor docs using Diataxis principles and `--balance` checks |
| Docs | `review-ai-writing` | Detect AI writing patterns in docs, comments, and commits |
| Docs | `humanize-beagle` | Rewrite AI writing with safe/risky controls |
| Testing | `gen-test-plan` | Generate E2E YAML test plans from branch changes |
| Testing | `run-test-plan` | Execute E2E YAML test plans, stopping on first failure |

## Conventions

- **Commits**: Conventional Commits format (`feat`, `fix`, `docs`, `refactor`, `test`, `chore`)
- **Versioning**: Semantic versioning tracked via git tags (`vX.Y.Z`) and `CHANGELOG.md`
- **Release notes**: Keep a Changelog format in `CHANGELOG.md`
- **Skill references**: Use relative paths (`../<skill-name>/SKILL.md`) plus the skill name in prose

## Release Process

1. **Run validation** - Confirm `./scripts/check-portability.sh` prints `PORTABILITY OK` and `npx skills add . --list` discovers all skills cleanly
2. **Update CHANGELOG.md** - Move `[Unreleased]` entries into `## [X.Y.Z] - YYYY-MM-DD` (Keep a Changelog format) and update footer compare links
3. **Commit** - `chore(release): prepare vX.Y.Z`
4. **Push** - `git push origin main`
5. **Tag** - `git tag -a vX.Y.Z -m "Release vX.Y.Z - Summary"` and `git push origin vX.Y.Z`
6. **Release** - `gh release create vX.Y.Z --title "vX.Y.Z" --notes "..."`

Version bumping:
- **Patch** (x.y.Z): Bug fixes, documentation
- **Minor** (x.Y.0): New skills or features
- **Major** (X.0.0): Breaking changes to repository layout or existing skills
