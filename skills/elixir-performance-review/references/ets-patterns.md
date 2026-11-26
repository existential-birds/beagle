# ETS, `:persistent_term`, and `:atomics` Patterns

## Choosing the Right Shared Storage

| Use Case | Tool |
|----------|------|
| Read-heavy mutable cache | ETS (`read_concurrency: true`) |
| Write-heavy / high-contention counters or metrics | `:counters` / `:atomics`, or ETS with `write_concurrency: true, decentralized_counters: true` |
| Static or rarely updated global configuration / large read-only terms | `:persistent_term` (zero-copy reads; expensive writes trigger global GC) |
| Write-heavy with serialized consistency | GenServer / `PartitionSupervisor` |
| Small, single-process state | GenServer |

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

# Write-heavy workload (OTP 23+: enable decentralized_counters for concurrent writes/size)
:ets.new(:counters, [:set, :public, :named_table,
  write_concurrency: true,
  decentralized_counters: true
])

# Mixed concurrent read/write
:ets.new(:mixed, [:set, :public, :named_table,
  read_concurrency: true,
  write_concurrency: true,
  decentralized_counters: true
])
```

## Common Patterns

### Cache with TTL (Needs Periodic Sweep)

Lazy expiration in `get/1` only deletes an expired key if that exact key is read again — without a periodic sweep/eviction job (e.g. `:ets.select_delete/2` on a timer), unqueried expired keys leak memory indefinitely:

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

  # Run periodically from an owner GenServer via Process.send_after/3
  def sweep_expired do
    now = System.monotonic_time(:millisecond)
    :ets.select_delete(:cache, [{{:_, :_, :"$1"}, [{:<, :"$1", now}], [true]}])
  end
end
```

### Lock-Free Counters (`:atomics` / `:counters` vs ETS)

For pure integer counters under heavy concurrency, `:atomics` or `:counters` avoid ETS table lock contention entirely; for keyed counters in ETS, use `:ets.update_counter/4`:

```elixir
# Atomic counter updates in ETS
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

*(Never store sensitive secrets/tokens in `:public` or `:protected` ETS — any process can read them.)*

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
    table = :ets.new(:my_table, [:public, :named_table, read_concurrency: true])
    {:ok, table}
  end
end
```

## Review Questions

1. Is ETS appropriate vs `:persistent_term` (rarely updated read-only data) or `:atomics`/`:counters` (high-contention counters)?
2. Are `read_concurrency`, `write_concurrency`, and `decentralized_counters: true` set appropriately?
3. Do TTL caches periodically sweep unqueried expired entries?
4. Is table ownership and access control (`:public`/`:protected`/`:private`) properly managed?
