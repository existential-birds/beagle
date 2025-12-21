---
description: create claude code skills with comprehensive best practices and patterns
---
# Skill Builder

Create, validate, and refine Claude Code skills following official best practices.

## Workflow Overview

```
1. Gather Requirements → 2. Design Structure → 3. Write SKILL.md → 4. Add Supporting Files → 5. Validate → 6. Test
```

## Instructions

### Phase 1: Gather Requirements

Before writing any skill, collect this information from the user:

**Required:**
- What capability should the skill provide?
- When should Claude invoke this skill (triggers)?
- What domain knowledge is needed that Claude doesn't have?

**Optional:**
- Are there utility scripts needed?
- Should tool access be restricted (`allowed-tools`)?
- What files/references should be included?

Ask clarifying questions if the scope is unclear. Skills should be focused on one capability.

### Phase 2: Design the Structure

Determine the skill complexity:

**Simple Skill (single file):**
```
skill-name/
└── SKILL.md
```

Use when: Single capability, no scripts, under 200 lines of content.

**Multi-file Skill (progressive disclosure):**
```
skill-name/
├── SKILL.md           # Overview + navigation (under 500 lines)
├── reference.md       # Detailed API/schema info
├── examples.md        # Extended examples
└── scripts/           # Utility scripts
    ├── helper.py
    └── validate.py
```

Use when: Complex domain, multiple sub-capabilities, utility scripts needed.

### Phase 3: Write SKILL.md

#### Frontmatter Requirements

```yaml
---
name: skill-name-here
description: What it does and when to use it. Include trigger keywords.
allowed-tools: Read, Grep, Glob  # Optional: restrict tool access
---
```

**Name rules:**
- Lowercase letters, numbers, hyphens only
- Maximum 64 characters
- Use gerund form preferred: `processing-pdfs`, `generating-commits`
- No reserved words: "anthropic", "claude"

**Description rules:**
- Maximum 1024 characters
- Write in third person: "Processes X" not "I can process X"
- Include BOTH what it does AND when to use it
- Include trigger keywords users would naturally say

**Description pattern:**
```
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

<For complex tasks, provide checklists Claude can track>

## Examples

<Input/output pairs showing desired style and output>

## Advanced

<Link to additional files if needed>
For detailed reference, see [reference.md](reference.md).
```

### Phase 4: Apply Best Practices

#### Conciseness Principle

**Default assumption:** Claude is already very smart.

Only add context Claude doesn't have. Challenge each piece of information:
- "Does Claude really need this explanation?"
- "Can I assume Claude knows this?"
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
\`\`\`python
import pdfplumber
with pdfplumber.open("file.pdf") as pdf:
    text = pdf.pages[0].extract_text()
\`\`\`
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
\`\`\`bash
python scripts/migrate.py --verify --backup
\`\`\`
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

```
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
```
feat(auth): implement JWT-based authentication

Add login endpoint and token validation middleware
```

**Example 2:**
Input: Fixed bug where dates displayed incorrectly
Output:
```
fix(reports): correct date formatting in timezone conversion

Use UTC timestamps consistently across report generation
```
````

#### Progressive Disclosure

Reference additional files instead of including everything:

```markdown
## Advanced Features

**Form filling**: See [FORMS.md](FORMS.md) for complete guide
**API reference**: See [REFERENCE.md](REFERENCE.md) for all methods
**Examples**: See [EXAMPLES.md](EXAMPLES.md) for common patterns
```

**Critical:** Keep references one level deep from SKILL.md. Don't create chains of references.

### Phase 5: Validation Checklist

Before finalizing, verify:

**Core Quality:**
- [ ] Description is specific and includes trigger keywords
- [ ] Description includes both what it does AND when to use it
- [ ] Description is written in third person
- [ ] Name uses lowercase-hyphen format
- [ ] SKILL.md body is under 500 lines
- [ ] No time-sensitive information
- [ ] Consistent terminology throughout
- [ ] Examples are concrete, not abstract
- [ ] File references are one level deep
- [ ] Workflows have clear steps

**Technical:**
- [ ] Valid YAML frontmatter (no tabs, correct syntax)
- [ ] No Windows-style paths (use forward slashes)
- [ ] Required packages listed if applicable
- [ ] Scripts have explicit error handling

**If using `allowed-tools`:**
- [ ] Only necessary tools are listed
- [ ] Tool names are correct (Read, Grep, Glob, Edit, Write, Bash, etc.)

### Phase 6: Test the Skill

After creating the skill:

1. **Place in correct location:**
   - Personal: `~/.claude/skills/skill-name/SKILL.md`
   - Project: `.claude/skills/skill-name/SKILL.md`

2. **Restart Claude Code** to load the skill

3. **Test with natural language** that matches your description triggers:
   ```
   User: "Help me extract text from this PDF"
   → Should invoke skill with "PDF" trigger
   ```

4. **Verify Claude navigates correctly** to reference files when needed

5. **Iterate based on observation:**
   - Does Claude find the right information?
   - Does Claude apply rules correctly?
   - Are there missing examples or edge cases?

## Anti-Patterns to Avoid

**DON'T:**
- Use Windows-style paths (`scripts\helper.py`)
- Offer too many options without a default
- Include time-sensitive information
- Use inconsistent terminology
- Create deeply nested file references
- Assume tools are installed without documenting
- Write overly verbose explanations Claude already knows
- Use first or second person in descriptions

**DO:**
- Provide a single recommended approach with alternatives noted
- Use consistent terminology throughout
- Structure longer files with table of contents
- Document package requirements explicitly
- Trust Claude's existing knowledge
- Write descriptions that help Claude select the right skill

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

- **Full reference**: See [reference.md](reference.md)
- **Examples**: See [examples.md](examples.md)
- **Utility scripts**: See [scripts/](scripts/)
```

**reference.md:**
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

```
Created skill: .claude/skills/reviewing-code/

Files:
├── SKILL.md (245 lines) - Core instructions and checklists
├── security-patterns.md - Common security issues to check
└── examples.md - Example review outputs

Description: "Reviews code changes for production readiness, checking code quality, architecture, testing, and security. Use when reviewing PRs, checking code before merge, or auditing code quality."

Next steps:
1. Review the generated files
2. Restart Claude Code to load the skill
3. Test with: "Review the changes in my current branch"
```

## Guidelines

**When the user asks for a skill:**
1. Ask clarifying questions about scope and triggers
2. Propose the structure (simple vs multi-file)
3. Write the SKILL.md following all patterns above
4. Run through the validation checklist
5. Explain how to test the skill

**Iterative refinement:**
If the user reports the skill isn't working:
1. Check if description triggers match user's natural language
2. Verify YAML syntax is valid
3. Ensure file paths are correct
4. Review if instructions are clear enough for the task
