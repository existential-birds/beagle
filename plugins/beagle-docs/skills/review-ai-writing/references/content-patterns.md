# Content Patterns

Detection patterns for AI-generated writing in developer docs, commit messages, PRs, and code comments.

## 1. Promotional Language

### What to Look For

Inflated claims about code quality or tool capabilities. AI text oversells what code does, using marketing language instead of precise technical description.

### Detection Patterns

**Commit messages**:

Before:
```
feat: add robust and elegant caching layer for seamless data retrieval
```
After:
```
feat: add Redis cache for user profile queries
```

**Module docs**:

Before:
```markdown
This powerful and highly flexible authentication module provides a comprehensive,
enterprise-grade solution for all your security needs.
```
After:
```markdown
Authentication module supporting OAuth 2.0 and SAML. Wraps `authlib` with
project-specific defaults and middleware hooks.
```

**Inline comments**:

Before: `// This elegant algorithm efficiently handles all edge cases`

After: `// Handles duplicate keys by keeping the last value`

### Trigger Words

`robust`, `elegant`, `seamless`, `powerful`, `comprehensive`, `cutting-edge`, `best-in-class`, `enterprise-grade`, `highly flexible`, `state-of-the-art`, `effortlessly`

### fix_safety: Safe

Replace promotional adjectives with factual descriptions of what the code actually does.

---

## 2. Vague Authority

### What to Look For

Unattributed claims borrowing authority from unnamed sources. AI text inserts "research shows" or "experts agree" without citations.

### Detection Patterns

**Docs**:

Before:
```markdown
Research shows that structured error handling significantly improves reliability.
Experts agree that the Result pattern is the preferred approach.
```
After:
```markdown
Uses the Result pattern (`Ok`/`Err`) instead of exceptions.
See [ADR-0012](../decisions/0012-result-pattern.md) for the tradeoff discussion.
```

**PR descriptions**:

Before:
```
Studies have shown that smaller functions lead to better maintainability.
This refactor follows industry-standard practices.
```
After:
```
Split `process_order` (180 lines) into `validate_order`, `apply_discounts`,
and `submit_order`. Each function is independently testable.
```

**Code comments**:

Before: `// Best practices dictate that we should validate input here`

After: `// Validate before insert; see #422 for the injection that motivated this`

### Trigger Phrases

`research shows`, `studies have shown`, `experts agree`, `it is widely recognized`, `best practices dictate`, `industry-standard`, `as recommended by leading engineers`

### fix_safety: Safe

Replace with specific references (links, ADR numbers, issue numbers) or drop the claim entirely.

---

## 3. Formulaic Structure

### What to Look For

Rigid intro-body-conclusion scaffolding where it adds no value. AI text forces three-act structure onto commit messages and short docs.

### Detection Patterns

**Over-structured commit messages**:

Before:
```
feat: implement user notification system

Introduction:
This commit introduces a notification system for users.

Changes Made:
- Added NotificationService class
- Added email template

Conclusion:
Users will now receive email notifications when orders are processed.
```
After:
```
feat: add email notifications on order completion

- Add NotificationService with SendGrid transport
- Add order_completed email template
- Add notifications table migration
```

**Unnecessary preamble in docs**:

Before:
```markdown
## Configuration

Configuration plays a vital role in any application. In this section,
we will explore the various configuration options available.

### Database URL
```
After:
```markdown
## Configuration

### Database URL
```

**Restated conclusions**:

Before:
```markdown
## Conclusion

In summary, this library provides CSV parsing for your data pipeline.
As discussed above, it supports custom delimiters. We hope you find it useful.
```
After: Remove the section, or replace with a "See also" list linking to related docs.

### fix_safety: Safe

Removing empty intros, restated conclusions, and "in this section we will" preambles does not alter technical content.

---

## 4. Synthetic Openers

### What to Look For

Canned opening phrases that add no information and delay the reader. Common in generated docs, PR descriptions, and READMEs.

### Detection Patterns

**Docs**:

Before:
```markdown
In today's fast-paced world of API development, rate limiting has become
an essential component of any production-ready system.
```
After:
```markdown
Token bucket rate limiter for the public API. Defaults to 100 req/min
per API key. Configure via `RATE_LIMIT` in environment.
```

**PR descriptions**:

Before:
```
In the world of distributed systems, message queues play a crucial role
in decoupling services. This PR adds RabbitMQ support to our pipeline.
```
After:
```
Add RabbitMQ consumer for the ingestion pipeline. Replaces the polling
loop in `ingest_worker.py` (see #287 for latency benchmarks).
```

**Code comments**:

Before: `// As we all know, caching is important for performance`

After: `// Cache parsed configs; parsing takes ~200ms per file`

### Trigger Phrases

`In today's fast-paced`, `In the world of`, `In the ever-evolving landscape`, `As we all know`, `It's worth noting that`, `It goes without saying`, `When it comes to`, `In the realm of`

### fix_safety: Needs review

Most synthetic openers can be deleted outright, but some may be the only sentence introducing a topic. After removing the opener, verify the paragraph still has a clear lead sentence. If the opener was the entire introduction, write a direct replacement stating scope or purpose.

---

## Review Questions

1. Does this description say what the code does, or how great it is?
2. Is this claim attributed to a specific source, or does it lean on vague authority?
3. Would this doc lose any technical content if the intro and conclusion were deleted?
4. Does the opening sentence deliver information, or is it a generic warm-up?
5. Could a reader skip the first paragraph entirely and miss nothing?
