---
description: Generate first-draft technical documentation from code analysis
---

# Draft Docs

Generate Reference or How-To documentation drafts to `docs/drafts/` for review before publishing.

## Arguments

- **Topic prompt:** Description of what to document (e.g., "Document the WebSocket API")
- **--publish [file]:** Move reviewed draft to final location and update navigation

## Mode 1: Generate Draft

```
/beagle:draft-docs "Document the authentication middleware"
```

### Step 1: Parse Input

Extract from the prompt:

1. **Topic:** What to document (e.g., "authentication middleware")
2. **Content type:** Detect from keywords:

| Keywords | Type | Skill |
|----------|------|-------|
| "how to", "guide", "steps", "configure", "set up" | How-To | `howto-docs` |
| "API", "reference", "parameters", "function", "endpoint" | Reference | `reference-docs` |

If ambiguous, ask: "Should this be a Reference doc (technical lookup) or How-To guide (task completion)?"

### Step 2: Load Skills

Always load both:

1. `beagle:docs-style` - Core writing principles
2. Detected type skill:
   - `beagle:reference-docs` for Reference
   - `beagle:howto-docs` for How-To

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

### Step 5: Write Draft

1. **Create output path:**
   - `docs/drafts/{slug}.md`
   - Slug from topic: "WebSocket API" → `websocket-api.md`

2. **Ensure directory exists:**
   ```bash
   mkdir -p docs/drafts
   ```

3. **Write the draft file**

4. **Report to user:**
   ```markdown
   ## Draft Created

   **File:** `docs/drafts/{slug}.md`
   **Type:** Reference | How-To
   **Based on:** [list of analyzed symbols/files]

   ### Next Steps

   1. Review the draft for accuracy
   2. Add any missing context or examples
   3. When ready, publish with:
      ```
      /beagle:draft-docs --publish docs/drafts/{slug}.md
      ```
   ```

## Mode 2: Publish Draft

```
/beagle:draft-docs --publish docs/drafts/websocket-api.md
```

### Step 1: Read Draft

Read the draft file and extract:
- Title
- Content type (from frontmatter or structure)

### Step 2: Determine Destination

Ask user which section:

```markdown
Where should this document go?

1. **API Reference** → `docs/api/{slug}.md`
2. **Guides** → `docs/guides/{slug}.md`
3. **How-To** → `docs/how-to/{slug}.md`
4. **Other** → Specify path
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

## Content Type Detection

### Reference Indicators

- Prompt mentions: API, endpoint, function, method, class, type, parameters, returns
- Target is a specific symbol or set of symbols
- User wants technical specification

### How-To Indicators

- Prompt mentions: how to, guide, steps, configure, set up, integrate
- Target is a task or workflow
- User wants procedural instructions

## Rules

- Always load `docs-style` skill for every draft
- Generate to `docs/drafts/` - never directly to final location
- Include frontmatter with title and description
- Use realistic examples from actual codebase
- Reference analyzed symbols in draft metadata
- Preserve existing navigation structure when publishing
- Ask before overwriting existing files
