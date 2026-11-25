# Contributing to Beagle

Contributions are welcome. This guide covers how to add or update skills and documentation in the Beagle Agent Skills repository.

## Quick start

1. Fork and clone the repository.
2. Create a branch: `git checkout -b feat/my-skill`.
3. Add or edit skills under `skills/<skill-name>/`.
4. Run `./scripts/check-portability.sh` and `npx skills add . --list`.
5. Submit a pull request.

## Repository layout

All skills live directly under `skills/`:

```text
skills/<skill-name>/
├── SKILL.md           # Required entrypoint (<500 lines, valid YAML frontmatter)
├── references/        # Optional supporting docs
├── scripts/           # Optional helper scripts
└── assets/            # Optional static assets
```

Domain groupings are maintained in [SKILLS.md](SKILLS.md), [README.md](README.md), and [llms.txt](llms.txt) rather than nested subdirectories so the repository layout matches `.agents/skills/<skill-name>/` 1:1.

## Local development

Install skills from this repository for any compatible agent with the [skills CLI](https://skills.sh/docs/cli):

```bash
# Preview discovered skills without installing
npx skills add . --list

# Install from the local checkout
npx skills add .
```

Or install from GitHub:

```bash
npx skills add existential-birds/beagle
```

## Creating skills

Skills are technology knowledge bases in `skills/<skill-name>/SKILL.md`. See the [Agent Skills specification](https://agentskills.io/specification) and `skills/skill-builder/SKILL.md` for authoring guidance.

### Beagle-specific guidelines

- **Frontmatter**: Use only `agentskills.io` core fields (`name`, `description`, and optional `license`, `compatibility`, `metadata`, `allowed-tools`). `name` must match the parent directory (`^[a-z0-9]+(-[a-z0-9]+)*$`, `<= 64` chars) and `description` (`<= 1024` chars) must include clear trigger keywords.
- **Content**: Keep `SKILL.md` under 500 lines; use `references/` for details. Do not place extra `.md` files directly beside `SKILL.md`.
- **Focus**: Include Beagle-specific workflow and current ecosystem details, not generic facts every agent already knows.
- **Code review skills**: Report issues as `[FILE:LINE] ISSUE_TITLE` and link `../review-verification-protocol/SKILL.md` (naming `review-verification-protocol` in prose for single-skill installs).
- **Portability**: Do not hard-code one harness as the executing agent. Avoid named harness tool instructions, slash-command invocations, and plugin-namespace tokens.
- **References**: Prefer relative `../<skill-name>/SKILL.md` links to canonical shared references instead of duplicating large blocks.

### Structure

```text
skills/my-skill/
├── SKILL.md
└── references/
    └── advanced.md
```

## Validation

Run the repository validation script and verify CLI discovery before committing:

```bash
./scripts/check-portability.sh
npx skills add . --list
```

`./scripts/check-portability.sh` validates layout preconditions, harness portability, absence of legacy install references, `agentskills.io` frontmatter + `<500`-line limits, and all relative markdown links and `#anchor` headings.

For a changed skill, also test it in a fresh agent session or install it locally with `npx skills add . --skill <skill-name>` and confirm the trigger description loads the intended workflow.

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org/):

```text
feat(skills): add redis-code-review skill
fix(skills): correct review-python tech detection
docs: update README with new skills
```

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`.

## Pull requests

1. Create a feature branch from `main`.
2. Make focused changes, usually one skill or closely related skill set per PR.
3. Update [SKILLS.md](SKILLS.md) (and [README.md](README.md) / [llms.txt](llms.txt) / [AGENTS.md](AGENTS.md) if domain counts or key entry points change) when adding, removing, or renaming skills.
4. Include the `./scripts/check-portability.sh` and `npx skills add . --list` results in the PR body.

## What makes a good skill?

- Fills a knowledge gap: recent library versions, non-obvious patterns, or project-specific workflow.
- Includes concrete commands, file paths, output formats, and verification gates.
- Follows the technology's official conventions.
- Avoids duplicating generic model knowledge.
- Separates long reference material into `references/` files.

## Releasing

Maintainers release from `main`:

1. Update `CHANGELOG.md` with a Keep a Changelog version section and updated footer compare links.
2. Run `./scripts/check-portability.sh` and `npx skills add . --list`.
3. Commit with `chore(release): prepare vX.Y.Z`.
4. Tag and push: `git tag -a vX.Y.Z -m "Release vX.Y.Z" && git push origin vX.Y.Z`.
5. Create the GitHub release for the tag.
