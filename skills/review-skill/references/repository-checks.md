# Repository & Portability Checks

All repository checks emit **HIGH confidence** issues. These are verifiable by enumerating `skills/` directories, checking links, and running Agent Skills CLI/reference validators.

## Discovering the Repository Structure

Build an index of the repository before running checks:

1. **Enumerate skill directories** — scan `skills/*/SKILL.md` directly under the repository root.
2. **Collect skill metadata** — for each skill directory, parse `(directory_name, frontmatter.name, frontmatter.description)`.
3. **Check layout compliance** — confirm each skill directory contains only `SKILL.md` at its root plus optional `references/`, `scripts/`, and `assets/` subdirectories (no extra root `.md` files alongside `SKILL.md`).

```text
repository/
└── skills/
    ├── skill-one/
    │   ├── SKILL.md
    │   ├── references/
    │   ├── scripts/
    │   └── assets/
    └── skill-two/
        └── SKILL.md
```

## Layout & Discovery Validation

### Flat `skills/<skill-name>/SKILL.md` Layout

**What to check:** Every skill lives directly at `skills/<skill-name>/SKILL.md`, with supporting files organized inside `references/`, `scripts/`, or `assets/` rather than extra root `.md` files.

**How to verify:**
1. Confirm `SKILL.md` is at `skills/<skill-name>/SKILL.md` (not nested under category or plugin folders)
2. Confirm no extra `.md` files exist in `skills/<skill-name>/` beside `SKILL.md`
3. Confirm frontmatter `name` matches `<skill-name>` identically

**Why it matters:** `npx skills add` installs every skill into flat `.agents/skills/<skill-name>/`. Flat repository structure gives 1:1 parity with installed layout and ensures cross-skill relative links behave identically in the repo and after installation.

**Severity:** Critical if `SKILL.md` is misplaced or `name` mismatches the directory; Major if extra root `.md` files exist alongside `SKILL.md`.

### CLI Discovery & Specification Validation

**What to check:** The repository discovers cleanly with `npx skills add . --list` and modified skills pass `skills-ref validate <skill-dir>`.

**How to verify:**
1. Run `npx skills add . --list` (or local `skills` binary) and verify all expected skills appear with zero parse or skip warnings
2. Run `skills-ref validate skills/<skill-name>` (if installed) to confirm strict `agentskills.io` compliance

**Why it matters:** Ensures skills are actually installable and will not be silently skipped or rejected by Agent Skills tooling.

**Severity:** Critical if `skills add . --list` skips a skill or `skills-ref validate` fails.

## Name Collision Detection

### Unique `name` Across `skills/`

**What to check:** The skill's `name` field (from YAML frontmatter) does not match any other skill's `name` in `skills/`.

**How to verify:**
1. Build the `(directory_name, frontmatter.name)` index across all `skills/*/SKILL.md`
2. Flag any duplicate `name` values

**Why it matters:** `npx skills add` deduplicates by exact `skill.name` — the first discovered skill wins and subsequent skills with the same `name` are silently skipped.

**Severity:** Critical — duplicate names silently shadow skills during discovery and installation.

## Cross-Skill Link & Portability Checks

### Portable Cross-Skill Links

**What to check:** Links to sibling skills use `../<target-skill>/SKILL.md` (or `../../<target-skill>/SKILL.md` from `references/*.md`) AND name the target skill explicitly in prose.

**How to verify:**
1. Check every relative link pointing outside the current skill directory resolves to an existing `skills/<target-skill>/...` path
2. Confirm no multi-level legacy plugin traversals or plugin-namespace syntax (`plugin:skill`) remain
3. Confirm the target skill name appears in surrounding prose so single-skill installations (`npx skills add --skill <name>`) remain understandable even when sibling skills are not installed

**Why it matters:** Multi-level relative paths break once installed into flat `.agents/skills/<name>/`, and prose names keep workflows clear when skills are installed individually.

**Severity:** Major if a relative link is broken or uses legacy plugin paths; Minor if the skill name is missing from prose.

### Harness-Agnostic Instructions

**What to check:** Skill files contain no harness-specific assumptions, proprietary tool names, or non-portable directory paths.

**How to verify:** Search all `.md` files in the skill directory for:
- Proprietary tool phrasing (e.g., `<Tool> tool` capitalized tool names or interactive prompt tool names)
- Harness-specific config/install filenames or hidden agent config directories (unless genuinely documenting generic installation target paths like `.agents/skills/`)
- Harness-specific argument variables instead of natural parameter descriptions
- Legacy plugin/marketplace manifest references

**Why it matters:** Agent Skills must work across all `agentskills.io`-compatible coding agents.

**Severity:** Major — harness-specific instructions fail or confuse non-target agents.

## Cross-Reference Validation (Should-Have)

### SKILL.md References Resolve to Existing Files

**What to check:** Every relative markdown link in `SKILL.md` points to a file that exists.

**How to verify:** Parse markdown links from `SKILL.md`. For each relative path, check that the target file exists. Ignore:
- External URLs (`http://`, `https://`)
- Anchor links (`#section-name`)

**Why it matters:** Broken references mean the agent can't load the referenced content, resulting in incomplete skill execution.

**Severity:** Minor — the skill still loads, but loses access to referenced material.

**Common false positives:** Links to files that will be created by the same PR in another commit — check the full PR diff, not just a single commit.

## Trigger Keyword Overlap (Should-Have)

### Flag Significant Overlap with Existing Skills

**What to check:** The new skill's description doesn't share the same primary trigger keywords as an existing skill in the repository to the point where the agent would have difficulty choosing between them.

**How to verify:**
1. Extract key terms from the new skill's description (nouns, verbs, technology names)
2. Compare against descriptions of all existing skills in `skills/`
3. Flag if two skills share 3+ primary trigger keywords AND their capability statements don't clearly differentiate them

**Why it matters:** When multiple skills match the same trigger, the agent may pick the wrong one or waste context loading both. Clear differentiation in descriptions prevents this.

**Severity:** Informational — overlap may be intentional (complementary skills) or the skill author may want to adjust their description.

**Common false positives:**
- Skills in the same domain that intentionally complement each other (e.g., `review-python` and `pytest-code-review` both mention Python)
- Skills that share technology keywords but serve different purposes (e.g., a "build" skill and a "review" skill for the same framework)

## Script Quality (Should-Have)

### Scripts Declare `--help`

**What to check:** If the skill includes executable scripts (`.py`, `.sh`, `.js`, etc.) in a `scripts/` directory, each script supports a `--help` flag that describes its usage.

**How to verify:** Check script files for argument parsing that includes help text. Look for `argparse`, `click`, `--help` handling, or usage strings.

**Why it matters:** The agent uses `--help` output to understand how to invoke scripts correctly. Without it, the agent must read the full script source to determine usage, consuming unnecessary context.

**Severity:** Informational — scripts work without `--help`, but discoverability suffers.

### Scripts Avoid Interactive Prompts

**What to check:** Scripts do not use `input()`, `readline`, `read -p`, or other TTY-dependent prompts. Agent environments typically don't support interactive input.

**How to verify:** Search script files for interactive input patterns:
- Python: `input(`, `sys.stdin.read` without piped input
- Bash: `read -p`, `select`
- Node: `readline`, `prompt`

**Why it matters:** Interactive prompts hang in non-TTY agent environments, causing the skill to stall indefinitely.

**Severity:** Major if the script is part of the main workflow. Informational if it's an optional utility.
