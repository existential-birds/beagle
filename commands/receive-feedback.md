---
description: Process code review feedback from a file with verification-first discipline
---

# Receive Feedback Command

Process external code review feedback using the receive-feedback skill.

## Usage

```
/receive-feedback path/to/feedback.md
```

## Workflow

1. **Read** the feedback file at `$ARGUMENTS`
2. **Parse** individual feedback items (numbered, bulleted, or freeform)
3. **Load skill** using the Skill tool: `Skill(skill: "beagle:receive-feedback")`
4. **Process** each item through verify → evaluate → execute (as defined in the skill)
5. **Produce** structured response summary (per skill's RESPONSE.md)

## Expected Feedback File Format

The feedback file should contain numbered or bulleted items:

```markdown
1. Remove unused import on line 15
2. Add error handling to the API call
3. Consider using a generator for large datasets
4. Fix typo in variable name: `usr` → `user`
```

Or freeform prose - extract actionable items from the text.

## Example

```
/receive-feedback reviews/pr-123-feedback.md
```

Reads the file, processes each item with technical verification,
and outputs a structured response table.
