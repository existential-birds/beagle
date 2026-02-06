# Skill Integration

## Using Code-Review Skills for Verification

When feedback relates to a specific technology, load the relevant skill
to verify against established codebase patterns.

## Skill Lookup Table

| Feedback Domain | Skill | Key Patterns to Check |
|-----------------|-------|----------------------|
| Python code quality | python-code-review | Type hints, error handling, naming |
| FastAPI endpoints | fastapi-code-review | Dependency injection, response models |
| SQLAlchemy models | sqlalchemy-code-review | Relationships, session handling |
| Pytest tests | pytest-code-review | Fixtures, parametrization, mocking |
| PostgreSQL queries | postgres-code-review | Indexes, joins, transactions |
| React components | shadcn-code-review | Component composition, accessibility |
| React Router | react-router-code-review | Loaders, actions, error boundaries |
| Tailwind styling | tailwind-v4 | Utility classes, responsive design |
| State management | zustand-state | Store structure, selectors |
| Vitest tests | vitest-testing | Test structure, mocking |

## Integration Workflow

1. **Identify domain** - What technology does the feedback concern?
2. **Load skill** - Use Skill tool: `Skill(skill: "beagle:<skill-name>")`
3. **Cross-reference** - Does feedback align with skill guidance?
4. **Resolve conflicts** - If feedback contradicts skill, flag for discussion

## Conflict Resolution

If reviewer feedback conflicts with skill guidance:

```
Skill says: [pattern from skill]
Reviewer says: [contradicting suggestion]

Flag: "Feedback conflicts with established pattern. Discuss before implementing."
```

Codebase patterns (captured in skills) take precedence over external opinions.
