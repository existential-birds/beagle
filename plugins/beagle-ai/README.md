# beagle-ai

Pydantic AI, LangGraph, DeepAgents, and Vercel AI SDK skills for [Claude Code](https://claude.ai/code). Part of the [beagle](https://github.com/existential-birds/beagle) plugin marketplace.

## Installation

```bash
# Add the marketplace (if not already added)
claude plugin marketplace add https://github.com/existential-birds/beagle

# Install the plugin
claude plugin install beagle-ai@existential-birds
```

## Skills

| Skill | Description |
|-------|-------------|
| **pydantic-ai-agent-creation** | Create PydanticAI agents with type-safe dependencies, structured outputs, and proper configuration |
| **pydantic-ai-common-pitfalls** | Avoid common mistakes and debug issues in PydanticAI agents |
| **pydantic-ai-dependency-injection** | Implement dependency injection using RunContext and deps_type |
| **pydantic-ai-model-integration** | Configure LLM providers, fallback models, streaming, and model settings |
| **pydantic-ai-testing** | Test PydanticAI agents using TestModel, FunctionModel, VCR cassettes, and inline snapshots |
| **pydantic-ai-tool-system** | Register and implement PydanticAI tools with proper context handling and type annotations |
| **langgraph-architecture** | Architectural decisions for LangGraph applications, state management, and multi-agent design |
| **langgraph-code-review** | Review LangGraph code for bugs and anti-patterns in state management, graph structure, and async |
| **langgraph-implementation** | Implement stateful agent graphs with nodes, edges, checkpointing, and interrupts |
| **deepagents-architecture** | Architectural decisions for Deep Agents applications, backend strategies, and subagent design |
| **deepagents-code-review** | Review Deep Agents code for configuration and usage mistakes in backends, subagents, and middleware |
| **deepagents-implementation** | Implement agents using create_deep_agent with backends, subagents, middleware, and human-in-the-loop |
| **vercel-ai-sdk** | Build streaming chat interfaces with useChat, tool calls, and multi-step reasoning |

### Reference Material

Each implementation skill includes detailed reference documents:

**deepagents-implementation**: implementation patterns, tool configuration

**langgraph-implementation**: common graph patterns

**vercel-ai-sdk**: messages, streaming, tools, useChat hook

## See Also

- [beagle-core](../beagle-core) - Shared workflows, verification protocol, and git commands
- [beagle marketplace](https://github.com/existential-birds/beagle) - Full plugin marketplace with 10 focused plugins
