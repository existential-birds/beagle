# Concurrency Patterns

## Task Patterns

### Use Task.Supervisor for Dynamic Tasks

```elixir
# BAD - unlinked task, crashes silently
Task.async(fn -> risky_work() end)

# BAD - linked task, crashes caller
Task.async(fn -> risky_work() end) |> Task.await()

# GOOD - supervised, restartable
Task.Supervisor.async_nolink(MyTaskSupervisor, fn ->
  risky_work()
end)
```

### Parallel Processing

```elixir
# Process items concurrently with limit
Task.Supervisor.async_stream_nolink(
  MyTaskSupervisor,
  items,
  fn item -> process(item) end,
  max_concurrency: 10,
  ordered: false
)
|> Enum.to_list()
```

### Timeout Handling

```elixir
task = Task.Supervisor.async_nolink(MySup, fn -> slow_work() end)

case Task.yield(task, 5_000) || Task.shutdown(task) do
  {:ok, result} -> {:ok, result}
  nil -> {:error, :timeout}
  {:exit, reason} -> {:error, reason}
end
```

## Backpressure

### GenStage / Broadway for Backpressure

```elixir
# Producer-consumer with demand
defmodule MyConsumer do
  use GenStage

  def handle_events(events, _from, state) do
    process(events)
    {:noreply, [], state}  # Demand more when ready
  end
end
```

### Manual Backpressure

```elixir
# Limit concurrent operations
defmodule RateLimiter do
  use GenServer

  def init(_) do
    {:ok, %{active: 0, max: 10, queue: :queue.new()}}
  end

  def handle_call(:acquire, from, %{active: n, max: max} = state) when n < max do
    {:reply, :ok, %{state | active: n + 1}}
  end

  def handle_call(:acquire, from, state) do
    {:noreply, %{state | queue: :queue.in(from, state.queue)}}
  end

  def handle_cast(:release, %{queue: queue, active: n} = state) do
    case :queue.out(queue) do
      {{:value, from}, queue} ->
        GenServer.reply(from, :ok)
        {:noreply, %{state | queue: queue}}

      {:empty, _} ->
        {:noreply, %{state | active: n - 1}}
    end
  end
end
```

## Process Spawning

### Don't Spawn Unbounded

```elixir
# BAD - spawns process per request
def handle_request(req) do
  spawn(fn -> process(req) end)  # Unbounded!
end

# GOOD - use pool
def handle_request(req) do
  :poolboy.transaction(:worker_pool, fn pid ->
    Worker.process(pid, req)
  end)
end
```

### DynamicSupervisor for Bounded Children

```elixir
defmodule MyDynamicSup do
  use DynamicSupervisor

  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, [],
      name: __MODULE__,
      max_children: 100  # Bounded!
    )
  end
end
```

## Review Questions

1. Are dynamic tasks under a Task.Supervisor?
2. Is there backpressure for high-volume producers?
3. Is process spawning bounded?
4. Are timeouts configured for async operations?
