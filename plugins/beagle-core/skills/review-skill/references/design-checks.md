# Design Checks

All design checks emit **MEDIUM confidence** issues. These involve judgment — flag only when the problem is clear, not when the approach is merely different from what you'd choose.

## Description Trigger Quality

### Specific Enough to Trigger Accurately

**What to check:** The description provides enough specificity that an agent can distinguish this skill from others in a marketplace with 100+ skills. Generic descriptions cause over-triggering (selected for unrelated tasks) or under-triggering (missed for relevant tasks).

**How to verify:** Ask: "If I had 100 skills loaded, would this description uniquely identify when to use this one?" Check for:
- Specific domain terms (not just "code", "files", "data")
- Concrete trigger conditions (not just "Use when needed")
- Technology or format names when applicable

**Good examples:**
```yaml
# Specific domain + concrete triggers
description: Reviews Go code for idiomatic patterns, error handling, concurrency safety, and common mistakes. Use when reviewing .go files, checking error handling, goroutine usage, or interface design.

# Clear capability boundary + activation context
description: Extract text and tables from PDF files, fill forms, merge documents. Use when working with PDF files or when the user mentions PDFs, forms, or document extraction.
```

**Bad examples:**
```yaml
# Too vague — matches almost anything
description: Helps with code quality

# No trigger context — when should this activate?
description: Processes documents and generates output

# Overly broad — would trigger on any development task
description: Assists with software development tasks and best practices
```

**When NOT to flag:** A description that covers a genuinely broad domain (e.g., a general Python review skill) is fine as long as the trigger conditions are specific. Breadth of capability is different from vagueness of description.

### Not Overlapping Excessively with Other Skills

**What to check:** The description's trigger surface doesn't substantially duplicate another skill in the same marketplace. Some overlap is expected (a Python review skill and a FastAPI review skill both mention Python), but the descriptions should have distinct primary trigger conditions.

**How to verify:** Compare the new/changed skill's description against other skills in the same plugin and marketplace. Flag if the primary trigger keywords are nearly identical and the capability statements don't differentiate.

**When NOT to flag:** Complementary skills that cover different aspects of the same domain (e.g., `review-python` for general Python and `review-fastapi` for FastAPI-specific patterns) are expected to share some keywords.

## Progressive Disclosure

### Main Concepts in SKILL.md, Details in References

**What to check:** SKILL.md provides the core workflow and navigation. Detailed reference material, extensive examples, API specifications, and long checklists live in separate reference files.

**How to verify:** Check if SKILL.md contains:
- Long code examples (>20 lines) that could be in a reference file
- Detailed API specifications or schema definitions
- Exhaustive checklists (>15 items) without summarization
- Content that only applies to specific sub-tasks (should load on demand)

**Good pattern:**
```markdown
# SKILL.md
## Quick Start
[3-5 lines]

## Workflow
[Core steps with brief descriptions]

## References
- Detailed API reference: [reference.md](reference.md)
- Extended examples: [examples.md](examples.md)
```

**Bad pattern:**
```markdown
# SKILL.md (400+ lines)
## API Reference
[200 lines of API details]
## Examples
[150 lines of examples]
## Edge Cases
[50 lines of edge cases]
```

**When NOT to flag:**
- Simple skills under 200 lines that don't need splitting
- Skills where all content is essential for every invocation (no conditional loading benefit)
- Skills that are already well under the 500-line limit

### Reference Files Organized by Domain

**What to check:** When a skill has multiple reference files, they're organized so the agent can load only what's relevant to the current task.

**How to verify:** Each reference file should serve a distinct purpose or domain. Files named `reference1.md`, `reference2.md` are a smell — prefer descriptive names like `api-errors.md`, `migration-patterns.md`.

**When NOT to flag:** Skills with a single reference file don't need domain organization.

## Degrees of Freedom

### Calibrated to Task Fragility

**What to check:** Instructions match their specificity to the task's fragility:
- **High freedom** (text-based guidance) for judgment calls where multiple approaches are valid
- **Medium freedom** (templates/pseudocode with parameters) for tasks with a preferred pattern but acceptable variation
- **Low freedom** (exact commands, no modification) for fragile operations where consistency is critical

**How to verify:** Look for mismatches:
- Overly prescriptive instructions for flexible tasks (e.g., exact code for a code review process)
- Overly vague instructions for fragile tasks (e.g., "run the migration script" without specifying the exact command and flags)

**Good examples:**
```markdown
# High freedom — code review (judgment-based)
1. Analyze the code structure and organization
2. Check for potential bugs or edge cases
3. Suggest improvements for readability

# Low freedom — database migration (fragile)
Run exactly: `python scripts/migrate.py --verify --backup`
Do not modify the command or add additional flags.
```

**Bad examples:**
```markdown
# Over-prescriptive for a flexible task
When reviewing code, always check line 1 first, then line 2...

# Under-specified for a fragile task
Run the migration script with appropriate flags.
```

**When NOT to flag:** When the skill consistently uses one freedom level and the domain justifies it (e.g., a deployment skill that is entirely low-freedom because every step is fragile).

## Implementation Leakage

### No Unjustified Library/Tool Prescription

**What to check:** The skill doesn't prescribe specific libraries, tools, or implementations when the domain doesn't require them. A skill providing guidance should describe *what* to do and *why*, leaving *how* to the agent's judgment unless a specific tool is genuinely the only or clearly best option.

**How to verify:** For each library/tool mentioned, ask: "Is this the only reasonable choice, or is the skill leaking implementation preference?" Signals of leakage:
- Mandating a specific HTTP client when any would work
- Requiring a particular testing framework when the project may use a different one
- Prescribing a specific editor command or IDE feature

**When NOT to flag:**
- Skills that are explicitly about a specific tool (e.g., "pdfplumber patterns")
- Cases where a specific tool is genuinely necessary (e.g., a migration script that must use the project's own migrator)
- Utility scripts bundled with the skill (these are part of the skill, not leaked preferences)

## Workflow Quality

### Validation Steps Present

**What to check:** Multi-step workflows include validation or verification steps — they don't fire-and-forget. After a significant action, the workflow should verify the result before proceeding.

**How to verify:** For each workflow with 3+ steps, check that at least one step involves validation, verification, or a check-before-proceeding gate. Look for patterns like:
- "Run validation"
- "Verify output"
- "Check that X before proceeding"
- "If validation fails, return to step N"

**When NOT to flag:**
- Simple workflows (1-2 steps) where the action is self-contained
- Workflows where the final step is inherently a verification (e.g., "run tests")
- Read-only workflows that don't produce artifacts

### No Fire-and-Forget Destructive Operations

**What to check:** If the workflow involves writing files, modifying state, or executing commands with side effects, there's a verification step after the operation.

**When NOT to flag:** Operations that are inherently safe or reversible (e.g., writing to a temp file, creating a git branch).

## Output Format Specification

### Structured Output Has Template or Example

**What to check:** When a skill produces structured output (reports, reviews, formatted documents, data files), the expected format is specified via a template or a concrete example. Prose descriptions of format are insufficient for consistent output.

**How to verify:** If the skill's workflow produces a file or structured response, check that SKILL.md or a reference file contains either:
- A template with placeholders showing the exact structure
- A concrete example of the expected output
- Both (template for structure, example for style)

**Good pattern:**
````markdown
## Output Format

```markdown
## Summary
[1-2 sentences]

## Findings
1. [FILE:LINE] TITLE
   - Issue: ...
   - Fix: ...
```
````

**Bad pattern:**
```markdown
## Output Format

Write a summary followed by a list of findings with file locations.
```

**When NOT to flag:**
- Skills that produce free-form text (creative writing, explanations)
- Skills where the output format is inherently determined by the task (e.g., "generate a commit message")
