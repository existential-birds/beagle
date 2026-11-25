# Structural Checks

All structural checks emit **HIGH confidence** issues. These are mechanically verifiable — the skill either passes or fails each check.

## YAML Frontmatter

### Valid YAML

**What to check:** The frontmatter block between `---` delimiters parses as valid YAML. No tabs (YAML requires spaces), no unclosed quotes, no duplicate keys.

**How to verify:** Attempt to parse the frontmatter. Check for common YAML errors: tab characters, unquoted strings with special characters (`:`, `#`, `{`, `}`), missing closing quotes.

**Why it matters:** Invalid frontmatter prevents the skill from loading entirely. The agent never sees the skill.

**Common false positives:** Colons inside quoted description strings are valid YAML — `description: "Use when: X happens"` is fine.

### Required Fields Present

**What to check:** Frontmatter contains both `name` and `description` fields with non-empty values.

**How to verify:** After parsing YAML, confirm both keys exist and their values are non-empty strings (not `null`, not empty string, not whitespace-only).

**Why it matters:** `name` and `description` are the only fields the runtime reads at startup for skill discovery. Without them, the skill is invisible.

**Common false positives:** None. These fields are unconditionally required.

### Allowed Fields Only (`agentskills.io` Specification)

**What to check:** Frontmatter uses only the fields defined by the `agentskills.io` specification:
- Required: `name`, `description`
- Optional: `license`, `compatibility` (at most 500 characters), `metadata` (key-value map), `allowed-tools` (experimental space-delimited string)

Flag any non-spec harness extension keys such as `disable-model-invocation`, `user-invocable`, `autoContext`, `dependencies`, or `triggers`.

**How to verify:** Inspect every top-level key in YAML frontmatter against `{name, description, license, compatibility, metadata, allowed-tools}`. Verify `compatibility` (if present) is `<= 500` chars and `allowed-tools` (if present) uses space-delimited tokens rather than comma-separated lists.

**Why it matters:** Strict validators such as `skills-ref validate` reject unknown frontmatter keys, and harness-specific keys reduce cross-agent portability.

**Common false positives:** Keys nested under `metadata` (such as `metadata.author` or `metadata.version`) are valid per `agentskills.io`. Note: avoid setting `metadata.internal` to `true` on reference skills that workflow skills depend on, as `npx skills add` hides internal skills from default installation.

## Name Field

### Lowercase-Hyphen Format (No Leading, Trailing, or Consecutive Hyphens)

**What to check:** `name` contains only lowercase letters, numbers, and single hyphens. No underscores, no uppercase, no spaces, no leading/trailing `-`, no consecutive `--`, and no special characters.

**How to verify:** Match against pattern `^[a-z0-9]+(-[a-z0-9]+)*$`.

**Why it matters:** The name is used as the identifier in `skills/<name>/` directory names and installed `.agents/skills/<name>/` paths. Non-conforming names fail `agentskills.io` validation and cause lookup failures.

**Common false positives:** None. The format is strictly defined.

### Matches Parent Directory Name

**What to check:** The frontmatter `name` matches the exact name of the skill's parent directory (`skills/<skill-name>/SKILL.md`).

**How to verify:** Compare parsed `name` to `basename(dirname(skill_md_path))`.

**Why it matters:** Required by `agentskills.io/specification` and enforced by `skills-ref validate`. Mismatches also cause confusion when installing individual skills via `npx skills add --skill <name>`.

**Common false positives:** None. Directory and `name` must match identically.

### Maximum Length

**What to check:** `name` is at most 64 characters.

**How to verify:** Count characters in the name string.

**Why it matters:** The runtime enforces this limit. Names exceeding 64 characters are silently truncated or rejected depending on the host.

**Common false positives:** None. This is a hard limit.

### Vendor-Neutral Naming Convention (Informational)

**What to check:** As an optional vendor-neutrality convention, check whether `name` contains vendor-specific substrings such as `anthropic` or `claude` (case-insensitive).

**How to verify:** Case-insensitive substring search.

**Why it matters:** Vendor-neutral names like `api-client` or `llm-integration` stay portable across agent harnesses and avoid colliding with vendor-official skill catalogs.

**Common false positives:** A skill legitimately targeting a specific vendor SDK might name it explicitly — treat as an informational suggestion rather than a hard specification error.

## Description Field

### Maximum Length

**What to check:** `description` is at most 1024 characters.

**How to verify:** Count characters in the description string.

**Why it matters:** The runtime enforces this limit. Longer descriptions are truncated, potentially losing the "when to use" component that drives trigger accuracy.

**Common false positives:** None. This is a hard limit.

### Third Person Voice

**What to check:** Description does not use first person ("I can", "I will", "I help") or second person ("You can", "You should", "Helps you").

**How to verify:** Check for pronouns `I`, `my`, `me`, `you`, `your` as word boundaries at the start of sentences or after periods. The description should read as a capability statement: "Processes X", "Reviews Y", "Generates Z".

**Why it matters:** Descriptions are injected into the system prompt alongside many other skill descriptions. Mixed point-of-view confuses the agent's skill selection. Third person is the convention across all skill ecosystems.

**Common false positives:** Quoted text within the description (e.g., `Use when user says "I need help"`) — the pronouns are in quoted speech, not the description's own voice.

### What and When Components

**What to check:** Description includes both what the skill does (capability) and when to use it (trigger conditions). Look for patterns like "Use when", "Triggers on", "Use for", or equivalent phrasing that separates capability from activation context.

**How to verify:** The description should have two distinct components. A description that only states capability ("Reviews Python code") without trigger context ("Use when reviewing .py files or checking type hints") is incomplete.

**Why it matters:** The description is the primary signal the agent uses for skill selection. Without "when" context, the agent either over-triggers (selects the skill for unrelated tasks) or under-triggers (misses relevant tasks).

**Common false positives:** Very short descriptions that pack both components into one clause — "Reviews Python code for type safety and async patterns" implicitly covers "when" (when there's Python code to review). Flag only when trigger context is genuinely absent.

## SKILL.md Body

### Line Limit

**What to check:** The `SKILL.md` file (including frontmatter) is under 500 lines.

**How to verify:** Count total lines in the file.

**Why it matters:** Once loaded, the entire `SKILL.md` competes for context window space. Beyond 500 lines, the skill degrades agent performance. Content should be split into reference files using progressive disclosure.

**Common false positives:** None. This follows Agent Skills progressive disclosure best practices.

## File Structure

### Reference Depth

**What to check:** Reference files linked from `SKILL.md` do not themselves link to further reference files (no chains). All references should be one level deep from `SKILL.md`.

**How to verify:** For each file referenced in `SKILL.md`, scan that file for markdown links to other files within the skill directory. If found, flag the chain.

**Why it matters:** The agent may only partially read nested references (using partial reads instead of full reads), resulting in incomplete information. One-level references ensure complete reads.

**Common false positives:** Links to external URLs (not local files) are fine. Links to files outside the skill directory (e.g., to sibling skills via `../../<skill>/SKILL.md`) are cross-skill references, not internal reference chains, and should not be flagged here.

### No Windows-Style Paths

**What to check:** No file paths in any skill file use backslash separators (`\`).

**How to verify:** Search all files in the skill directory for `\` in contexts that look like file paths (adjacent to `/`, `.md`, `.py`, directory names).

**Why it matters:** Backslash paths break on Unix systems where most agents run. Forward slashes work on all platforms.

**Common false positives:** Backslashes in regex patterns, escape sequences in code blocks, or YAML escape characters. Only flag backslashes that are clearly file path separators.

## Content Freshness

### No Time-Sensitive Content

**What to check:** Skill files do not contain hardcoded dates, or relative time references like "recently", "new", "currently", "as of", "just released", "latest version".

**How to verify:** Search for:
- Date patterns: `20[0-9]{2}`, month names adjacent to years
- Relative time words: `recently`, `new` (as in "new feature"), `currently`, `as of`, `just released`, `latest`

**Why it matters:** Skills persist across time. "The new API" becomes "the old API" silently. "As of 2025" becomes stale by 2026. Content should describe the current state without temporal anchoring.

**Common false positives:**
- Version numbers that happen to contain year-like patterns (`v2024.1`)
- The word "new" in technical context ("create a new file", "new instance")
- Dates in example output templates (showing what output looks like, not making temporal claims)

Use judgment: flag temporal claims about the external world, not incidental use of date-like patterns.
