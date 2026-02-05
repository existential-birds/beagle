# ETS Patterns

## When to Use ETS

| Use Case | ETS? |
|----------|------|
| Read-heavy cache | Yes |
| Write-heavy with consistency | No (use GenServer) |
| Shared state across processes | Yes |
| Small, single-process state | No (use GenServer) |

## Table Types

```elixir
# :set - one value per key (default)
:ets.new(:cache, [:set])

# :bag - multiple values per key
:ets.new(:events, [:bag])

# :ordered_set - sorted by key
:ets.new(:timeline, [:ordered_set])
```

## Concurrency Options

```elixir
# Read-heavy workload
:ets.new(:cache, [:set, :public, :named_table,
  read_concurrency: true
])

# Write-heavy workload
:ets.new(:counters, [:set, :public, :named_table,
  write_concurrency: true
])

# Both
:ets.new(:mixed, [:set, :public, :named_table,
  read_concurrency: true,
  write_concurrency: true
])
```

## Common Patterns

### Cache with TTL

```elixir
defmodule TTLCache do
  def put(key, value, ttl_ms) do
    expires_at = System.monotonic_time(:millisecond) + ttl_ms
    :ets.insert(:cache, {key, value, expires_at})
  end

  def get(key) do
    case :ets.lookup(:cache, key) do
      [{^key, value, expires_at}] ->
        if System.monotonic_time(:millisecond) < expires_at do
          {:ok, value}
        else
          :ets.delete(:cache, key)
          :expired
        end

      [] ->
        :not_found
    end
  end
end
```

### Counter

```elixir
# Atomic counter updates
:ets.update_counter(:stats, :requests, 1, {:requests, 0})
```

### Match Specifications

```elixir
# Find all users with role :admin
:ets.select(:users, [
  {{:"$1", %{role: :admin}}, [], [:"$1"]}
])

# Using match
:ets.match(:users, {:"$1", %{role: :admin, name: :"$2"}})
# Returns [[id1, name1], [id2, name2], ...]
```

## Access Control

```elixir
# :public - any process can read/write
# :protected - owner writes, any reads (default)
# :private - only owner

:ets.new(:shared, [:public])    # Multi-process cache
:ets.new(:config, [:protected]) # Owner updates, all read
:ets.new(:internal, [:private]) # Single process only
```

## Ownership and Lifecycle

```elixir
# ETS table dies with owner process
# Use a dedicated process to own long-lived tables

defmodule TableOwner do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    table = :ets.new(:my_table, [:public, :named_table])
    {:ok, table}
  end
end
```

## Review Questions

1. Is ETS appropriate for this use case (read vs write ratio)?
2. Are concurrency options set correctly?
3. Is table ownership properly managed?
4. Are access controls appropriate?
