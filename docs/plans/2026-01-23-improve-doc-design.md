# improve-doc Command Design

Design for the `improve-doc` command and supporting Diátaxis skills.

## Overview

**Command:** `/beagle:improve-doc`

**Purpose:** Analyze an existing markdown document, categorize its content by Diátaxis type, identify specific issues, then interactively improve it section by section.

**Invocation:**
```
/beagle:improve-doc path/to/document.md
```

**Workflow:**
1. Parse and analyze the document
2. Show type breakdown + issues
3. For each section: propose improvements → user approves/skips → apply
4. Overwrite original file

**Skills loaded:**
- Always: `docs-style` (core principles)
- As needed: `tutorial-docs`, `howto-docs`, `reference-docs`, `explanation-docs`

## Diátaxis Framework

The command uses the [Diátaxis framework](https://diataxis.fr/) which defines four documentation types:

| Type | Orientation | User Need |
|------|-------------|-----------|
| **Tutorial** | Learning | "I want to learn" |
| **How-To** | Task | "I want to accomplish X" |
| **Reference** | Information | "I need to look up Y" |
| **Explanation** | Understanding | "I want to understand why" |

## Analysis Phase

### Step 1: Parse Document Structure

Break the document into sections based on headings. For each section, capture:
- Heading level and text
- Content (paragraphs, code blocks, lists, tables)
- Line range (for later editing)

### Step 2: Classify Each Section

Apply Diátaxis heuristics to determine the dominant type:

| Type | Indicators |
|------|------------|
| **Tutorial** | "Let's", "we will", step-by-step learning, builds toward a project, minimal explanation |
| **How-To** | "How to" title, task-focused steps, assumes prior knowledge, goal-oriented |
| **Reference** | Parameter tables, type signatures, API specs, factual descriptions, no narrative |
| **Explanation** | "Why", "because", history, trade-offs, alternatives, conceptual discussion |

### Step 3: Identify Issues

Check each section against its detected type's principles. Examples:

- Tutorial section with too much explanation → "Tutorial explains rather than guides"
- How-to missing prerequisites → "How-to lacks prerequisites section"
- Reference using prose instead of tables → "Reference should use tables for parameters"
- Explanation mixed into reference → "Reference contains 'why' content better suited to explanation"

### Step 4: Present Analysis

```markdown
## Document Analysis

**File:** `docs/authentication.md`

### Type Breakdown

| Section | Type | Issues |
|---------|------|--------|
| Introduction | Explanation | None |
| Getting Started | Tutorial | Explains too much, needs visible outcomes |
| API Reference | Reference | Uses prose instead of tables |
| Configuration | How-To | Missing prerequisites |

### Top Issues

1. [Getting Started] Tutorial section contains lengthy explanations — tutorials should minimize "why"
2. [API Reference] Parameters described in prose — use tables for scannability
3. [Configuration] No prerequisites listed — readers won't know what's needed upfront
```

## Interactive Refinement Phase

For each section with issues:

1. **Show the current section** (truncated if long)
2. **List the specific issues** for that section
3. **Ask user intent** — clarifying questions if the detected type seems ambiguous
4. **Propose improved version** — rewritten following the appropriate skill's principles
5. **User decides** — Accept, skip, or request modifications

### Example Interaction

```markdown
## Section 2 of 4: Getting Started

**Detected type:** Tutorial
**Issues:**
- Explains too much (tutorials should learn-by-doing)
- No visible outcomes after steps

**Current content (lines 15-42):**
> ## Getting Started
>
> Authentication is a critical part of any application. OAuth 2.0
> provides a secure way to handle user identity by using tokens
> instead of passwords. This section will walk you through...

**Clarifying question:**
Is this section meant to teach beginners (tutorial) or help experienced
users accomplish a specific task (how-to)?
```

User answers → command proposes rewrite:

```markdown
**Proposed improvement:**

> ## Getting Started
>
> Let's set up authentication for your app. By the end, you'll have
> a working login flow.
>
> ### 1. Create an OAuth app
>
> Go to Settings > Developer > New App. Enter "My App" as the name.
>
> You should see your new app in the list with a client ID.
>
> ### 2. Add the SDK
> ...

Accept this change? [yes / skip / modify]
```

### User Choices

- **yes:** Apply change, move to next section
- **skip:** Leave section unchanged, move on
- **modify:** Ask what to change, regenerate

## Output

After all sections are processed, the command overwrites the original file. Users can use git to review changes or revert if needed.

## New Skills Required

### `tutorial-docs`

Patterns for learning-oriented tutorials that teach through doing.

**Key principles from Diátaxis:**
- Learn by doing, not by reading explanations
- Deliver visible results at every step ("You should see...")
- Guide to concrete actions, not abstract concepts
- Minimize choices — one clear path
- Teacher takes responsibility for success
- Permit repetition to build confidence

**Template structure:**
- Introduction (what you'll build, not why it matters)
- Prerequisites (minimal — tutorials are for beginners)
- Steps with visible outcomes after each
- "What you've learned" summary
- Next steps

### `explanation-docs`

Patterns for understanding-oriented content that provides context and insight.

**Key principles from Diátaxis:**
- Discursive, not procedural
- Answers "why" and "how does this work"
- Makes connections to other concepts
- Provides historical context and design rationale
- Discusses alternatives and trade-offs
- Suitable for reading away from the keyboard

**Template structure:**
- Overview (what this explains)
- Background/context
- How it works (conceptually)
- Design decisions and trade-offs
- Alternatives considered
- Related concepts

## Files to Create

```
beagle/
├── commands/
│   └── improve-doc.md          # New command
└── skills/
    ├── tutorial-docs/
    │   └── SKILL.md            # New skill
    └── explanation-docs/
        └── SKILL.md            # New skill
```

## Existing Skills Used

- `docs-style/SKILL.md` — loaded always
- `reference-docs/SKILL.md` — loaded for reference sections
- `howto-docs/SKILL.md` — loaded for how-to sections

## Command Workflow Diagram

```
/beagle:improve-doc path/to/file.md
           │
           ▼
    ┌──────────────┐
    │ Parse into   │
    │ sections     │
    └──────┬───────┘
           │
           ▼
    ┌──────────────┐
    │ Classify     │
    │ each section │
    └──────┬───────┘
           │
           ▼
    ┌──────────────┐
    │ Identify     │
    │ issues       │
    └──────┬───────┘
           │
           ▼
    ┌──────────────┐
    │ Show         │
    │ analysis     │
    └──────┬───────┘
           │
           ▼
    ┌──────────────────────────┐
    │ For each section:        │◄──┐
    │  - Show current          │   │
    │  - Clarify intent        │   │
    │  - Propose improvement   │   │
    │  - Accept / Skip / Modify│───┘
    └──────────────┬───────────┘
                   │ (all sections done)
                   ▼
    ┌──────────────┐
    │ Overwrite    │
    │ original     │
    └──────────────┘
```
