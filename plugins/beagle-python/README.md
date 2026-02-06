# beagle-python

Python, FastAPI, SQLAlchemy, PostgreSQL, and pytest code review skills for [Claude Code](https://claude.ai/code). Part of the [beagle](https://github.com/existential-birds/beagle) plugin marketplace.

## Installation

```bash
# Add the marketplace (if not already added)
claude plugin marketplace add https://github.com/existential-birds/beagle

# Install the plugin
claude plugin install beagle-python@existential-birds
```

## Commands

| Command | Usage | Description |
|---------|-------|-------------|
| **review-python** | `/beagle-python:review-python` | Review changed `.py` files against `main` with automatic framework detection |

Reviews changed Python files against `main`, detects which frameworks you use, and loads the appropriate skills automatically. Pass `--parallel` to spawn specialized subagents per technology area.

## Skills

| Skill | Description |
|-------|-------------|
| **python-code-review** | Type safety, async patterns, error handling, and common mistakes |
| **fastapi-code-review** | Routing patterns, dependency injection, validation, and async handlers |
| **sqlalchemy-code-review** | Session management, relationships, N+1 queries, and migration patterns |
| **postgres-code-review** | Indexing strategies, JSONB operations, connection pooling, and transaction safety |
| **pytest-code-review** | Async test patterns, fixtures, parametrize, and mocking |
| **review-verification-protocol** | Mandatory verification steps to reduce false positives |

### Reference Material

Each review skill includes detailed reference documents:

**python-code-review**: pep8 style, type safety, async patterns, error handling, common mistakes

**fastapi-code-review**: routes, dependencies, validation, async

**sqlalchemy-code-review**: sessions, relationships, queries, migrations

**postgres-code-review**: indexes, JSONB, connections, transactions

**pytest-code-review**: async testing, fixtures, parametrize, mocking

## See Also

- [beagle-core](../beagle-core) - Shared workflows, verification protocol, and git commands
- [beagle marketplace](https://github.com/existential-birds/beagle) - Full plugin marketplace with 10 focused plugins
