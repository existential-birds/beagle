---
name: draft-docs
description: Generate first-draft technical documentation from code analysis
disable-model-invocation: true
---

# Draft Docs

Generate Tutorial, How-To, Reference, or Explanation documentation drafts to `docs/drafts/` for review before publishing. These are the four [Diataxis](https://diataxis.fr/) types — see [docs-style/references/diataxis-compass.md](../docs-style/references/diataxis-compass.md) for the full type-selection procedure.

## Arguments

- **Topic prompt:** Description of what to document (e.g., "Document the WebSocket API")
- **--publish [file]:** Move reviewed draft to final location and update navigation

## Mode 1: Generate Draft

Invoke the **draft-docs** skill with a topic prompt, e.g. `draft-docs "Document the authentication middleware"`.

### Step 0: Gather Context

Before parsing input, gather project context:

```bash
# Check for existing docs structure
ls -la docs/ 2>/dev/null || echo "No docs/ directory found"

# Identify documentation framework
ls docs/navigation.json docs/mint.json docs/docusaurus.config.js docs/mkdocs.yml 2>/dev/null | head -1

# Check for existing drafts
ls docs/drafts/*.md 2>/dev/null || echo "No existing drafts"

# Get recent code changes for context
git diff --name-only $(git merge-base HEAD main)..HEAD 2>/dev/null | head -20
```

**Capture:**
- Docs structure: `docs/` subdirectories present
- Navigation system: `navigation.json`, `mint.json`, or other config
- Tech stack hints: from file extensions and imports in changed files
- Existing drafts: to avoid duplicates

### Step 1: Parse Input

Extract from the prompt:

1. **Topic:** What to document (e.g., "authentication middleware")
2. **Content type:** Detect from keywords:

| Keywords | Type | Skill |
|----------|------|-------|
| "tutorial", "learn", "getting started", "first", "onboarding", "introduction", "build a/your" | Tutorial | [tutorial-docs](../tutorial-docs/SKILL.md) |
| "how to", "guide", "steps", "configure", "set up" | How-To | [howto-docs](../howto-docs/SKILL.md) |
| "API", "reference", "parameters", "function", "endpoint" | Reference | [reference-docs](../reference-docs/SKILL.md) |
| "why", "how does it work", "concept", "background", "rationale", "design decision", "architecture", "trade-offs" | Explanation | [explanation-docs](../explanation-docs/SKILL.md) |

These four types are the quadrants of the [Diátaxis](https://diataxis.fr/) framework — Tutorial (learning), How-To (task), Reference (information), and Explanation (understanding). Decide with the two compass questions — *action or cognition? acquisition or application?* — detailed in [docs-style/references/diataxis-compass.md](../docs-style/references/diataxis-compass.md). Two distinctions resolve most ambiguity:

- **Tutorial vs. How-To** both give action steps, but a Tutorial teaches a beginner through a guaranteed-to-succeed lesson (study), while a How-To directs a competent user toward a real goal (work). If the reader is learning the product for the first time, it's a Tutorial; if they already know it and want to get a task done, it's a How-To.
- **Reference vs. Explanation** both serve theoretical knowledge, but Reference *states* neutral facts to consult at the keyboard, while Explanation *discusses* reasoning and context to read away from it. If the request wants opinions, history, or trade-offs, it's Explanation; if it wants an authoritative spec, it's Reference.

If ambiguous, ask: "Should this be a Tutorial (learning by doing), a How-To guide (task completion), a Reference doc (technical lookup), or an Explanation (understanding the why behind a concept)?"

### Step 2: Load Skills

Always load both:

1. [docs-style](../docs-style/SKILL.md) - Core writing principles
2. Detected type skill:
   - [tutorial-docs](../tutorial-docs/SKILL.md) for Tutorial
   - [howto-docs](../howto-docs/SKILL.md) for How-To
   - [reference-docs](../reference-docs/SKILL.md) for Reference
   - [explanation-docs](../explanation-docs/SKILL.md) for Explanation

### Step 3: Analyze Code

Search the codebase for relevant code:

1. **Symbol search:** Find functions, classes, types matching the topic
2. **File search:** Locate related files by name patterns
3. **Reference search:** Find usage examples

Gather:
- Function/method signatures
- Type definitions
- Existing comments/docstrings
- Usage patterns in tests or examples

### Step 4: Generate Draft

Apply the loaded skills to generate documentation:

**For Tutorial docs:**
- Follow `tutorial-docs` template structure
- Title names what the reader will build ("Build your first X"), not what they'll learn
- Use first-person plural — "In this tutorial, we will…" — to keep the teacher/learner narrative
- Give one clear path with no choices or alternatives
- After every step, state what the reader should see ("You should see…")
- Ruthlessly minimize explanation; link out to Explanation docs for the "why"

**For Reference docs:**
- Follow `reference-docs` template structure
- Document all parameters with types
- Include complete, runnable examples from actual code
- Add Related section linking to connected symbols

**For How-To docs:**
- Follow `howto-docs` template structure
- Start title with "How to"
- List concrete prerequisites
- Break into single-action steps
- Include verification section

**For Explanation docs:**
- Follow `explanation-docs` template structure
- Frame the title around understanding a concept ("Understanding X"), not a task
- Open by stating what the reader will understand after reading
- Explain the *why* behind design decisions, not just what exists
- Discuss trade-offs honestly and acknowledge alternatives that were considered
- Write flowing prose for reading away from the keyboard — no steps to follow

### Step 5: Write Draft

1. **Create output path:**
   - `docs/drafts/{slug}.md`
   - Slug from topic: "WebSocket API" → `websocket-api.md`

2. **Ensure directory exists:**
   ```bash
   mkdir -p docs/drafts
   ```

3. **Write the draft file** (see **Hard gates** → Write gate: confirm file on disk before the next step)

4. **Report to user:**
   ```markdown
   ## Draft Created

   **File:** `docs/drafts/{slug}.md`
   **Type:** Tutorial | How-To | Reference | Explanation
   **Based on:** [list of analyzed symbols/files]

   ### Next Steps

   1. Review the draft for accuracy
   2. Add any missing context or examples
   3. When ready, publish by invoking the **draft-docs** skill with `--publish docs/drafts/{slug}.md`
   ```

### Step 6: End-of-Run Verification

Verify draft generation completed successfully:

```bash
# Confirm draft file exists
ls -la docs/drafts/{slug}.md

# Validate frontmatter (YAML header)
head -10 docs/drafts/{slug}.md | grep -E "^---$|^title:|^description:"

# Check markdown syntax (if markdownlint available)
markdownlint docs/drafts/{slug}.md 2>/dev/null || echo "markdownlint not available"
```

**Verification Checklist:**
- [ ] Draft file created at `docs/drafts/{slug}.md`
- [ ] Frontmatter includes `title` and `description`
- [ ] Content type matches detected type (Tutorial, How-To, Reference, or Explanation)
- [ ] Code examples are complete and runnable (Tutorial/How-To/Reference); concepts grounded in real design decisions (Explanation)
- [ ] Tutorial drafts give a single path with observable "You should see…" outcomes at each step
- [ ] All analyzed symbols referenced in draft

If any verification fails, report the specific issue and offer to regenerate.

## Mode 2: Publish Draft

Invoke the **draft-docs** skill with the `--publish` flag, e.g. `draft-docs --publish docs/drafts/websocket-api.md`.

### Step 1: Read Draft

Read the draft file and extract:
- Title
- Content type (from frontmatter or structure)

### Step 2: Determine Destination

Ask user which section:

```markdown
Where should this document go?

1. **Tutorials** → `docs/tutorials/{slug}.md`
2. **API Reference** → `docs/api/{slug}.md`
3. **Guides** → `docs/guides/{slug}.md`
4. **How-To** → `docs/how-to/{slug}.md`
5. **Concepts / Explanation** → `docs/concepts/{slug}.md`
6. **Other** → Specify path
```

### Step 3: Move File

```bash
mv docs/drafts/{slug}.md {destination}/{slug}.md
```

### Step 4: Update Navigation

Check for `docs/navigation.json` and update navigation:

1. **Read current navigation.json**
2. **Find appropriate navigation group**
3. **Add new page entry**
4. **Write updated navigation.json**

Example update:
```json
{
  "navigation": [
    {
      "group": "API Reference",
      "pages": [
        "api/existing-page",
        "api/websocket-api"
      ]
    }
  ]
}
```

### Step 5: Report

```markdown
## Published

**From:** `docs/drafts/{slug}.md`
**To:** `{destination}/{slug}.md`
**Navigation:** Updated `docs/navigation.json`

The document is now live in your docs.
```

### Step 6: End-of-Run Verification

Verify publish completed successfully:

```bash
# Confirm file moved to destination
ls -la {destination}/{slug}.md

# Confirm draft removed
ls docs/drafts/{slug}.md 2>/dev/null && echo "WARNING: Draft still exists" || echo "Draft cleaned up"

# Verify navigation updated
grep -q "{slug}" docs/navigation.json && echo "Navigation includes new page" || echo "WARNING: Navigation may need manual update"

# Check markdown syntax at final location
markdownlint {destination}/{slug}.md 2>/dev/null || echo "markdownlint not available"
```

**Verification Checklist:**
- [ ] Document moved to `{destination}/{slug}.md`
- [ ] Draft removed from `docs/drafts/`
- [ ] Navigation file updated with new page entry
- [ ] No broken links in navigation structure
- [ ] Document accessible at expected URL path

If any verification fails, report the specific issue and offer remediation steps.

## Content Type Detection

### Tutorial Indicators

- Prompt mentions: tutorial, learn, getting started, first, onboarding, introduction, "build a/your"
- Target is a beginner's first successful experience with the product
- User wants a guided, learn-by-doing lesson, not a task or a lookup

### Reference Indicators

- Prompt mentions: API, endpoint, function, method, class, type, parameters, returns
- Target is a specific symbol or set of symbols
- User wants technical specification

### How-To Indicators

- Prompt mentions: how to, guide, steps, configure, set up, integrate
- Target is a task or workflow
- User wants procedural instructions

### Explanation Indicators

- Prompt mentions: why, how it works, concept, background, rationale, design decision, architecture, trade-offs
- Target is a concept or system the reader wants to understand, not operate
- User wants context and reasoning to read away from the keyboard, not steps to follow

## Rules

- Always load `docs-style` skill for every draft
- Generate to `docs/drafts/` - never directly to final location
- Include frontmatter with title and description
- Use realistic examples from actual codebase
- Reference analyzed symbols in draft metadata
- Preserve existing navigation structure when publishing
- Ask before overwriting existing files

## Hard gates (sequenced)

Do not skip ahead: each **Pass** must be true before the next step. Use commands or explicit artifacts—not internal assurance.

### Generate draft (Mode 1)

1. **Context gate — Pass:** Step 0 commands ran (or equivalent) and you recorded at least one concrete outcome: e.g. `docs/` listing snippet, or explicit note that `docs/` is missing and will be created.
2. **Type gate — Pass:** Tutorial vs How-To vs Reference vs Explanation is decided using the keyword table and the two compass questions **or** the user’s explicit answer (quote or paraphrase with “user chose …”). Do not start **Step 3: Analyze Code** until this is locked.
3. **Skills gate — Pass:** Before analysis, both are in play: [docs-style](../docs-style/SKILL.md) and the type skill ([tutorial-docs](../tutorial-docs/SKILL.md), [howto-docs](../howto-docs/SKILL.md), [reference-docs](../reference-docs/SKILL.md), or [explanation-docs](../explanation-docs/SKILL.md)). In your run, name the two skills loaded (paths)—not “I reviewed writing guidelines.”
4. **Write gate — Pass:** After writing the draft, `test -f docs/drafts/{slug}.md` succeeds (or `ls` shows the file). Only then emit the **Draft Created** block.

### Publish draft (Mode 2)

1. **Destination gate — Pass:** User chose a destination (from the menu or a specific path). Resolve `{destination}` to a full path; **Pass** when the parent directory exists (`test -d "$(dirname "$path")"` or project-appropriate check) **and** you are not overwriting an existing file without explicit user approval.
2. **Move gate — Pass:** After `mv`, the file exists at `{destination}/{slug}.md` (`test -f`) and navigation updates (if applicable) are applied before claiming **Published**.
