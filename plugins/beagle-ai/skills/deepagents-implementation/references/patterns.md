# Common Patterns

## Research Agent with Memory

```python
from langgraph.store.memory import InMemoryStore
from deepagents import create_deep_agent
from deepagents.backends import CompositeBackend, StateBackend, StoreBackend

store = InMemoryStore()

agent = create_deep_agent(
    tools=[web_search],
    system_prompt="""You are a research assistant with persistent memory.
    Save important findings to /memories/ for future reference.
    Check /memories/ at the start of research tasks.""",
    backend=CompositeBackend(
        default=StateBackend(),
        routes={"/memories/": StoreBackend(store=store)},
    ),
    store=store,
    checkpointer=checkpointer,
)
```

## Code Assistant with Disk Access

```python
from deepagents import create_deep_agent
from deepagents.backends import FilesystemBackend

agent = create_deep_agent(
    system_prompt="You are a coding assistant. Help users with their codebase.",
    backend=FilesystemBackend(root_dir="/Users/dev/project"),
)

# Agent can now read/write real files and execute shell commands
```

## Multi-Specialist Team

```python
agent = create_deep_agent(
    subagents=[
        {
            "name": "researcher",
            "description": "Deep research and fact-finding",
            "system_prompt": "Research thoroughly, cite sources.",
            "tools": [web_search],
        },
        {
            "name": "writer",
            "description": "Write polished content",
            "system_prompt": "Write clear, engaging content.",
            "tools": [],
        },
        {
            "name": "reviewer",
            "description": "Review and critique content",
            "system_prompt": "Provide constructive feedback.",
            "tools": [],
        },
    ],
    system_prompt="""Coordinate the team:
    1. Use researcher for facts
    2. Use writer to draft
    3. Use reviewer to polish""",
)
```

## Production Setup

```python
from langgraph.checkpoint.postgres import PostgresSaver
from langgraph.store.postgres import PostgresStore
from deepagents import create_deep_agent
from deepagents.backends import CompositeBackend, StateBackend, StoreBackend

# Production persistence
checkpointer = PostgresSaver.from_conn_string(DATABASE_URL)
store = PostgresStore.from_conn_string(DATABASE_URL)

agent = create_deep_agent(
    model="anthropic:claude-sonnet-4-5-20250929",
    tools=[...],
    backend=CompositeBackend(
        default=StateBackend(),
        routes={"/memories/": StoreBackend(store=store)},
    ),
    checkpointer=checkpointer,
    store=store,
)
```
