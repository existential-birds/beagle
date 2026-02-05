# Memory Patterns

## Binary Handling

### Large Binaries Are Reference Counted

Binaries > 64 bytes are stored on shared heap. Copying between processes is cheap (reference copy).

```elixir
# Efficient - only reference copied
send(pid, large_binary)

# But beware of sub-binaries holding reference to large binary
<<header::binary-size(100), _rest::binary>> = large_binary
# header still references entire large_binary!
```

### Force Copy When Needed

```elixir
# Release reference to large binary
<<header::binary-size(100), _::binary>> = large_binary
header = :binary.copy(header)
```

## Process Heap

### Large State = Large GC

Each process has its own heap. Large state means:
- Longer GC pauses
- More memory per process

```elixir
# BAD - accumulating large state
def handle_cast({:add, item}, state) do
  {:noreply, [item | state.items]}  # Grows forever!
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

```elixir
# BAD - loads all records
Repo.all(User)
|> Enum.map(&process/1)

# GOOD - streams from database
User
|> Repo.stream()
|> Stream.map(&process/1)
|> Stream.run()
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

1. Are large binaries being unnecessarily copied?
2. Is process state bounded or growing unbounded?
3. Are streams used for large data processing?
4. Is shared state in ETS rather than process heap?
