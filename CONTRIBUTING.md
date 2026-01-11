# Contributing to Beagle

Contributions are welcome. This guide covers how to add skills, commands, and improvements.

## Quick start

1. Fork and clone the repository
2. Create a branch: `git checkout -b feat/my-skill`
3. Make changes
4. Test with Claude Code (see below)
5. Submit a pull request

## Local development

Add the plugin to `~/.claude/settings.json`:

```json
{
  "plugins": ["/path/to/your/beagle"]
}
```

Restart Claude Code after changes to reload.

## Creating skills

Skills are technology knowledge bases in `skills/skill-name/SKILL.md`. See [Agent Skills best practices](https://docs.claude.com/en/docs/agents-and-tools/agent-skills/best-practices) for authoring guidance.

### Beagle-specific guidelines

- **Description**: Include trigger keywords (e.g., "React hooks", "FastAPI endpoints")
- **Content**: Under 500 lines; use `references/` subfolder for additional detail
- **Focus**: Only include what Claude wouldn't know from training
- **Code review skills**: Use format `[FILE:LINE] ISSUE_TITLE` for issues

### Structure

```
skills/my-skill/
├── SKILL.md           # Required
└── references/        # Optional
    └── advanced.md
```

## Creating commands

Commands are workflow files in `commands/command-name.md`. See [Slash commands](https://docs.claude.com/en/docs/claude-code/slash-commands) for format details.

### Beagle-specific guidelines

- Start with context gathering (git status, file detection)
- Load relevant skills based on detected technologies
- Include output format templates
- End with verification steps

## Testing

No automated tests. Validate manually:

1. Check YAML frontmatter is valid
2. For skills: Start a conversation using trigger keywords
3. For commands: Run `/beagle:<command-name>`

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(skills): add redis-code-review skill
fix(commands): correct review-python tech detection
docs: update README with new skills
```

Types: `feat`, `fix`, `docs`, `refactor`, `chore`

## Pull requests

1. Create a feature branch from `main`
2. Make focused changes (one skill or command per PR)
3. Update README.md skill/command tables if adding new ones
4. Submit PR with clear description

## What makes a good skill?

- Fills a knowledge gap (recent library versions, non-obvious patterns)
- Includes working code examples
- Follows the technology's official conventions
- Avoids duplicating Claude's existing knowledge

## Releasing

Maintainers use internal commands to create releases:

1. `/release` - Creates a release PR with updated CHANGELOG and version bump
2. `/release-tag <version>` - After PR is merged, tags and creates GitHub release
