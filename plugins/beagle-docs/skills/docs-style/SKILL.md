---
name: docs-style
description: Core technical documentation writing principles for voice, tone, structure, and LLM-friendly patterns. Use when writing or reviewing any documentation.
user-invocable: false
---

# Documentation Style Guide

Apply these principles when writing or reviewing documentation to ensure clarity, consistency, and accessibility for both human readers and LLMs.

## Choose the Right Documentation Type First

Style serves a purpose, and the purpose depends on which of the four Diataxis types you are writing. Before applying the conventions below, decide whether the document is a **Tutorial** (learning), **How-To guide** (a task), **Reference** (looking up), or **Explanation** (understanding) — these are not interchangeable, and mixing them in one document weakens all of them.

To choose, ask the two compass questions: *action or cognition? acquisition or application?*

| The reader's stance | Type |
|---|---|
| "I'm learning — guide my hands" | **Tutorial** |
| "I have a goal — help me reach it" | **How-To** |
| "I'm working — let me look something up" | **Reference** |
| "I'm reflecting — help me understand why" | **Explanation** |

For the full decision procedure, the 2×2 map, the two distinctions that resolve most ambiguity (Tutorial vs. How-To, Reference vs. Explanation), and the quality model, see [references/diataxis-compass.md](references/diataxis-compass.md). The type-specific skills (`tutorial-docs`, `howto-docs`, `reference-docs`, `explanation-docs`) build on the principles in this guide once the type is chosen.

## Voice and Tone

### Use Second Person

Address the reader directly as "you" rather than "the user" or "developers."

```markdown
<!-- Good -->
You can configure the API by setting environment variables.

<!-- Avoid -->
The user can configure the API by setting environment variables.
Developers should configure the API by setting environment variables.
```

### Prefer Active Voice

Write sentences where the subject performs the action. Active voice is clearer and more direct.

```markdown
<!-- Good -->
Create a configuration file in the root directory.
The function returns an array of user objects.

<!-- Avoid -->
A configuration file should be created in the root directory.
An array of user objects is returned by the function.
```

### Be Concise

Cut unnecessary words. Every word should earn its place.

```markdown
<!-- Good -->
Run the install command.

<!-- Avoid -->
In order to proceed, you will need to run the install command.
```

```markdown
<!-- Good -->
This endpoint returns user data.

<!-- Avoid -->
This endpoint is used for the purpose of returning user data.
```

Common phrases to simplify:

| Instead of | Use |
|------------|-----|
| in order to | to |
| for the purpose of | to, for |
| in the event that | if |
| at this point in time | now |
| due to the fact that | because |
| it is necessary to | you must |
| is able to | can |
| make use of | use |

## Document Structure

### Write Clear, Descriptive Headings

Headings should tell readers exactly what the section contains. Avoid clever or vague titles.

```markdown
<!-- Good -->
## Install the CLI
## Configure Authentication
## Handle Rate Limits

<!-- Avoid -->
## Getting Started (vague)
## The Fun Part (clever)
## Misc (uninformative)
```

### Create Self-Contained Pages

Assume readers may land on any page directly from search. Each page should:

- Explain what the feature/concept is
- State prerequisites clearly
- Provide complete context for the topic

```markdown
<!-- Good: Self-contained -->
# Webhooks

Webhooks let you receive real-time notifications when events occur in your account.

## Prerequisites

- An active API key with webhook permissions
- A publicly accessible HTTPS endpoint

## Create a Webhook

...
```

### Use Semantic Markup

Choose the right format for the content type:

- **Headings**: Follow proper hierarchy (h1 > h2 > h3, never skip levels)
- **Lists**: Use for multiple related items
- **Tables**: Use for structured data with consistent attributes
- **Code blocks**: Use for any code, commands, or file paths

```markdown
<!-- Good: Table for structured data -->
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| api_key | string | Yes | Your API key |
| timeout | integer | No | Request timeout in seconds |

<!-- Good: List for steps or options -->
To authenticate, you can:
- Use an API key in the header
- Use OAuth 2.0
- Use a service account
```

### Make Content Skimmable

Break dense paragraphs into digestible chunks:

- Keep paragraphs to 3-4 sentences maximum
- Use bullet points for lists of items
- Add subheadings to long sections
- Put key information first (inverted pyramid)

```markdown
<!-- Good: Skimmable -->
## Error Handling

The API returns standard HTTP status codes.

### Common Errors

- **400 Bad Request**: Invalid parameters. Check the request body.
- **401 Unauthorized**: Invalid or missing API key.
- **429 Too Many Requests**: Rate limit exceeded. Wait and retry.

### Retry Strategy

For 429 errors, use exponential backoff starting at 1 second.
```

## Consistency

### Use One Term Per Concept

Pick a term and use it consistently. Switching terms confuses readers.

```markdown
<!-- Good: Consistent terminology -->
Generate an API key in the dashboard. Use your API key in the Authorization header.

<!-- Avoid: Inconsistent terminology -->
Generate an API key in the dashboard. Use your API token in the Authorization header.
```

Document your terminology choices:

| Concept | Use | Don't use |
|---------|-----|-----------|
| Authentication credential | API key | API token, secret key, access key |
| Configuration file | config file | settings file, preferences file |
| Command line | CLI | terminal, command prompt, shell |

### Apply Consistent Formatting

Use the same formatting for similar content types:

- **UI elements**: Bold (Click **Save**)
- **Code/commands**: Backticks (`npm install`)
- **File paths**: Backticks (`/etc/config.yaml`)
- **Key terms on first use**: Bold or italics
- **Placeholders**: SCREAMING_CASE or angle brackets (`YOUR_API_KEY` or `<api-key>`)

## LLM-Friendly Patterns

### State Prerequisites Explicitly

List what users need before starting. This helps both humans and LLMs understand context.

```markdown
## Prerequisites

Before you begin, ensure you have:

- Node.js 18 or later installed
- An active account with admin permissions
- Your API key (find it in **Settings > API**)
```

### Define Acronyms on First Use

Spell out acronyms the first time they appear on a page.

```markdown
<!-- Good -->
The CLI (Command Line Interface) provides tools for managing your resources.
Subsequent uses can just say "CLI."

<!-- Avoid -->
The CLI provides tools for managing your resources.
```

### Provide Complete, Runnable Code Examples

Code examples should work when copied. Include:

- All necessary imports
- Realistic placeholder values
- Expected output (when helpful)

```markdown
<!-- Good: Complete example -->
```python
import requests

API_KEY = "your-api-key"
BASE_URL = "https://api.example.com/v1"

response = requests.get(
    f"{BASE_URL}/users",
    headers={"Authorization": f"Bearer {API_KEY}"}
)

print(response.json())
# Output: {"users": [{"id": 1, "name": "Alice"}, ...]}
```

<!-- Avoid: Incomplete snippet -->
```python
response = requests.get(url, headers=headers)
```
```

### Write Descriptive Titles and Meta Descriptions

Page titles and descriptions help with search and LLM understanding.

```markdown
---
title: "Authentication - API Reference"
description: "Learn how to authenticate API requests using API keys, OAuth 2.0, or service accounts."
---
```

## Pitfalls to Avoid

### Don't Use Product-Centric Language

Orient documentation around user goals, not product features.

```markdown
<!-- Good: User-goal oriented -->
# Send Emails

Send transactional emails to your users with delivery tracking.

<!-- Avoid: Product-centric -->
# Email Service

Our powerful email service provides enterprise-grade delivery.
```

### Skip Obvious Instructions

Don't document self-explanatory UI actions.

```markdown
<!-- Good: Meaningful instruction -->
Enter your webhook URL. The URL must use HTTPS and be publicly accessible.

<!-- Avoid: Obvious instruction -->
Click in the text field. Type your webhook URL. Click the Save button.
```

### Avoid Colloquialisms

Colloquialisms hurt clarity and localization.

```markdown
<!-- Good -->
This approach significantly improves performance.

<!-- Avoid -->
This approach is a game-changer for performance.
This will blow your mind.
Let's dive in!
```

## Two Kinds of Quality

Good documentation has two layers of quality, and the second depends on the first:

- **Functional quality** — objective and measurable: accuracy, completeness, consistency, usefulness, precision. This is the prerequisite. The principles in this guide and the type-specific skills target functional quality.
- **Deep quality** — subjective and human-centred: it feels good to use, anticipates the reader, and fits how people actually work. You cannot reach it without functional quality first; choosing the right type (above) and writing it cleanly lays the conditions for it.

See [references/diataxis-compass.md](references/diataxis-compass.md) for the full quality model and the "work by improvement" approach (improve one real piece at a time; never build empty section skeletons).

## Quick Reference Checklist

When writing documentation, verify:

- [ ] The document is one clear Diataxis type, not a mix (see [the compass](references/diataxis-compass.md))
- [ ] Using "you" instead of "the user"
- [ ] Active voice throughout
- [ ] No unnecessary words
- [ ] Headings are descriptive
- [ ] Page is self-contained
- [ ] Proper heading hierarchy
- [ ] One term per concept
- [ ] Prerequisites listed
- [ ] Acronyms defined
- [ ] Code examples are complete
- [ ] No product-centric language
- [ ] No colloquialisms

## Applying This Skill

Use these principles when:

1. **Writing new documentation**: Apply all principles from the start
2. **Reviewing documentation**: Check against the quick reference checklist
3. **Editing existing docs**: Prioritize voice/tone, then structure, then consistency
4. **Creating code examples**: Ensure they are complete and runnable
