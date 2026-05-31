# Marketplace Checks

All marketplace checks emit **HIGH confidence** issues. These are verifiable by reading manifest files and enumerating directories.

This document is marketplace-agnostic — it works against any Agent Skills marketplace that uses `plugin.json` manifests. It does not hardcode marketplace names, directory conventions, or organization-specific rules.

## Discovering the Marketplace Structure

Before running marketplace checks, build a map of the marketplace:

1. **Find the marketplace manifest** — look for a top-level manifest file (e.g., `marketplace.json`, `.claude-plugin/marketplace.json`, or similar) that lists plugins. If no manifest exists, fall back to scanning for `plugin.json` files.

2. **Enumerate plugins** — for each plugin entry in the manifest, read its `source` path to find the plugin directory. Read the plugin's `plugin.json` for metadata.

3. **Enumerate skills per plugin** — within each plugin directory, look for a `skills/` directory. Each subdirectory of `skills/` that contains a `SKILL.md` is a skill.

4. **Build the skill index** — collect all `(plugin_name, skill_name, description)` tuples. This index is used for collision detection and overlap analysis.

```text
Marketplace
├── Plugin A (plugin.json)
│   └── skills/
│       ├── skill-one/SKILL.md
│       └── skill-two/SKILL.md
├── Plugin B (plugin.json)
│   └── skills/
│       ├── skill-three/SKILL.md
│       └── skill-four/SKILL.md
```

## Name Collision Detection

### No Duplicate Skill Names Within Marketplace

**What to check:** The skill's `name` field (from YAML frontmatter) does not match any other skill's `name` in the same marketplace.

**How to verify:**
1. Build the skill index (see above)
2. For each new or renamed skill, check if its `name` appears in any other plugin's skills
3. Skills within the same plugin can share a name with skills in other plugins only if the marketplace uses `plugin:skill` namespacing — but identical names are still confusing and should be flagged

**Why it matters:** Name collisions cause ambiguous skill references. When a user or automation references `skill-name`, the runtime may pick the wrong one or fail entirely.

**Severity:** Critical — a name collision means the skill cannot be reliably referenced.

**Common false positives:**
- A skill being moved between plugins (same name, different location) — check the diff to see if the old location was deleted. If so, this is a move, not a collision.
- Skills in different marketplaces (different repos) can share names without collision.

## Plugin Manifest Consistency

### plugin.json Exists and Is Valid

**What to check:** The plugin directory containing the new/changed skill has a valid `plugin.json` with at minimum: `name`, `description`, `version`.

**How to verify:** Read `plugin.json` from the plugin's `.claude-plugin/` directory (or root, depending on marketplace convention). Verify it parses as valid JSON and contains the required fields.

**Why it matters:** A skill without a valid parent plugin.json won't be discovered by the marketplace runtime.

**Severity:** Critical if plugin.json is missing or invalid JSON. Major if required fields are missing.

### Skill Directory Matches Plugin Structure

**What to check:** The new skill is placed in the plugin's `skills/` directory following the marketplace's directory convention.

**How to verify:** Confirm:
1. The skill directory is inside `<plugin_root>/skills/<skill_name>/`
2. The directory name matches the skill's `name` field in frontmatter
3. `SKILL.md` is at the root of the skill directory (not nested deeper)

**Why it matters:** Skills placed outside the expected directory structure won't be discovered by the plugin loader.

**Severity:** Critical if the skill is in the wrong location. Minor if the directory name doesn't match the frontmatter `name` (the runtime uses the frontmatter name, but mismatches cause confusion).

## Cross-Reference Validation (Should-Have)

### SKILL.md References Resolve to Existing Files

**What to check:** Every relative markdown link in SKILL.md (`[text](path)`) points to a file that exists within the skill directory.

**How to verify:** Parse markdown links from SKILL.md. For each relative path, check that the target file exists. Ignore:
- External URLs (`http://`, `https://`)
- Anchor links (`#section-name`)
- Links to files outside the skill directory (these are cross-skill references and may be valid)

**Why it matters:** Broken references mean the agent can't load the referenced content, resulting in incomplete skill execution.

**Severity:** Minor — the skill still loads, but loses access to referenced material.

**Common false positives:** Links to files that will be created by the same PR but are in a different commit — check the full PR diff, not just the current commit.

## Trigger Keyword Overlap (Should-Have)

### Flag Significant Overlap with Existing Skills

**What to check:** The new skill's description doesn't share the same primary trigger keywords as an existing skill in the marketplace to the point where the agent would have difficulty choosing between them.

**How to verify:**
1. Extract key terms from the new skill's description (nouns, verbs, technology names)
2. Compare against descriptions of all existing skills in the marketplace
3. Flag if two skills share 3+ primary trigger keywords AND their capability statements don't clearly differentiate them

**Why it matters:** When multiple skills match the same trigger, the agent may pick the wrong one or waste context loading both. Clear differentiation in descriptions prevents this.

**Severity:** Informational — overlap may be intentional (complementary skills) or the skill author may want to adjust their description.

**Common false positives:**
- Skills in the same domain that intentionally complement each other (e.g., `review-python` and `pytest-code-review` both mention Python)
- Skills that share technology keywords but serve different purposes (e.g., a "build" skill and a "review" skill for the same framework)

## Script Quality (Should-Have)

### Scripts Declare --help

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
