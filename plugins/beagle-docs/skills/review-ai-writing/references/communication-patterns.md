# Communication Patterns

Detection criteria for conversational AI artifacts that leak into developer-facing text: documentation, commit messages, PR descriptions, and code comments.

## 1. Chat Leaks

### What to Look For

Conversational phrases from AI chat sessions copy-pasted into committed text. These read as one side of a dialogue rather than authored documentation.

### Detection Patterns

```markdown
# BAD - Chat openers leaked into docs/PRs/comments
Certainly! Here's how to configure the database connection.
Great question! The middleware stack processes requests in order.
I'd be happy to help explain the authentication flow.

# GOOD
Configure the database connection with the following environment variables.
The middleware stack processes requests in order.
```

```python
# BAD - Chat phrasing in code comments or commit messages
# Here's the implementation for the retry logic
# Let me explain what this does
# As requested, this handles the edge case
# Sure thing! This validates the token format

# GOOD
# Retry with exponential backoff, max 3 attempts
# Handles empty input by returning early
```

### fix_safety: Safe

Removing chat preambles does not change technical meaning.

---

## 2. Cutoff Disclaimers

### What to Look For

Training cutoff disclaimers or knowledge-limitation hedges in docs or comments. These expose AI-generated origin and erode reader confidence.

### Detection Patterns

```markdown
# BAD
As of my last update, the API supports cursor-based pagination.
Based on current knowledge, PostgreSQL 16 introduced merge joins.
I cannot guarantee this behavior will remain consistent.

# GOOD
The API supports cursor-based pagination (v2.3+).
PostgreSQL 16 introduced merge joins (see release notes).
This behavior may change; pin your dependency version.
```

### fix_safety: Safe

Replace disclaimers with versioned references or remove entirely.

---

## 3. Sycophantic Tone

### What to Look For

Excessive praise or enthusiasm in code review comments, PR descriptions, and documentation that reads as flattery rather than technical assessment.

### Detection Patterns

```markdown
# BAD
Excellent approach! The factory pattern here is wonderful.
Great implementation! This is a really elegant solution.
This is a brilliant way to handle the race condition!

# GOOD
The factory pattern decouples instantiation from the handler logic.
The mutex prevents the race condition identified in #247.
Consider a read-write lock since reads outnumber writes 10:1.
```

```python
# BAD
# This is a really nice pattern for dependency injection

# GOOD
# Dependency injection via constructor allows test doubles
```

### fix_safety: Safe

Replace praise with neutral technical descriptions. No semantic meaning is lost.

---

## 4. Apologetic Errors

### What to Look For

Over-apologizing in error messages, log output, or documentation. Error handling should be informative and actionable, not socially polite.

### Detection Patterns

```python
# BAD
raise ValueError("I apologize for any inconvenience, but the input is invalid.")
logger.error("Sorry for the confusion, but the config could not be loaded.")
print("Unfortunately, we regret to inform you that the connection failed.")

# GOOD
raise ValueError(f"Invalid input: expected ISO 8601 date, got {value!r}")
logger.error("Failed to load config from %s: %s", config_path, err)
print(f"Connection failed: {host}:{port} (timeout after {timeout}s)")
```

```markdown
# BAD
We're sorry, but this feature is not available in the free tier.

# GOOD
This feature requires a paid plan. See pricing for details.
```

### fix_safety: Needs review

Error message rewording must preserve all diagnostic information (codes, paths, values). Verify the replacement includes the same actionable details.

---

## Review Questions

1. Does the text read like one side of a conversation or like authored documentation?
2. Are there hedges or disclaimers that reference AI knowledge limitations?
3. Does review feedback contain praise without specific technical substance?
4. Do error messages apologize instead of providing actionable remediation steps?
5. Would the text make sense if the reader had no context of an AI interaction?
