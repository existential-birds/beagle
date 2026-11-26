# Memory Patterns

## Binary Handling

### Large Binaries Are Reference Counted

Binaries > 64 bytes are stored on the shared binary heap. Copying between processes is cheap (reference copy), **but** slicing a sub-binary from a large binary retains a reference to the entire parent binary until the sub-binary is garbage-collected.

```elixir
# Efficient - only reference copied across processes
send(pid, large_binary)

# Beware: sub-binary retains reference to entire large_binary!
<<header::binary-size(100), _rest::binary>> = large_binary
```

### Force Copy When Retaining Sub-Binaries

Copy the extracted slice — **not** the match expression itself (because `<<...>> = large_binary` evaluates to `large_binary`):

```elixir
# BAD - match evaluates to large_binary, so :binary.copy copies the entire binary!
header = :binary.copy(<<header::binary-size(100), _::binary>> = large_binary)

# GOOD - extract slice first, then copy only the 100-byte slice
<<header::binary-size(100), _::binary>> = large_binary
header = :binary.copy(header)
```

## Process Heap

### Large State = Large GC

Each process has its own heap. Large state means:
- Longer GC pauses
- More memory per process

```elixir
# BAD - accumulating unbounded state
def handle_cast({:add, item}, state) do
  {:noreply, %{state | items: [item | state.items]}}  # Grows forever!
end

# GOOD - bounded state
def handle_cast({:add, item}, state) do
  items = Enum.take([item | state.items], @max_items)
  {:noreply, %{state | items: items}}
end
```

### Use ETS for Large Shared State

```elixir
# BAD - large map in GenServer
defmodule BigCache do
  use GenServer
  def init(_), do: {:ok, %{}}  # Millions of entries here
end

# GOOD - ETS for large state
defmodule BigCache do
  def init do
    :ets.new(:cache, [:set, :public, :named_table])
  end
end
```

## Message Passing

### Avoid Large Message Copies

```elixir
# BAD - copies entire list to each process
Enum.each(workers, fn pid ->
  send(pid, {:process, large_list})
end)

# GOOD - send reference or key
Enum.each(workers, fn pid ->
  send(pid, {:process, :ets.whereis(:data), key})
end)
```

## Streams for Large Data

### Use Streams to Avoid Loading All in Memory

```elixir
# BAD - loads entire file
File.read!("large.csv")
|> String.split("\n")
|> Enum.map(&parse_line/1)

# GOOD - streams line by line
File.stream!("large.csv")
|> Stream.map(&parse_line/1)
|> Enum.to_list()  # Or process incrementally
```

### Database Streams

`Repo.stream/2` requires an active database cursor and **raises at runtime if enumerated outside `Repo.transaction/2`**:

```elixir
# BAD - loads all records into memory
Repo.all(User)
|> Enum.map(&process/1)

# BAD - raises because Repo.stream must run inside Repo.transaction!
User
|> Repo.stream()
|> Stream.map(&process/1)
|> Stream.run()

# GOOD - streams inside Repo.transaction
Repo.transaction(fn ->
  User
  |> Repo.stream()
  |> Stream.map(&process/1)
  |> Stream.run()
end)
```

## Detecting Memory Issues

```elixir
# Process memory
Process.info(self(), :memory)

# System memory
:erlang.memory()

# Binary memory specifically
:erlang.memory(:binary)
```

## Review Questions

1. Are sub-binaries retained from large (>64B) binaries copied with `:binary.copy/1` on the extracted slice?
2. Is process state bounded or growing unbounded?
3. Are streams used for large data processing, with `Repo.stream/2` wrapped in `Repo.transaction/2`?
4. Is shared state in ETS rather than a GenServer process heap?
