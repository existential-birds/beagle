# Draft Docs Command Design

**Date:** 2025-12-25
**Status:** Approved
**Related Issue:** existential-birds/amelia#142

## Summary

Create a `/beagle:draft-docs` command and supporting skills to generate first-draft technical documentation following Mintlify best practices. The command analyzes code based on user prompts and generates Reference or How-To documentation to a staging location for review.

## Decisions Made

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Capability | Draft new docs (not conversion) | Existing amelia-doc skill handles conversion |
| Content types | Reference + How-To (MVP) | Most common, clearest structure |
| Input | Code + user prompt | Flexible - user describes, command finds code |
| Output location | `docs/drafts/` staging | Review before integrating into navigation |
| Architecture | Single command + multiple skills | Matches beagle patterns, skills reusable |
| Command name | `draft-docs` | Sets expectation of review needed |

## Command Overview

**Command:** `/beagle:draft-docs`

### Two-Phase Workflow

**Phase 1: Generate draft**
```
/beagle:draft-docs "Document the WebSocket API"
→ Creates: docs/drafts/websocket-api.md
```

**Phase 2: Publish after review**
```
/beagle:draft-docs --publish docs/drafts/websocket-api.md
→ Asks: "Which section?" → API Reference
→ Moves to: docs/api/websocket-api.md
→ Updates: mint.json navigation
```

### Command Flow

1. **Parse Input** - Extract topic, detect content type (Reference vs How-To)
2. **Load Skills** - Always `mintlify-style` + appropriate content type skill
3. **Analyze Code** - Search for relevant symbols/files based on prompt
4. **Generate Draft** - Apply templates, write to `docs/drafts/`
5. **Publish Mode** - (with `--publish`) Move to final location, update nav config

## File Structure

```
beagle/
├── commands/
│   └── draft-docs.md              # Main command
├── skills/
│   ├── mintlify-style/
│   │   └── SKILL.md               # Core writing principles
│   ├── mintlify-reference-docs/
│   │   └── SKILL.md               # Reference doc patterns
│   └── mintlify-howto-docs/
│       └── SKILL.md               # How-To guide patterns
```

## Skill: mintlify-style

Core Mintlify writing principles applied to all documentation.

### Voice & Tone
- Second person ("you" not "the user")
- Active voice ("Create a file" not "A file should be created")
- Concise - cut unnecessary words

### Structure
- Clear, descriptive headings (no clever/vague titles)
- Self-contained pages (readers may land anywhere)
- Semantic markup (proper heading hierarchy, lists for lists, tables for data)
- Skimmable - break dense paragraphs

### Consistency
- One term per concept (don't switch between "API key" and "API token")
- Consistent formatting across similar content

### LLM-Friendly Patterns
- Explicit prerequisites
- Defined acronyms on first use
- Complete, runnable code examples
- Descriptive titles and meta descriptions

### Pitfalls to Avoid
- Product-centric language (orient around user goals)
- Obvious instructions that add no value
- Colloquialisms that hurt clarity/localization

## Skill: mintlify-reference-docs

Reference documentation is information-oriented - helping users find precise technical details.

### Purpose & Audience
- Experienced users seeking specific information
- Not for learning, for looking up

### Structure Template

```markdown
---
title: "[Symbol/API Name]"
description: "One-line description of what it does"
---

# [Name]

Brief description (1-2 sentences).

## Parameters / Props / Arguments
[Table format with name, type, required, description]

## Returns / Response
[What comes back, with types]

## Example
[Complete, runnable code]

## Related
[Links to related reference pages]
```

### Writing Principles
- Brevity over explanation
- Scannable tables, not prose
- Every example must be runnable
- Consistent format across all entries
- Avoid "why" - save that for Explanations

### Code Examples
- Show common use case first
- Include imports/setup
- Use realistic values, not "foo/bar"

## Skill: mintlify-howto-docs

How-To guides are problem-oriented - helping users complete specific tasks.

### Purpose & Audience
- Users with a specific goal in mind
- Assumes some familiarity with the product

### Structure Template

```markdown
---
title: "How to [achieve specific goal]"
description: "Learn how to [goal] using [product/feature]"
---

# How to [Goal]

Brief intro: what you'll accomplish and why it's useful.

## Prerequisites
- [What user needs before starting]
- [Required access, tools, or setup]

## Steps

### 1. [Action verb] the [thing]
[Instruction with expected outcome]

### 2. [Next action]
[Continue with clear steps]

## Verify it worked
[How to confirm success]

## Next steps
[What user might want to do next]
```

### Writing Principles
- Title starts with "How to"
- Each step = one action
- Show expected outcome after key steps
- Minimize context - focus on doing
- Write from user's perspective, not product's

## Future Work

GitHub issues to track:
1. `feat(draft-docs): add Tutorial content type support`
2. `feat(draft-docs): add Explanation content type support`

## References

- [Mintlify Technical Writing Guide](https://www.mintlify.com/guides)
- [Diátaxis Framework](https://diataxis.fr/)
- Amelia Issue #142: Replace VitePress docs with Mintlify
