# GenServer Bottlenecks

## Single Process Bottleneck

### The Problem

```elixir
# BAD - all requests through one process
defmodule Cache do
  use GenServer

  def get(key), do: GenServer.call(__MODULE__, {:get, key})
  def put(key, val), do: GenServer.call(__MODULE__, {:put, key, val})
end
```

Every request queues in the GenServer's mailbox. Under load:
- Mailbox grows unbounded
- Latency increases linearly
- Memory pressure from queued messages

### Solutions

**1. Use ETS for read-heavy workloads:**

```elixir
defmodule Cache do
  def init do
    :ets.new(:cache, [:set, :public, :named_table, read_concurrency: true])
  end

  def get(key), do: :ets.lookup(:cache, key)
  def put(key, val), do: :ets.insert(:cache, {key, val})
end
```

**2. Partition by key with `PartitionSupervisor` (Elixir 1.14+):**

Avoid dynamic atom interpolation like `:"cache_#{partition}"` — use `PartitionSupervisor` with `:via` tuples:

```elixir
# In Application supervision tree:
{PartitionSupervisor, child_spec: MyApp.CacheWorker, name: MyApp.CachePartitions}

# Caller routes by key deterministically without atom creation:
defmodule PartitionedCache do
  def get(key) do
    GenServer.call({:via, PartitionSupervisor, {MyApp.CachePartitions, key}}, {:get, key})
  end
end
```

**3. Use `Registry` for dynamic per-key workers:**

```elixir
defmodule WorkerPool do
  def get_worker(key) do
    case Registry.lookup(MyRegistry, key) do
      [{pid, _}] -> pid
      [] -> start_worker(key)
    end
  end
end
```

## Blocking Operations

### The Problem

```elixir
# BAD - blocks entire GenServer
def handle_call(:fetch_external, _from, state) do
  result = HTTPClient.get!(url)  # 500ms+ network call
  {:reply, result, state}
end
```

All other messages wait during the HTTP call.

### Solutions

**1. Use `Task.Supervisor` for async work (with `:DOWN` + `demonitor`):**

```elixir
def handle_call(:fetch_external, from, state) do
  task =
    Task.Supervisor.async_nolink(MyApp.TaskSupervisor, fn ->
      HTTPClient.get!(url)
    end)

  {:noreply, put_in(state.pending[task.ref], from)}
end

def handle_info({ref, result}, state) do
  case Map.pop(state.pending, ref) do
    {nil, _pending} ->
      {:noreply, state}

    {from, pending} ->
      Process.demonitor(ref, [:flush])
      GenServer.reply(from, result)
      {:noreply, %{state | pending: pending}}
  end
end

def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
  case Map.pop(state.pending, ref) do
    {nil, _pending} ->
      {:noreply, state}

    {from, pending} ->
      GenServer.reply(from, {:error, reason})
      {:noreply, %{state | pending: pending}}
  end
end
```

**2. Use `handle_continue/2` for expensive init:**

```elixir
def init(_args) do
  {:ok, %{}, {:continue, :load_data}}
end

def handle_continue(:load_data, state) do
  data = expensive_load()
  {:noreply, %{state | data: data}}
end
```

## Timeouts

### Configure Appropriately

```elixir
# Client-side timeout (use catch :exit, not rescue - timeouts are exit signals)
def fetch(pid) do
  try do
    GenServer.call(pid, :fetch, 10_000)
  catch
    :exit, {:timeout, _} -> {:error, :timeout}
  end
end

# Server-side idle timeout
def handle_info(:timeout, state) do
  {:stop, :normal, state}
end

def handle_call(:work, _from, state) do
  {:reply, :ok, state, 30_000}  # 30s idle timeout
end
```

## Review Questions

1. Is this GenServer a potential bottleneck under load (consider ETS or `PartitionSupervisor`)?
2. Are there blocking I/O operations in callbacks?
3. Are `Task.Supervisor.async_nolink` tasks tracked by `task.ref` with both reply and `:DOWN` handlers?
4. Are timeouts configured and caught via `catch :exit, {:timeout, _}`?
