# Contributing to Beagle

Contributions are welcome. This guide covers how to add skills and documentation to the Beagle Agent Skills marketplace.

## Quick start

1. Fork and clone the repository.
2. Create a branch: `git checkout -b feat/my-skill`.
3. Make changes under the relevant `plugins/<plugin>/skills/` directory.
4. Run the portability check and inspect the changed Markdown.
5. Submit a pull request.

## Repository layout

Active marketplace plugins live under `plugins/`:

```text
plugins/<plugin>/
├── README.md
└── skills/
    └── <skill-name>/
        ├── SKILL.md
        └── references/      # Optional supporting docs
```

The marketplace manifest is `.claude-plugin/marketplace.json`. There are no per-plugin `plugin.json` files and no active `commands/` directories; former command workflows were converted to skills.

## Local development

Install the whole marketplace for any compatible agent with the skills CLI:

```bash
npx skills add existential-birds/beagle
```

During local Claude Code development, add the checkout to `~/.claude/settings.json`:

```json
{
  "plugins": ["/path/to/your/beagle"]
}
```

Restart the agent after changes so skill discovery reloads. Codex users can link skills from this checkout into `~/.agents/skills/`; see [.codex/INSTALL.md](.codex/INSTALL.md) and [docs/README.codex.md](docs/README.codex.md).

## Creating skills

Skills are technology knowledge bases in `plugins/<plugin>/skills/<skill-name>/SKILL.md`. See the [Agent Skills specification](https://agentskills.io/specification) and [Agent Skills best practices](https://docs.claude.com/en/docs/agents-and-tools/agent-skills/best-practices) for authoring guidance.

### Beagle-specific guidelines

- **Description**: Include trigger keywords, for example "React hooks" or "FastAPI endpoints".
- **Content**: Keep `SKILL.md` under 500 lines; use `references/` for details.
- **Focus**: Include Beagle-specific workflow and current ecosystem details, not generic facts every agent already knows.
- **Code review skills**: Report issues as `[FILE:LINE] ISSUE_TITLE`.
- **Portability**: Do not hard-code one harness as the executing agent. Avoid named tool instructions such as `Task tool`, slash-command invocations, and plugin-namespace tokens in active skill content.
- **References**: If multiple skills need the same verification protocol, prefer relative links to the canonical reference instead of copying large blocks.

### Structure

```text
plugins/beagle-example/skills/my-skill/
├── SKILL.md
└── references/
    └── advanced.md
```

## Validation

This repository is a Markdown marketplace, not a buildable package. Use the checks that match your change:

```bash
./scripts/check-portability.sh
python3 - <<'PY'
from pathlib import Path
import yaml
for path in Path('plugins').glob('*/skills/*/SKILL.md'):
    text = path.read_text()
    if not text.startswith('---'):
        raise SystemExit(f'missing frontmatter: {path}')
    end = text.find('\n---', 3)
    if end == -1:
        raise SystemExit(f'unclosed frontmatter: {path}')
    yaml.safe_load(text[3:end])
print('frontmatter ok')
PY
```

For a changed skill, also read it from a fresh agent session or install/link it locally and confirm the trigger description loads the intended workflow.

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
3. Update the relevant plugin README and [SKILLS.md](SKILLS.md) when adding, removing, or renaming skills.
4. Include the portability/frontmatter checks you ran in the PR body.

## What makes a good skill?

- Fills a knowledge gap: recent library versions, non-obvious patterns, or project-specific workflow.
- Includes concrete commands, file paths, output formats, and verification gates.
- Follows the technology's official conventions.
- Avoids duplicating generic model knowledge.
- Separates long reference material into `references/` files.

## Releasing

Maintainers release from `main`:

1. Update `CHANGELOG.md` with a Keep a Changelog version section.
2. Bump `metadata.version` in `.claude-plugin/marketplace.json`.
3. Commit with `chore(release): X.Y.Z`.
4. Tag and push: `git tag -a vX.Y.Z -m "Release vX.Y.Z" && git push origin vX.Y.Z`.
5. Create the GitHub release for the tag.
