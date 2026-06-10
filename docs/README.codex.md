# Beagle for Codex

## Prerequisites

- Codex CLI or the Codex App
- A local clone of this repository

## Install

1. Clone Beagle.
2. Create `~/.agents/skills/` if needed.
3. Follow [.codex/INSTALL.md](../.codex/INSTALL.md) to link active skill directories into Codex.
4. Restart Codex if it was already open.

## Discovery

Codex discovers linked skill directories from `SKILL.md` frontmatter. Beagle skills are loaded as a flat set of unique skill names.

## Limits

- Codex has no separate Skill tool at runtime.
- There is no plugin namespace in discovery.
- The manual installer links the canonical `beagle-core` copy of `review-verification-protocol`; framework-local copies remain in the repository for relative skill references.
- In Beagle docs, `Task` maps to `spawn_agent` for delegation.

## More

See the main [README](../README.md).
