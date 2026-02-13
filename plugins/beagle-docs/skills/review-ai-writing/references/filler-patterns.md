# Filler Patterns

Patterns for detecting AI-generated filler in developer documentation, commit messages, PRs, and code comments.

## Filler Phrases

Dev-specific filler phrases that add no information. These weaken technical writing by burying the actual point.

> Cross-reference: See `beagle-docs:docs-style` for the core phrase simplification table.

The following are dev-specific additions commonly found in AI-generated output:

| Phrase | Fix |
|--------|-----|
| "It's worth noting that" | Delete, or state the fact directly |
| "It should be noted that" | Delete |
| "As mentioned earlier/above" | Link directly to the section, or delete |
| "This allows us to" | State what happens |
| "In this section, we will" | Delete; just start the section |
| "Let's take a look at" | Delete |
| "As we can see" | Delete |
| "Going forward" | Delete, or specify a timeframe |
| "At the end of the day" | Delete |

**What to look for**: Sentences that begin with these phrases and contribute nothing after removal. The surrounding sentence remains grammatically correct and retains its meaning.

### Before / After

```markdown
<!-- Before -->
It's worth noting that the connection pool defaults to 10.

<!-- After -->
The connection pool defaults to 10.
```

```python
# Before
# This allows us to gracefully handle timeout errors
# After
# Handles timeout errors with exponential backoff
```

```markdown
<!-- Before (commit message) -->
Going forward, all API responses will include pagination metadata.

<!-- After -->
All API responses now include pagination metadata.
```

**fix_safety**: Safe -- these phrases can be removed mechanically without changing meaning.

---

## Excessive Hedging

Overuse of qualifiers that weaken technical statements. In technical documentation, either something is true or it is not. Stacking hedges signals that the author (or model) is uncertain about claims that should be definitive.

**What to look for**: Multiple hedging words combined in a single clause, or hedges applied to verifiable facts.

Common patterns:
- "might potentially" -- pick one or neither
- "could possibly" -- pick one or neither
- "it seems like it may" -- state what it does, or document the ambiguity explicitly
- "arguably" -- either make the argument or remove the claim
- "one could say" -- say it or remove it
- "it is generally considered" -- by whom? cite or state directly
- "this should theoretically" -- test it and state the result

### Before / After

```markdown
<!-- Before -->
This approach might potentially reduce latency in some cases.

<!-- After -->
This approach reduces p95 latency by ~40ms in benchmarks (see #214).
```

```markdown
<!-- Before (PR description) -->
The refactor could possibly improve readability and arguably makes
the module easier to test.

<!-- After -->
The refactor separates I/O from parsing, making the module unit-testable
without mocks.
```

```python
# Before
# This should theoretically handle all edge cases
# After
# Handles empty input, None, and negative values (see test_edge_cases)
```

**fix_safety**: Needs review -- removing hedges changes the strength of the claim. Verify the resulting statement is accurate before committing.

---

## Generic Conclusions

Empty summarizing paragraphs that restate what the reader just read. These appear at the end of docs, PRs, and commit descriptions. They add no information and signal AI generation because LLMs are trained on content with formulaic conclusions.

**What to look for**: Final paragraphs that begin with summarizing phrases and contain no new information, action items, or links.

Common patterns:
- "In conclusion, we have seen that..."
- "To summarize, this document covered..."
- "By following these steps, you will be able to..."
- "Overall, this implementation provides..."
- "In summary, the changes above..."
- "With these changes in place, we now have..."

### Before / After

```markdown
<!-- Before (end of PR description) -->
In summary, the changes above refactor the authentication module to use
JWT tokens instead of session cookies, improving security and reducing
server-side state. By following this approach, we ensure that the system
is more maintainable and scalable going forward.

<!-- After -->
## Migration

Existing sessions expire after deploy. Users will need to re-authenticate.
See the migration runbook: docs/runbooks/auth-jwt-migration.md
```

```markdown
<!-- Before (end of a doc page) -->
By following these steps, you will be able to deploy your application
to production successfully. We have covered all the necessary
configuration and setup required for a smooth deployment.

<!-- After -->
## Next steps

- [Set up monitoring](/guides/monitoring) for your production deployment
- [Configure alerting](/guides/alerts) for error rate thresholds
```

```python
# Before (end of module docstring)
# In conclusion, this module provides a comprehensive set of utilities
# for handling date parsing across multiple formats.

# After
# Supported formats: ISO 8601, RFC 2822, Unix timestamps.
# See parse_date() for the full format list.
```

**fix_safety**: Safe -- generic conclusions can be deleted outright. If the section needs a closing, replace it with actionable next steps or concrete references.
