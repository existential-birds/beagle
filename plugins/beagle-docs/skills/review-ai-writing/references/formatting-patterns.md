# Formatting Patterns

Detection criteria for AI-generated formatting habits in developer docs, commit messages, PR descriptions, and code comments.

## 1. Boldface Overuse

### What to Look For

AI tends to bold every key term, creating visual noise that dilutes emphasis. In developer documentation, bold should be reserved for UI element labels, key terms on first introduction, and warnings or critical notes.

### Detection Patterns

**Bolding common terms throughout a paragraph**:

```markdown
<!-- BAD - Every term is bold, nothing stands out -->
The **server** reads the **configuration file** on **startup** and
initializes the **database connection pool**. If the **connection**
fails, the **retry logic** kicks in with **exponential backoff**.

<!-- GOOD - Bold only on first introduction of a key concept -->
The server reads the configuration file on startup and initializes
the database connection pool. If the connection fails, the retry
logic kicks in with **exponential backoff** (see Retry Strategies).
```

**Bolding obvious terms in lists**:

```markdown
<!-- BAD - Bold on every list label adds nothing -->
- **Port**: 8080
- **Host**: localhost
- **Protocol**: HTTP

<!-- GOOD - Plain text when the structure already provides emphasis -->
- Port: 8080
- Host: localhost
- Protocol: HTTP
```

**Bolding in commit messages or PR descriptions**:

```markdown
<!-- BAD -->
Fix **race condition** in **connection pool** when **timeout** expires

<!-- GOOD -->
Fix race condition in connection pool when timeout expires
```

### fix_safety

Safe. Removing unnecessary bold formatting does not change meaning.

---

## 2. Emoji Decoration

### What to Look For

Gratuitous emoji in technical writing where plain text is clearer. Common in AI-generated changelogs, PR descriptions, commit messages, and documentation headings. Emoji should only appear when they serve a functional purpose (e.g., status indicators in a table).

### Detection Patterns

**Emoji in changelog or release notes**:

```markdown
<!-- BAD - Emoji adds no information -->
## What's New

- :rocket: Added streaming support for large responses
- :bug: Fixed null pointer in auth middleware
- :sparkles: New CLI flag for verbose output
- :wastebasket: Removed deprecated v1 endpoints

<!-- GOOD - Let the content speak -->
## What's New

- Added streaming support for large responses
- Fixed null pointer in auth middleware
- New CLI flag for verbose output
- Removed deprecated v1 endpoints
```

**Emoji in headings or section titles**:

```markdown
<!-- BAD -->
## :wrench: Configuration
## :book: API Reference
## :warning: Known Issues

<!-- GOOD -->
## Configuration
## API Reference
## Known Issues
```

**Emoji as bullet markers or checkmarks**:

```markdown
<!-- BAD - Emoji replacing standard list markers -->
:white_check_mark: Unit tests passing
:white_check_mark: Integration tests passing
:white_check_mark: Linting clean

<!-- GOOD - Use standard markdown -->
- [x] Unit tests passing
- [x] Integration tests passing
- [x] Linting clean
```

### fix_safety

Safe. Removing decorative emoji does not change technical meaning.

---

## 3. Heading Restatement

### What to Look For

The first sentence after a heading restates the heading in slightly different words. This is filler that delays the reader from reaching useful content. The heading already names the topic; the body should immediately provide substance.

### Detection Patterns

**Restating the heading as a definition**:

```markdown
<!-- BAD - First sentence is the heading in sentence form -->
## Error Handling

Error handling is an important aspect of building robust applications.
When an error occurs...

<!-- GOOD - Jump straight into substance -->
## Error Handling

All functions in this module return `(result, error)` tuples. Check
the error value before using the result.
```

**Restating with "This section describes..."**:

```markdown
<!-- BAD - Meta-commentary about the section itself -->
## Authentication

This section describes how authentication works in the system.
The authentication flow begins when...

<!-- GOOD - Start with what the reader needs -->
## Authentication

Clients authenticate by sending a Bearer token in the `Authorization`
header. Tokens are issued by the `/auth/token` endpoint and expire
after 24 hours.
```

**Restating in code comments**:

```python
# BAD - Comment restates the function name
def calculate_retry_delay(attempt: int) -> float:
    """Calculate the retry delay.

    Calculates the delay before retrying a failed request.
    """
    return min(2 ** attempt, MAX_DELAY)

# GOOD - Comment adds information the name doesn't convey
def calculate_retry_delay(attempt: int) -> float:
    """Exponential backoff capped at MAX_DELAY seconds.

    Uses jitter to prevent thundering herd on service recovery.
    """
    return min(2 ** attempt, MAX_DELAY)
```

### fix_safety

Needs review. The restated sentence sometimes contains useful qualifiers or scope limitations mixed in with the filler. Verify that no meaningful context is lost before removing.

---

## Review Questions

1. Does every bold term in this paragraph genuinely need emphasis, or would one or two suffice?
2. Would this changelog entry lose any meaning without the emoji?
3. Does the first sentence after this heading tell the reader something the heading did not?
