---
name: skill-builder
description: Creates and refines Agent Skills with agentskills.io specification compliance, progressive disclosure, validation, and testing. Use when designing, authoring, or auditing SKILL.md files, references, or skill scripts.
---

# Skill Builder

Create, validate, and refine Agent Skills.

## Quick Start

1. Gather the capability, triggers, and required domain knowledge (or scaffold with `npx skills init <skill-name>`).
2. Choose a simple single-file skill or a multi-file skill with `references/`, `scripts/`, or `assets/`.
3. Write `SKILL.md` with concise, trigger-focused instructions and `agentskills.io`-compliant YAML frontmatter.
4. Add reference files under `references/` only for detail that would otherwise bloat `SKILL.md`.
5. Validate YAML frontmatter, file layout, and naming (`skills-ref validate` and `npx skills add . --list`).
6. Test the skill with the natural language users are likely to say.

## Workflow

- Start with requirements and scope control.
- Design the structure before writing content.
- Keep descriptions in third person and include trigger keywords.
- Use progressive disclosure for long examples, templates, and validation details.

## Gates

Follow in order. **Pass** means a check you can satisfy with concrete artifacts (written bullets, paths, line counts, parsed YAML)—not an internal sense of "done."

1. **Requirements** — **Pass:** Capability, triggers, and any required domain knowledge (or explicit "none") are written down or confirmed from the user.
2. **Structure** — **Pass:** Single-file vs `SKILL.md` + `references/` is chosen; heavy detail lives in `references/`, not inlined in `SKILL.md`.
3. **Draft** — **Pass:** Frontmatter is valid YAML with `name` (matching the parent directory name) and `description`; `SKILL.md` is ≤ 500 lines; every relative link from `SKILL.md` resolves to a path that exists; any optional `allowed-tools` entry uses space-delimited syntax and is justified.
4. **Trigger check** — **Pass:** At least one natural-language user phrase plausibly matching the `description` is identified for a quick invocation test.

## Validation

- Keep `SKILL.md` under 500 lines.
- Prefer one-level `references/` links.
- Avoid time-sensitive guidance.
- Confirm frontmatter uses only `agentskills.io` specification fields (`name`, `description`, optional `license`, `compatibility`, `metadata`, `allowed-tools`).
- Verify `allowed-tools` (if used) is an optional, experimental space-delimited string per `agentskills.io/specification`.
- Run `skills-ref validate` (if available) and `npx skills add . --list` to verify discovery.

## Advanced Reference

For the full workflow, templates, examples, and validation checklist, see [references/skill-builder-guide.md](references/skill-builder-guide.md).
