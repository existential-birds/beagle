# beagle-python

Python, FastAPI, SQLAlchemy, PostgreSQL, and pytest code review. Part of the [beagle](https://github.com/existential-birds/beagle) Agent Skills marketplace — see the [full skill catalog](../../SKILLS.md).

## Installation

For any coding agent that supports [Agent Skills](https://agentskills.io):

```bash
npx skills add existential-birds/beagle
```

For Claude Code:

```bash
claude plugin marketplace add https://github.com/existential-birds/beagle
claude plugin install beagle-python@existential-birds
```

## Skills

| Skill | Description |
|-------|-------------|
| `review-python` | Comprehensive Python/FastAPI backend review against `main` with framework detection and optional parallel agents |
| `python-code-review` | Type safety, async patterns, error handling, and common mistakes |
| `fastapi-code-review` | Routing patterns, dependency injection, validation, and async handlers |
| `sqlalchemy-code-review` | Session management, relationships, N+1 queries, and migration patterns |
| `postgres-code-review` | Indexing strategies, JSONB operations, connection pooling, and transaction safety |
| `pytest-code-review` | Async test patterns, fixtures, parametrize, and mocking |
| `review-verification-protocol` | Reference: mandatory verification steps to reduce false positives |

## See Also

- [Skill catalog](../../SKILLS.md) — every skill in the marketplace
- [beagle-core](../beagle-core/README.md) — shared workflows, verification, and git skills
- [beagle marketplace](https://github.com/existential-birds/beagle) — the full Agent Skills marketplace
