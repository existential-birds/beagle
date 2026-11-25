# Concurrency Patterns

## Task Patterns

### Use Task.Supervisor for Dynamic Tasks

```elixir
# BAD - unlinked task, crashes silently
Task.start(fn -> risky_work() end)

# BAD - linked task, crashes caller if task crashes
Task.async(fn -> risky_work() end) |> Task.await()

# GOOD - supervised, isolated
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

  def handle_call(:acquire, _from, %{active: n, max: max} = state) when n < max do
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

Prefer `NimblePool` (for stateful resource/connection pools), `PartitionSupervisor` (Elixir 1.14+, for partitioned workers), or `Task.Supervisor.async_stream_nolink` over spawning unbounded processes or legacy `:poolboy`:

```elixir
# BAD - spawns process per request
def handle_request(req) do
  spawn(fn -> process(req) end)  # Unbounded!
end

# GOOD - use NimblePool for pooled resources/workers
def handle_request(req) do
  NimblePool.checkout!(MyApp.WorkerPool, :checkout, fn _from, worker ->
    result = Worker.process(worker, req)
    {result, worker}
  end)
end
```

### DynamicSupervisor for Bounded Children

In a module-based `DynamicSupervisor`, `max_children` **must** be passed to `DynamicSupervisor.init/1` inside `init/1` (NOT to `DynamicSupervisor.start_link(__MODULE__, ...)`):

```elixir
defmodule MyDynamicSup do
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one, max_children: 100)
  end
end
```

*(Alternatively, without a wrapper module, pass `{DynamicSupervisor, name: MyDynamicSup, strategy: :one_for_one, max_children: 100}` in the parent supervisor's children list.)*

## Review Questions

1. Are dynamic tasks under a `Task.Supervisor`?
2. Is there backpressure for high-volume producers?
3. Is process spawning bounded (`NimblePool`, `PartitionSupervisor`, or `DynamicSupervisor.init(max_children: ...)` inside `init/1`)?
4. Are timeouts configured for async operations?
