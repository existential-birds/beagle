---
name: receive-feedback
description: Process external code review feedback with technical rigor. Use when receiving feedback from another LLM, human reviewer, or CI tool. Verifies claims before implementing, tracks disposition.
disable-model-invocation: false
---

# Receive Feedback

## Overview

Process code review feedback with verification-first discipline.
No performative agreement. Technical correctness over social comfort.

## Quick Reference

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│   VERIFY    │ ──▶ │   EVALUATE   │ ──▶ │   EXECUTE   │
│ (tool-based)│     │ (decision    │     │ (implement/ │
│             │     │  matrix)     │     │  reject/    │
└─────────────┘     └──────────────┘     │  defer)     │
                                         └─────────────┘
```

## Core Principle

**Verify before implementing. Ask before assuming.**

## When To Use

- Receiving code review from another LLM session
- Processing PR review comments
- Evaluating CI/linter feedback
- Handling suggestions from pair programming

## Workflow

For each feedback item:

1. **Verify** - Use tools to check if feedback is technically valid
2. **Evaluate** - Apply decision matrix to determine action
3. **Execute** - Implement, reject with evidence, or defer

## Command Workflow

Use this skill from the `/receive-feedback` command or by invoking it directly with a feedback file path.

1. **Read** the feedback file at `$ARGUMENTS`
2. **Parse** individual feedback items, whether numbered, bulleted, or freeform
3. **Load** this skill: `Skill(skill: "beagle-core:receive-feedback")`
4. **Process** each item through verify → evaluate → execute
5. **Produce** the structured response summary defined in `RESPONSE.md`

## Expected Feedback File Format

The feedback file may contain numbered or bulleted items:

```markdown
1. Remove unused import on line 15
2. Add error handling to the API call
3. Consider using a generator for large datasets
4. Fix typo in variable name: `usr` → `user`
```

Freeform prose is also acceptable; extract actionable items from the text.

## Example

```bash
/receive-feedback reviews/pr-123-feedback.md
```

Reads the file, processes each item with technical verification, and outputs a structured response table.

## Files

- `VERIFICATION.md` - Tool-based verification workflow
- `EVALUATION.md` - Decision matrix and rules
- `RESPONSE.md` - Structured output format
- `references/skill-integration.md` - Using with code-review skills
