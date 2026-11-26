# Skill Builder Guide

Create, validate, and refine Agent Skills following `agentskills.io` specification and progressive disclosure best practices.

## Workflow Overview

```text
1. Gather Requirements → 2. Design Structure → 3. Write SKILL.md → 4. Add Supporting Files → 5. Validate → 6. Test
```

## Instructions

### Phase 1: Gather Requirements

Before writing any skill, collect this information from the user:

**Required:**
- What capability should the skill provide?
- When should the agent invoke this skill (triggers)?
- What domain knowledge is needed that the agent doesn't have?

**Optional:**
- Are there utility scripts or static assets needed?
- Should tool access be pre-approved (`allowed-tools`)?
- What files/references should be included?

Ask clarifying questions if the scope is unclear. Skills should be focused on one capability.

### Phase 2: Design the Structure

Determine the skill complexity (you can also scaffold with `npx skills init <skill-name>`):

**Simple Skill (single file):**
```text
skill-name/
└── SKILL.md
```

Use when: Single capability, no scripts, under 200 lines of content.

**Multi-file Skill (progressive disclosure):**
```text
skill-name/
├── SKILL.md                  # Overview + navigation (under 500 lines)
├── references/               # Detailed reference docs loaded on demand
│   ├── reference.md
│   └── examples.md
├── scripts/                  # Executable utility scripts
│   ├── helper.py
│   └── validate.py
└── assets/                   # Static templates, schemas, images
    └── template.json
```

Use when: Complex domain, multiple sub-capabilities, utility scripts, or static assets needed. Keep `SKILL.md` as the only `.md` file at the skill root.

### Phase 3: Write SKILL.md

#### Frontmatter Requirements (`agentskills.io/specification`)

```yaml
---
name: skill-name-here
description: What it does and when to use it. Include trigger keywords.
license: MIT                  # Optional
compatibility: Designed for Node 20+  # Optional (<= 500 chars)
metadata:                     # Optional string-to-string map
  author: example-org
allowed-tools: Bash(git:*) Read  # Optional, experimental: space-delimited string
---
```

**Core fields only:** Only use `name`, `description`, and optional `license`, `compatibility`, `metadata`, `allowed-tools`. **Do NOT** add non-spec harness extension keys (`disable-model-invocation`, `user-invocable`, `autoContext`, `dependencies`, `triggers`), as strict validators such as `skills-ref validate` reject unexpected frontmatter fields.

**Name rules:**
- Lowercase letters, numbers, and single hyphens only (`^[a-z0-9]+(-[a-z0-9]+)*$`)
- No leading, trailing, or consecutive (`--`) hyphens
- Maximum 64 characters
- **Must match the parent directory name** (`skills/<skill-name>/SKILL.md`)
- Use gerund or action-noun form preferred: `processing-pdfs`, `generating-commits`
- Vendor-neutrality convention: avoid embedding vendor names like `"anthropic"` or `"claude"` unless the skill specifically integrates with that vendor's API

**Description rules:**
- Non-empty string, maximum 1024 characters
- Write in third person: "Processes X" not "I can process X"
- Quote the string in YAML if it contains `: ` or `#`
- Include BOTH what it does AND when to use it
- Include trigger keywords users would naturally say

**Description pattern:**
```text
<what it does>. <trigger conditions>.
```

**Good examples:**
```yaml
description: Extract text and tables from PDF files, fill forms, merge documents. Use when working with PDF files or when the user mentions PDFs, forms, or document extraction.

description: Analyze Excel spreadsheets, create pivot tables, generate charts. Use when analyzing Excel files, spreadsheets, tabular data, or .xlsx files.

description: Generate descriptive commit messages by analyzing git diffs. Use when the user asks for help writing commit messages or reviewing staged changes.
```

**Bad examples:**
```yaml
description: Helps with documents  # Too vague
description: I can process data    # Wrong person, too vague
description: Does stuff with files # Useless
```

#### Body Structure

Use this template:

```markdown
# Skill Name

## Quick Start

<Minimal working example - 3-5 lines max>

## Instructions

<Step-by-step guidance - be specific about WHAT to do>

## Workflows

<For complex tasks, provide checklists the agent can track>

## Examples

<Input/output pairs showing desired style and output>

## Advanced

<Link to additional files if needed>
For detailed reference, see [references/reference.md](references/reference.md).
```

### Phase 4: Apply Best Practices

#### Conciseness Principle

**Default assumption:** the agent is already very smart.

Only add context the agent doesn't have. Challenge each piece of information:
- "Does the agent really need this explanation?"
- "Can I assume the agent knows this?"
- "Does this paragraph justify its token cost?"

**Bad (verbose):**
```markdown
PDF (Portable Document Format) files are a common file format that contains
text, images, and other content. To extract text from a PDF, you'll need to
use a library. There are many libraries available...
```

**Good (concise):**
```markdown
Use pdfplumber for text extraction:
```python
import pdfplumber
with pdfplumber.open("file.pdf") as pdf:
    text = pdf.pages[0].extract_text()
```
```

#### Degrees of Freedom

Match specificity to task fragility:

**High freedom** (text-based instructions) - when multiple approaches are valid:
```markdown
## Code review process
1. Analyze the code structure and organization
2. Check for potential bugs or edge cases
3. Suggest improvements for readability
```

**Low freedom** (exact commands) - when operations are fragile:
```markdown
## Database migration
Run exactly this script:
```bash
python scripts/migrate.py --verify --backup
```
Do not modify the command or add additional flags.
```

#### Feedback Loops

For quality-critical tasks, add validation steps:

```markdown
## Editing Process
1. Make your edits
2. **Validate immediately**: `python scripts/validate.py`
3. If validation fails:
   - Review the error message
   - Fix the issues
   - Run validation again
4. **Only proceed when validation passes**
```

#### Checklists for Complex Workflows

Provide copyable checklists:

````markdown
## Form Filling Workflow

Copy this checklist and track progress:

```text
Task Progress:
- [ ] Step 1: Analyze the form
- [ ] Step 2: Create field mapping
- [ ] Step 3: Validate mapping
- [ ] Step 4: Fill the form
- [ ] Step 5: Verify output
```
````

#### Examples Pattern

Show input/output pairs for style guidance:

````markdown
## Commit Message Format

**Example 1:**
Input: Added user authentication with JWT tokens
Output:
```text
feat(auth): implement JWT-based authentication

Add login endpoint and token validation middleware
```

**Example 2:**
Input: Fixed bug where dates displayed incorrectly
Output:
```text
fix(reports): correct date formatting in timezone conversion

Use UTC timestamps consistently across report generation
```
````

#### Progressive Disclosure

Reference additional files under `references/` instead of including everything in `SKILL.md`:

```markdown
## Advanced Features

**Form filling**: See [references/forms.md](references/forms.md) for complete guide
**API reference**: See [references/reference.md](references/reference.md) for all methods
**Examples**: See [references/examples.md](references/examples.md) for common patterns
```

**Critical:** Keep references one level deep from `SKILL.md`. Don't create chains of references. If linking to a sibling skill, use `../<target-skill>/SKILL.md` and name the skill explicitly in prose so single-skill installations remain clear.

### Phase 5: Validation Checklist

Before finalizing, verify:

**Core Quality:**
- [ ] Description is specific and includes trigger keywords
- [ ] Description includes both what it does AND when to use it
- [ ] Description is written in third person (<= 1024 chars)
- [ ] `name` uses lowercase-hyphen format (`^[a-z0-9]+(-[a-z0-9]+)*$`, <= 64 chars) and matches parent directory name
- [ ] `SKILL.md` body is under 500 lines
- [ ] No time-sensitive information
- [ ] Consistent terminology throughout
- [ ] Examples are concrete, not abstract
- [ ] File references live under `references/` and are one level deep
- [ ] Workflows have clear steps

**Technical:**
- [ ] Valid YAML frontmatter (no tabs, correct quoting, only `agentskills.io` allowed fields)
- [ ] No Windows-style paths (use forward slashes)
- [ ] Required packages listed if applicable
- [ ] Scripts support `--help` and avoid interactive TTY prompts
- [ ] `skills-ref validate <skill-dir>` passes (when installed)
- [ ] `npx skills add . --list` discovers the skill cleanly without warnings

**If using `allowed-tools` (optional/experimental):**
- [ ] Only necessary capabilities are listed
- [ ] Uses space-delimited syntax per `agentskills.io/specification` (not comma-separated)

### Phase 6: Test the Skill

After creating the skill:

1. **Place in correct location**:
   - Project-local installed skill: `.agents/skills/<skill-name>/SKILL.md`
   - Global user skill: `~/.agents/skills/<skill-name>/SKILL.md`
   - Skills repository source: `skills/<skill-name>/SKILL.md`

2. **Verify discovery and spec compliance**:
   ```bash
   npx skills add . --list
   skills-ref validate "skills/<skill-name>"
   ```

3. **Test with natural language** that matches your description trigger phrases:
   ```text
   User: "Help me extract text from this PDF"
   → Should invoke skill with "PDF" trigger
   ```

4. **Verify the agent navigates correctly** to `references/` files when needed

5. **Iterate based on observation:**
   - Does the agent find the right information?
   - Does the agent apply rules correctly?
   - Are there missing examples or edge cases?

## Anti-Patterns to Avoid

**DON'T:**
- Use Windows-style paths (`scripts\helper.py`)
- Offer too many options without a default
- Include time-sensitive information
- Use inconsistent terminology
- Create deeply nested file references or extra `.md` files beside `SKILL.md`
- Add non-spec frontmatter keys or harness-specific tool names
- Assume tools are installed without documenting
- Write overly verbose explanations the agent already knows
- Use first or second person in descriptions

**DO:**
- Provide a single recommended approach with alternatives noted
- Use consistent terminology throughout
- Structure longer files with table of contents
- Document package requirements explicitly
- Trust the agent's existing knowledge
- Write descriptions that help the agent select the right skill

## Template: Simple Skill

```yaml
---
name: your-skill-name
description: <What it does>. Use when <trigger conditions>.
---

# Your Skill Name

## Quick Start

<Minimal example - get user productive immediately>

## Instructions

<Clear, numbered steps for common use cases>

## Examples

<2-3 input/output examples showing desired style>
```

## Template: Multi-File Skill

**SKILL.md:**
```yaml
---
name: your-skill-name
description: <What it does>. Use when <trigger conditions>.
---

# Your Skill Name

## Quick Start

<Minimal example>

## Common Tasks

### Task A
<Brief instructions>

### Task B
<Brief instructions>

## Advanced

- **Full reference**: See [references/reference.md](references/reference.md)
- **Examples**: See [references/examples.md](references/examples.md)
- **Utility scripts**: See [scripts/](scripts/)
```

**references/reference.md:**
```markdown
# Reference

## Contents
- Section A
- Section B
- Section C

## Section A
<Detailed content>
...
```

## Example Output

After gathering requirements for a "code-review" skill:

```text
Created skill: skills/reviewing-code/ (or .agents/skills/reviewing-code/)

Files:
├── SKILL.md (245 lines) - Core instructions and checklists
└── references/
    ├── security-patterns.md - Common security issues to check
    └── examples.md - Example review outputs

Description: "Reviews code changes for production readiness, checking code quality, architecture, testing, and security. Use when reviewing PRs, checking code before merge, or auditing code quality."

Next steps:
1. Review the generated files
2. Validate with `skills-ref validate` and `npx skills add . --list`
3. Test with: "Review the changes in my current branch"
```

## Guidelines

**When the user asks for a skill:**
1. Ask clarifying questions about scope and triggers
2. Propose the structure (simple vs multi-file)
3. Write the `SKILL.md` following all patterns above
4. Run through the validation checklist
5. Explain how to test the skill

**Iterative refinement:**
If the user reports the skill isn't working:
1. Check if description triggers match user's natural language
2. Verify YAML syntax is valid and `name` matches the directory
3. Ensure `references/` file paths are correct
4. Review if instructions are clear enough for the task
