# Pressure-test scenarios

Expected behaviors for the strategy-interview skill. Use these to validate that the skill handles common entry points correctly.

| Scenario | Expected behavior |
|----------|-------------------|
| User says "write a strategy to grow 30%" | Enter discovery, do not produce a draft — "grow 30%" is a goal, not a strategy |
| User provides an existing strategy doc | Start with bad-strategy filter before discovery |
| User stops mid-interview | Write strategy-notes.md with resume state only, no strategy-draft.md |
| User describes a feature arms race | Deploy value innovation prompts from blue-ocean lens |
| User asks for career strategy | Skip Wardley/cascade unless conversation warrants them |
| User says "just critique this, don't rewrite it" | Use critique variant, respect chat-only if requested |
