# Vocabulary Patterns

Detection patterns for AI-generated writing in developer docs, commit messages, PRs, and code comments.

## 1. AI Vocabulary

### What to Look For

Words that appear disproportionately in AI-generated text, organized by signal strength.

### High-Signal Words (Always Flag)

These rarely appear in natural developer writing. Flag every occurrence.

`delve`, `utilize`, `leverage` (meaning "use"), `whilst`, `furthermore`, `moreover`, `harnessing`, `revolutionize`, `paradigm`, `synergy`, `facilitate`, `empower`, `elevate`, `unleash`, `robust` (non-technical), `seamless`, `cutting-edge`, `endeavor`, `pivotal`, `embark`

```markdown
<!-- BAD -->
Let's delve into how this module leverages the cache to facilitate
seamless data retrieval, empowering developers to unleash the full
potential of the framework.

<!-- GOOD -->
This module uses the cache for faster data retrieval.
```

**fix_safety**: Safe. Direct word substitution.

### Low-Signal Words (Flag in Clusters of 3+)

Normal in isolation, but AI signals when clustered. Flag when 3+ appear in one paragraph.

`ensure`, `enhance`, `comprehensive`, `streamline`, `optimize`, `implement`, `innovative`, `significant`, `fundamental`, `essential`

```markdown
<!-- BAD - 4 low-signal words clustered -->
This comprehensive update ensures that the streamlined pipeline
handles all essential edge cases.

<!-- GOOD -->
This update fixes edge case handling in the pipeline.
```

**fix_safety**: Safe. Rewrite with plain language.

---

## 2. Copula Avoidance

### What to Look For

AI avoids simple copula verbs ("is", "are", "was") and substitutes complex verb phrases. The result is stiff and indirect.

### Detection Patterns

Watch for these phrases followed by articles ("a", "an", "the"):

- "stands as" / "serves as" / "acts as" / "functions as" / "remains as" / "exists as"

```markdown
<!-- BAD -->
This module stands as the primary entry point for authentication.
The `Config` struct serves as the central configuration object.

<!-- GOOD -->
This module is the primary entry point for authentication.
The `Config` struct is the central configuration object.
```

```python
# BAD
# This class serves as a wrapper around the database connection
class DB:
    ...

# GOOD
# Wraps the database connection
class DB:
    ...
```

Note: "acts as" is valid when describing adapter/proxy design patterns.

**fix_safety**: Safe. Replace with "is" or rewrite as a direct statement.

---

## 3. Rhetorical Devices

### What to Look For

AI overuses rhetorical questions and dramatic framing in documentation. Developers write direct statements; AI writes engagement hooks.

### Detection Patterns

**Rhetorical questions as section openers**:
```markdown
<!-- BAD -->
Ever wondered how to secure your API endpoints? What if you could
add authentication in just a few lines of code?

<!-- GOOD -->
Add authentication to API endpoints using middleware.
```

**"Imagine" framing**:
```markdown
<!-- BAD -->
Imagine a world where your deployments never fail.

<!-- GOOD -->
The CI pipeline catches failures before deployment.
```

**Dramatic introductions**:
```markdown
<!-- BAD -->
In today's fast-paced development landscape, managing state has
become one of the most challenging aspects of building modern
applications. This library was born from the need to...

<!-- GOOD -->
A state management library for React applications.
```

**In PR descriptions**:
```markdown
<!-- BAD -->
Have you ever struggled with flaky tests? This PR tackles that
age-old problem by introducing deterministic test ordering.

<!-- GOOD -->
Fix flaky tests by making test ordering deterministic.
```

**fix_safety**: Safe. Replace with direct statements.

---

## 4. Synonym Cycling

### What to Look For

AI cycles through synonyms for the same concept to avoid repetition. In technical writing, consistency matters more than variety. Call a "function" a "function" every time.

### Detection Patterns

**Cycling technical terms**:
```markdown
<!-- BAD - same thing called 4 different names -->
The `processOrder` function validates the input. The method then
checks inventory. This procedure calculates the total. Finally,
the routine saves the order to the database.

<!-- GOOD - consistent terminology -->
The `processOrder` function validates the input, checks inventory,
calculates the total, and saves the order to the database.
```

**Cycling component names**:
```markdown
<!-- BAD -->
The `UserCard` component renders the avatar. This widget also
shows the username. The element handles click events.

<!-- GOOD -->
The `UserCard` component renders the avatar, shows the username,
and handles click events.
```

**In commit messages**:
```text
# BAD
Refactor auth module, restructure login flow, reorganize session
handling, and rearchitect token management

# GOOD
Refactor auth module: simplify login, session, and token handling
```

Common cycling sets to watch for:
- function / method / procedure / routine
- component / widget / element
- refactor / restructure / reorganize / rearchitect

**fix_safety**: Needs review. Determine which term is most accurate, then use it consistently.

---

## 5. Commit Message Inflation

### What to Look For

AI turns simple changes into grand narratives. Good commits are terse and specific.

### Detection Patterns

**Grandiose verbs for small changes**:
```text
# BAD                                    # GOOD
Revolutionize the authentication flow    Fix auth token refresh
Elevate the user experience              Improve error messages
Empower the CI pipeline                  Add unit tests for auth
```

**Marketing language in commit bodies**:
```text
# BAD
This commit introduces a paradigm shift in how we handle database
connections, leveraging connection pooling to deliver a seamless
and robust experience for all downstream consumers.

# GOOD
Switch to connection pooling. Fixes timeout errors under load.
See #234.
```

**Overexplaining obvious changes**:
```text
# BAD
feat: Implement the crucial and fundamental addition of a
comprehensive user validation layer that ensures data integrity

# GOOD
feat: add input validation to user signup
```

### Quick Reference

| Inflated | Plain |
|----------|-------|
| "Revolutionize X" | "Fix X" / "Refactor X" |
| "Comprehensive overhaul" | "Refactor" / "Rewrite" |
| "Elevate the experience" | "Improve" |
| "Introduce a paradigm shift" | "Change" / "Switch to" |
| "Ensure robust handling" | "Fix" / "Handle" |
| "Empower users with" | "Add" |
| "Streamline the workflow" | "Simplify" |
| "Leverage cutting-edge" | "Use" |

**fix_safety**: Safe. Rewrite using Conventional Commits with plain verbs (add, fix, update, remove, refactor).

---

## Review Questions

1. Does the text contain any high-signal AI vocabulary words?
2. Are there 3+ low-signal words clustered in a single paragraph?
3. Does the writing avoid simple "is/are" in favor of complex verb phrases?
4. Are there rhetorical questions or "imagine" framing in technical docs?
5. Is the same concept referred to by multiple different terms within a section?
6. Do commit messages use dramatic verbs for routine changes?
