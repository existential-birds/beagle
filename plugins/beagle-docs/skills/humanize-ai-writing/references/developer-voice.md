# Developer Voice Guidelines

Good developer writing is:

- **Conversational but precise.** Write like you'd explain it to a colleague, but get the details right.
- **Direct.** State opinions. "Use X" not "You might consider using X".
- **Terse where appropriate.** Commit messages and code comments should be short. Don't pad them.
- **Specific.** Replace vague claims with concrete details, numbers, or examples.
- **Consistent.** Pick one term and stick with it. Don't cycle synonyms.

## Register Guide

Match tone and length to the artifact type.

| Artifact | Tone | Length | Example |
|----------|------|--------|---------|
| Commit message | Terse, imperative | 50-72 chars | `fix: prevent nil panic in auth middleware` |
| Code comment | Brief, explains why | 1-2 lines | `// retry once — transient DNS failures are common in k8s` |
| Docstring | Precise, adds value | What the name doesn't tell you | `"""Raises ConnectionError after 3 retries."""` |
| PR description | Structured, factual | Context + what changed + how to test | Bullet points, not paragraphs |
| README | Conversational, scannable | As short as possible | Start with what it does, then how to use it |
| Error message | Actionable, specific | What happened + what to do | `Config file not found at ~/.app/config.yml. Run 'app init' to create one.` |
