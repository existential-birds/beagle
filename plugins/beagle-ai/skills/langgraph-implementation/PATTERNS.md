# Advanced LangGraph Patterns

## Multi-Agent Supervisor Pattern

```python
from langgraph.graph import StateGraph, START, END
from langgraph.types import Command
from typing import Literal

class SupervisorState(TypedDict):
    messages: Annotated[list, add_messages]
    next_agent: str

def supervisor(state: SupervisorState) -> Command[Literal["researcher", "coder", "__end__"]]:
    """Route to appropriate agent based on task."""
    # LLM decides which agent to use
    decision = llm.invoke(state["messages"])
    if "research" in decision.content.lower():
        return Command(goto="researcher")
    elif "code" in decision.content.lower():
        return Command(goto="coder")
    return Command(goto=END)

def researcher(state: SupervisorState) -> dict:
    result = research_agent.invoke(state["messages"])
    return {"messages": [result]}

def coder(state: SupervisorState) -> dict:
    result = coding_agent.invoke(state["messages"])
    return {"messages": [result]}

builder = StateGraph(SupervisorState)
builder.add_node("supervisor", supervisor, destinations=["researcher", "coder", END])
builder.add_node("researcher", researcher)
builder.add_node("coder", coder)
builder.add_edge(START, "supervisor")
builder.add_edge("researcher", "supervisor")
builder.add_edge("coder", "supervisor")
```

## Map-Reduce Pattern

```python
from langgraph.types import Send

class MapReduceState(TypedDict):
    topics: list[str]
    results: Annotated[list[str], operator.add]  # Reducer aggregates

def distribute(state: MapReduceState) -> list[Send]:
    """Fan out to process each topic."""
    return [Send("process_topic", {"topic": t}) for t in state["topics"]]

def process_topic(state: dict) -> dict:
    """Process individual topic (receives Send payload)."""
    result = analyze(state["topic"])
    return {"results": [result]}

def aggregate(state: MapReduceState) -> dict:
    """Combine all results."""
    summary = summarize(state["results"])
    return {"summary": summary}

builder = StateGraph(MapReduceState)
builder.add_conditional_edges(START, distribute)
builder.add_edge("process_topic", "aggregate")
builder.add_edge("aggregate", END)
```

## Hierarchical Graph Pattern

```python
# Inner graph - specialized task
class InnerState(TypedDict):
    query: str
    result: str

inner_builder = StateGraph(InnerState)
inner_builder.add_node("search", search_fn)
inner_builder.add_node("analyze", analyze_fn)
inner_builder.add_edge(START, "search")
inner_builder.add_edge("search", "analyze")
inner_builder.add_edge("analyze", END)
inner_graph = inner_builder.compile()

# Outer graph - orchestration
class OuterState(TypedDict):
    messages: Annotated[list, add_messages]
    research_result: str

def prepare_research(state: OuterState) -> dict:
    """Transform outer state for inner graph."""
    return {"query": state["messages"][-1].content}

def process_result(state: OuterState) -> dict:
    """Handle result from inner graph."""
    return {"messages": [AIMessage(content=state["research_result"])]}

outer_builder = StateGraph(OuterState)
outer_builder.add_node("prepare", prepare_research)
outer_builder.add_node("research", inner_graph)  # Subgraph as node
outer_builder.add_node("process", process_result)
outer_builder.add_edge(START, "prepare")
outer_builder.add_edge("prepare", "research")
outer_builder.add_edge("research", "process")
outer_builder.add_edge("process", END)
```

## Reflection/Self-Correction Pattern

```python
class ReflectionState(TypedDict):
    draft: str
    feedback: str
    revision_count: int

def generate(state: ReflectionState) -> dict:
    if state.get("feedback"):
        prompt = f"Revise based on: {state['feedback']}\n\nDraft: {state['draft']}"
    else:
        prompt = "Generate initial draft"
    return {"draft": llm.invoke(prompt).content}

def reflect(state: ReflectionState) -> dict:
    feedback = critic_llm.invoke(f"Critique this: {state['draft']}").content
    return {"feedback": feedback, "revision_count": state.get("revision_count", 0) + 1}

def should_continue(state: ReflectionState) -> Literal["generate", "__end__"]:
    if state["revision_count"] >= 3:
        return END
    if "looks good" in state["feedback"].lower():
        return END
    return "generate"

builder = StateGraph(ReflectionState)
builder.add_node("generate", generate)
builder.add_node("reflect", reflect)
builder.add_edge(START, "generate")
builder.add_edge("generate", "reflect")
builder.add_conditional_edges("reflect", should_continue)
```

## Plan-and-Execute Pattern

```python
class PlanExecuteState(TypedDict):
    objective: str
    plan: list[str]
    completed_steps: Annotated[list[str], operator.add]
    current_step: int

def planner(state: PlanExecuteState) -> dict:
    plan = planning_llm.invoke(f"Create plan for: {state['objective']}")
    steps = parse_steps(plan.content)
    return {"plan": steps, "current_step": 0}

def executor(state: PlanExecuteState) -> dict:
    step = state["plan"][state["current_step"]]
    result = execute_step(step)
    return {
        "completed_steps": [f"{step}: {result}"],
        "current_step": state["current_step"] + 1
    }

def should_continue(state: PlanExecuteState) -> Literal["executor", "__end__"]:
    if state["current_step"] >= len(state["plan"]):
        return END
    return "executor"

builder = StateGraph(PlanExecuteState)
builder.add_node("planner", planner)
builder.add_node("executor", executor)
builder.add_edge(START, "planner")
builder.add_edge("planner", "executor")
builder.add_conditional_edges("executor", should_continue)
```

## Human Approval Gate Pattern

```python
from langgraph.types import interrupt, Command

class ApprovalState(TypedDict):
    action: str
    approved: bool
    result: str

def propose_action(state: ApprovalState) -> dict:
    action = determine_action(state)
    return {"action": action}

def human_review(state: ApprovalState) -> dict:
    decision = interrupt({
        "action": state["action"],
        "message": "Please approve or reject this action"
    })
    return {"approved": decision.get("approved", False)}

def execute_action(state: ApprovalState) -> dict:
    if state["approved"]:
        result = execute(state["action"])
    else:
        result = "Action rejected by human"
    return {"result": result}

def route_after_review(state: ApprovalState) -> Literal["execute", "__end__"]:
    return "execute" if state["approved"] else END

builder = StateGraph(ApprovalState)
builder.add_node("propose", propose_action)
builder.add_node("review", human_review)
builder.add_node("execute", execute_action)
builder.add_edge(START, "propose")
builder.add_edge("propose", "review")
builder.add_conditional_edges("review", route_after_review)
builder.add_edge("execute", END)

graph = builder.compile(checkpointer=checkpointer)

# Usage
config = {"configurable": {"thread_id": "1"}}
result = graph.invoke({"action": ""}, config)
# Graph pauses at review node

# Resume with approval
graph.invoke(Command(resume={"approved": True}), config)
```

## Branching and Joining

```python
class BranchState(TypedDict):
    input: str
    branch_a_result: str
    branch_b_result: str
    final_result: str

builder = StateGraph(BranchState)
builder.add_node("branch_a", branch_a_fn)
builder.add_node("branch_b", branch_b_fn)
builder.add_node("join", join_fn)

# Fan out - both run in parallel
builder.add_edge(START, "branch_a")
builder.add_edge(START, "branch_b")

# Fan in - wait for both
builder.add_edge(["branch_a", "branch_b"], "join")
builder.add_edge("join", END)
```

## Looping with Counter

```python
class LoopState(TypedDict):
    value: int
    iterations: int

def increment(state: LoopState) -> dict:
    return {
        "value": state["value"] * 2,
        "iterations": state["iterations"] + 1
    }

def should_loop(state: LoopState) -> Literal["increment", "__end__"]:
    if state["iterations"] >= 5:
        return END
    if state["value"] >= 1000:
        return END
    return "increment"

builder = StateGraph(LoopState)
builder.add_node("increment", increment)
builder.add_edge(START, "increment")
builder.add_conditional_edges("increment", should_loop)
```

## Error Recovery Pattern

```python
from langgraph.types import RetryPolicy

class ErrorRecoveryState(TypedDict):
    input: str
    result: str
    error: str
    attempts: int

def risky_operation(state: ErrorRecoveryState) -> dict:
    try:
        result = dangerous_api_call(state["input"])
        return {"result": result, "error": ""}
    except Exception as e:
        return {"error": str(e), "attempts": state.get("attempts", 0) + 1}

def fallback(state: ErrorRecoveryState) -> dict:
    return {"result": f"Fallback result for: {state['input']}"}

def route_after_operation(state: ErrorRecoveryState) -> Literal["fallback", "__end__"]:
    if state["error"] and state["attempts"] >= 3:
        return "fallback"
    if state["error"]:
        return "risky_operation"  # Retry
    return END

# With RetryPolicy for automatic retries
retry = RetryPolicy(max_attempts=3, retry_on=ConnectionError)
builder.add_node("risky_operation", risky_operation, retry_policy=retry)
```
