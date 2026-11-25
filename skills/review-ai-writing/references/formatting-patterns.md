# Formatting Patterns

Detection criteria for AI-generated formatting habits in developer docs, commit messages, PR descriptions, and code comments.

## 1. Boldface Overuse (`boldface_overuse`)

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

### fix_safety: Safe

Removing unnecessary bold formatting does not change meaning.

---

## 2. Emoji Decoration (`emoji_decoration`)

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

### fix_safety: Safe

Removing decorative emoji does not change technical meaning.

---

## 3. Heading Restatement (`heading_restatement`)

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

### fix_safety: Safe

Delete the restating opener sentence so the section starts directly with substantive content.

---

## 4. Em Dash Overuse (`em_dash_overuse`)

### What to Look For

Multiple em dashes (`—`) crammed into single sentences or stacked across consecutive paragraphs as a stylistic tic instead of periods, commas, parentheses, or colons.

### Detection Patterns

```markdown
<!-- BAD -->
The parser — which handles all input formats — validates each field — including nested objects — before returning.

<!-- GOOD -->
The parser validates each field (including nested objects) before returning. It handles all input formats.
```

### fix_safety: Safe

Replacing excessive em dashes with commas, parentheses, colons, or split sentences preserves meaning.

---

## 5. Thematic Breaks (`thematic_break`)

### What to Look For

Gratuitous horizontal rules (`---`, `***`) placed right before headings or between normal subsections where heading hierarchy already separates sections. (Do not flag YAML frontmatter `---` delimiters.)

### Detection Patterns

```markdown
<!-- BAD -->
---
## Configuration

<!-- GOOD -->
## Configuration
```

### fix_safety: Safe

Removing redundant horizontal rules before headings does not alter document structure or meaning.

---

## 6. Title-Case Headings (`title_case_heading`)

### What to Look For

AI-defaulted Title Case on every word (including prepositions/conjunctions like `"And"`, `"For"`, `"With"`, `"In"`) in headings when the project uses sentence case or plain technical nouns. Skip established proper nouns, product titles, and repos whose existing headings consistently use Title Case.

### Detection Patterns

```markdown
<!-- BAD -->
## Configuring Authentication And Rate Limiting For Your API

<!-- GOOD -->
## Configuring authentication and rate limiting
```

### fix_safety: Safe

Normalizing non-proper-noun words in headings to sentence case preserves meaning.

---

## 7. Curly Quotes (`curly_quotes`)

### What to Look For

Typographic smart/curly quotes (`“`, `”`, `‘`, `’`) in markdown prose, shell examples, or code comments where straight ASCII quotes (`"`, `'`) are standard and safe to copy-paste.

### Detection Patterns

```markdown
<!-- BAD -->
Run `git commit -m “fix bug”` — it’s fast.

<!-- GOOD -->
Run `git commit -m "fix bug"` — it's fast.
```

### fix_safety: Safe

Normalizing curly quotes and apostrophes to straight ASCII quotes avoids copy-paste syntax failures.

---

## 8. Inline-Header Lists (`inline_header_list`)

### What to Look For

Bullet lists where every item starts with a bolded mini-heading followed by a colon (`- **Reliability:** The system ensures...`) used in place of either a concise paragraph or a real list.

### Detection Patterns

```markdown
<!-- BAD -->
- **Fast Execution:** The engine processes requests quickly.
- **High Reliability:** The system recovers from transient errors.
- **Easy Integration:** Developers can install the SDK in seconds.

<!-- GOOD -->
Processes requests with a connection pool and automatic retry on 503 responses.
```

### fix_safety: Needs review

Converting bold inline-header lists to prose or cleaner bullets requires checking whether the labels serve as scannable reference keys (e.g., flag descriptions).

---

## 9. Unnecessary Tables (`unnecessary_table`)

### What to Look For

Small 2–3 row Markdown tables introduced by AI for simple prose facts, binary comparisons, or a handful of items that read more cleanly as a sentence or short list.

### Detection Patterns

```markdown
<!-- BAD -->
| Property | Value |
|----------|-------|
| Default Port | 8080 |
| Timeout | 30s |

<!-- GOOD -->
Defaults to port `8080` with a `30s` request timeout.
```

### fix_safety: Needs review

Converting tables to prose must preserve every cell value and label accurately.

---

## Review Questions

1. Does every bold term in this paragraph genuinely need emphasis, or would one or two suffice?
2. Would this changelog entry lose any meaning without the emoji?
3. Does the first sentence after this heading tell the reader something the heading did not?
4. Are em dashes, horizontal rules, curly quotes, or tiny tables adding visual clutter where plain punctuation or prose is clearer?
