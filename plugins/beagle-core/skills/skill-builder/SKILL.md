---
name: skill-builder
description: Create Claude Code skills with best practices, structure, validation, and testing. Use when designing or refining skills, prompts, references, or supporting files.
disable-model-invocation: true
---

# Skill Builder

Create, validate, and refine Claude Code skills.

## Quick Start

1. Gather the capability, triggers, and required domain knowledge.
2. Choose a simple single-file skill or a multi-file skill with references.
3. Write `SKILL.md` with concise, trigger-focused instructions.
4. Add reference files only for detail that would otherwise bloat `SKILL.md`.
5. Validate YAML frontmatter, file layout, and naming.
6. Test the skill with the natural language users are likely to say.

## Workflow

- Start with requirements and scope control.
- Design the structure before writing content.
- Keep descriptions in third person and include trigger keywords.
- Use progressive disclosure for long examples, templates, and validation details.

## Validation

- Keep `SKILL.md` under 500 lines.
- Prefer one-level reference links.
- Avoid time-sensitive guidance.
- Confirm frontmatter is valid YAML.
- Check that any `allowed-tools` entries are necessary and correct.

## Advanced Reference

For the full workflow, templates, examples, and validation checklist, see [references/skill-builder-guide.md](references/skill-builder-guide.md).
