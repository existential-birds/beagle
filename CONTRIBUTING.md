# Contributing to Beagle

Contributions are welcome. This guide covers how to add skills, commands, and improvements.

## Quick start

1. Fork and clone the repository
2. Create a branch: `git checkout -b feat/my-skill`
3. Make changes
4. Test with Claude Code
5. Submit a pull request

## Local development

Install the plugin from your local directory:

```bash
# In Claude Code settings (~/.claude/settings.json)
{
  "plugins": [
    "/path/to/your/beagle"
  ]
}
```

Restart Claude Code after changes to reload the plugin.

## Creating skills

Skills are technology knowledge bases that Claude loads automatically when relevant.

### Skill structure

```
skills/
└── my-skill/
    ├── SKILL.md           # Required: main skill file
    └── references/        # Optional: supporting docs
        └── advanced.md
```

### SKILL.md format

```markdown
---
name: my-skill
description: Brief description with trigger keywords. Claude uses this to decide when to load.
---

# My Skill

Content Claude should know about this technology.

## Quick start

Essential patterns and examples.

## Common patterns

Detailed guidance.
```

### Skill guidelines

- **Name**: lowercase-hyphen, max 64 characters
- **Description**: Include keywords that trigger loading (e.g., "React hooks", "FastAPI endpoints")
- **Content**: Under 500 lines in SKILL.md; use `references/` for additional detail
- **Assume intelligence**: Only include context Claude wouldn't know from training
- **Be specific**: Concrete examples over abstract explanations

### Code review skills

For `*-code-review` skills, use consistent issue format:

```markdown
## Issue format

[FILE:LINE] ISSUE_TITLE

- **Problem**: What's wrong
- **Fix**: How to fix it
```

## Creating commands

Commands are user-invoked workflows via `/beagle:<command-name>`.

### Command structure

Single markdown file in `commands/`:

```markdown
---
description: What this command does
---

# Command Name

## Step 1: Gather context

Instructions for Claude...

## Step 2: Perform action

More instructions...

## Output format

Template for output...
```

### Command guidelines

- Start with context gathering (git status, file detection)
- Load relevant skills based on detected technologies
- Include output format templates
- End with verification steps

## Conventions

### Commits

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(skills): add redis-code-review skill
fix(commands): correct review-backend tech detection
docs: update README with new skills
```

Types: `feat`, `fix`, `docs`, `refactor`, `chore`

### File naming

- Skills: `lowercase-hyphen/SKILL.md`
- Commands: `lowercase-hyphen.md`
- References: `lowercase-hyphen.md`

### Markdown

- Use fenced code blocks with language tags
- Use tables for structured data
- Keep lines under 120 characters

## Testing

No automated tests. Validate manually:

1. Check YAML frontmatter is valid
2. Verify markdown renders correctly
3. Test with Claude Code:
   - For skills: Start a conversation using trigger keywords
   - For commands: Run `/beagle:<command-name>`

## Versioning and releases

This project uses [Semantic Versioning](https://semver.org/):

- **Major** (1.0.0): Breaking changes to skill/command interfaces
- **Minor** (0.1.0): New skills or commands
- **Patch** (0.0.1): Bug fixes, documentation improvements

### Changelog

All changes are documented in [CHANGELOG.md](CHANGELOG.md) following [Keep a Changelog](https://keepachangelog.com/) format.

When contributing:
- Don't update CHANGELOG.md in your PR
- Maintainers add changelog entries during release

### Release process (maintainers)

1. Update version in `.claude-plugin/plugin.json`
2. Add release section to CHANGELOG.md
3. Commit: `chore: bump version to X.Y.Z`
4. Create annotated tag: `git tag -a vX.Y.Z -m "vX.Y.Z - Release title"`
5. Push with tags: `git push origin main --tags`
6. Create GitHub release from tag with changelog content

Alternatively, use `/beagle:gen-release-notes <previous-tag>` to generate release notes from commit history.

## Pull request process

1. Create a feature branch from `main`
2. Make focused changes (one skill or command per PR)
3. Update documentation:
   - Add to README.md skills/commands tables
   - Update CLAUDE.md command count if adding commands
4. Submit PR with clear description
5. Address review feedback

## What makes a good skill?

Good skills:
- Fill a knowledge gap (recent library versions, non-obvious patterns)
- Are specific and actionable
- Include working code examples
- Follow the technology's official conventions

Avoid:
- Duplicating Claude's existing knowledge
- Generic advice that applies to any technology
- Marketing language or subjective opinions

## Questions?

Open a [discussion](https://github.com/anderskev/beagle/discussions) for questions about contributing.
