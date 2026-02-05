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

**2. Partition by key:**

```elixir
defmodule PartitionedCache do
  @partitions 16

  def get(key) do
    partition = :erlang.phash2(key, @partitions)
    GenServer.call(:"cache_#{partition}", {:get, key})
  end
end
```

**3. Use Registry for dynamic workers:**

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

**1. Use Task.Supervisor for async work:**

```elixir
def handle_call(:fetch_external, from, state) do
  task = Task.Supervisor.async_nolink(MyApp.TaskSupervisor, fn ->
    HTTPClient.get!(url)
  end)
  {:noreply, Map.put(state, :pending, {from, task.ref})}
end

def handle_info({ref, result}, %{pending: {from, ref}} = state) do
  Process.demonitor(ref, [:flush])
  GenServer.reply(from, result)
  {:noreply, Map.delete(state, :pending)}
end

def handle_info({:DOWN, ref, :process, _pid, reason}, %{pending: {from, ref}} = state) do
  GenServer.reply(from, {:error, reason})
  {:noreply, Map.delete(state, :pending)}
end
```

**2. Use handle_continue for expensive init:**

```elixir
def init(args) do
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
# Client-side timeout
def fetch(pid) do
  GenServer.call(pid, :fetch, 10_000)  # 10 second timeout
rescue
  exit: {:timeout, _} -> {:error, :timeout}
end

# Server-side timeout for idle
def handle_info(:timeout, state) do
  {:stop, :normal, state}
end

def handle_call(:work, _from, state) do
  {:reply, :ok, state, 30_000}  # 30s idle timeout
end
```

## Review Questions

1. Is this GenServer a potential bottleneck under load?
2. Are there blocking I/O operations in callbacks?
3. Would ETS be more appropriate for this use case?
4. Are timeouts configured appropriately?
