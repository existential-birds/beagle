# Fix Strategies by Category

Strategies for each finding type, organized by category. Each entry includes the fix approach, risk level, and before/after examples.

## Table of Contents

- [Content Patterns](#content-patterns)
- [Vocabulary Patterns](#vocabulary-patterns)
- [Formatting Patterns](#formatting-patterns)
- [Communication Patterns](#communication-patterns)
- [Filler Patterns](#filler-patterns)
- [Code Docs Patterns](#code-docs-patterns)

---

## Content Patterns

| Type | Strategy | Risk |
|------|----------|------|
| Promotional language | Replace superlatives with specifics | Needs review |
| Vague authority | Delete the claim or add a citation | Safe |
| Formulaic structure | Remove the intro/conclusion wrapper | Needs review |
| Synthetic openers | Delete the opener, start with the point | Safe |
| Negative parallelism | Delete the filler construction, keep the point | Safe |
| Rule of three | Simplify to what matters, drop padding items | Needs review |
| Challenges-and-prospects | Delete the formulaic "Despite..." wrapper | Safe |

### Regression to the Mean

LLMs produce the most statistically likely output. Specific, unusual facts get replaced with generic, positive descriptions. When humanizing, restore specificity — replace vague praise with concrete details.

**Before:**
```markdown
In today's rapidly evolving software landscape, authentication is a crucial
component that plays a pivotal role in securing modern applications.
```

**After:**
```markdown
This guide covers authentication setup for the API.
```

### Negative Parallelism

LLMs produce "Not just X, but also Y" and "Not X, but Y" constructions that add words without adding meaning. Delete the construction, keep the point.

**Before:**
```markdown
This is not just a logging library, but also a comprehensive observability
framework that empowers developers to gain valuable insights.
```

**After:**
```markdown
This is a logging library with structured output and trace correlation.
```

### Rule of Three

LLMs overuse three-item lists ("adjective, adjective, adjective") to make superficial analyses appear comprehensive. Keep only items that carry specific meaning.

**Before:**
```markdown
The event features keynote sessions, panel discussions, and networking opportunities.
```

**After (keep only what's specific):**
```markdown
The event includes keynote sessions and breakout workshops.
```

### Challenges-and-Prospects Formula

Rigid formula: "Despite its [positive words], [subject] faces challenges..." ending with vague positive assessment. Delete the wrapper, state the actual limitation with specifics.

**Before:**
```markdown
Despite its robust architecture, the system faces challenges typical of
distributed environments. Despite these challenges, with its strategic
design and ongoing improvements, the platform continues to thrive.
```

**After:**
```markdown
Known limitations: network partitions can cause stale reads for up to 30s.
See the consistency model docs for details.
```

---

## Vocabulary Patterns

| Type | Strategy | Risk |
|------|----------|------|
| High-signal AI words | Direct word swap | Safe |
| Low-signal clusters | Reduce density, keep 1-2 | Needs review |
| Copula avoidance | Use "is/are" naturally | Safe |
| Rhetorical devices | Delete the question, state the fact | Safe |
| Synonym cycling | Pick one term, use it consistently | Needs review |
| Commit inflation | Rewrite to match actual change scope | Needs review |

### Copula Avoidance

LLMs substitute simple "is/are" with elaborate alternatives like "serves as", "stands as", "boasts", "features", "offers". Use the simple form.

**Before:**
```text
feat: Leverage robust caching paradigm to facilitate seamless data retrieval
```

**After:**
```text
feat: add response caching for faster reads
```

See `references/vocabulary-swaps.md` for the complete word swap table.

---

## Formatting Patterns

| Type | Strategy | Risk |
|------|----------|------|
| Boldface overuse | Remove bold from non-key terms | Safe |
| Emoji decoration | Remove emoji from technical content | Safe |
| Heading restatement | Delete the restating sentence | Safe |
| Title case headings | Convert to sentence case | Safe |
| Em dash overuse | Replace with commas, parentheses, or colons | Safe |
| Thematic breaks | Remove horizontal rules before headings | Safe |
| Curly quotes | Normalize to straight quotes/apostrophes | Safe |
| Inline-header lists | Restructure or convert to prose | Needs review |
| Unnecessary tables | Convert small tables to prose | Needs review |

**Boldface overuse — Before:**
```markdown
## Error Handling

**Error handling** is a **critical** aspect of building **reliable** applications.
The `handleError` function **catches** and **processes** all **runtime errors**.
```

**After:**
```markdown
## Error Handling

The `handleError` function catches runtime errors and logs them with context.
```

**Em dash overuse — Before:**
```markdown
The parser — which handles all input formats — validates each field — including nested objects — before returning.
```

**After:**
```markdown
The parser validates each field (including nested objects) before returning. It handles all input formats.
```

**Title case — Before:**
```markdown
## Strategic Negotiations And Global Partnerships
```

**After:**
```markdown
## Strategic negotiations and global partnerships
```

---

## Communication Patterns

| Type | Strategy | Risk |
|------|----------|------|
| Chat leaks | Delete entirely | Safe |
| Cutoff disclaimers | Delete entirely | Safe |
| Sycophantic tone | Delete or neutralize | Safe |
| Apologetic errors | Rewrite as direct error message | Needs review |

**Before:**
```python
# Great implementation! This elegantly handles the edge case.
# As of my last update, this API endpoint supports JSON.
```

**After:**
```python
# Handles the re-entrant edge case from issue #42.
# This endpoint accepts JSON.
```

---

## Filler Patterns

| Type | Strategy | Risk |
|------|----------|------|
| Filler phrases | Delete the phrase | Safe |
| Excessive hedging | Remove qualifiers, state directly | Safe |
| Generic conclusions | Delete the conclusion paragraph | Safe |

**Before:**
```markdown
It's worth noting that the configuration file might potentially need to be
updated. Going forward, this could possibly affect performance.
```

**After:**
```markdown
Update the configuration file. This affects performance.
```

---

## Code Docs Patterns

| Type | Strategy | Risk |
|------|----------|------|
| Tautological docstrings | Delete or add real information | Needs review |
| Narrating obvious code | Delete the comment | Safe |
| "This noun verbs" | Rewrite in active/direct voice | Safe |
| Exhaustive enumeration | Keep only non-obvious params | Needs review |

**Before:**
```python
def get_user(user_id: int) -> User:
    """Get a user.

    This method retrieves a user from the database by their ID.

    Args:
        user_id: The ID of the user to get.

    Returns:
        User: The user object.

    Raises:
        ValueError: If the user ID is invalid.
    """
    return db.query(User).get(user_id)
```

**After:**
```python
def get_user(user_id: int) -> User:
    """Raises UserNotFound if ID doesn't exist in the database."""
    return db.query(User).get(user_id)
```
