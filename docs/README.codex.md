# Beagle for Codex

## Prerequisites

- Codex CLI or the Codex App
- A local clone of this repository

## Install

1. Clone Beagle.
2. Create `~/.agents/skills/` if needed.
3. Follow [.codex/INSTALL.md](../.codex/INSTALL.md) to link each plugin's `skills/` directory into Codex.
4. Restart Codex if it was already open.

## Discovery

Codex discovers skills from `SKILL.md` frontmatter. Beagle's linked plugin `skills/` directories are loaded as a flat set.

## Limits

- Codex has no separate Skill tool at runtime.
- There is no plugin namespace in discovery.
- In Beagle docs, `Task` maps to `spawn_agent` for delegation.

## More

See the main [README](../README.md).
