# Process Exposure

## ETS Visibility

### Access Levels

```elixir
# :public - any process can read/write
# :protected - owner writes, anyone reads (default)
# :private - only owner can access

# DANGEROUS if contains sensitive data
:ets.new(:sessions, [:public])  # Any process can read sessions!

# BETTER - protected access
:ets.new(:sessions, [:protected])  # Only owner can write
```

### Sensitive Data in ETS

```elixir
# BAD - tokens visible to all processes
:ets.insert(:cache, {:user_123, %{token: "secret_token"}})

# GOOD - store reference, not secret
:ets.insert(:cache, {:user_123, %{token_id: "ref_abc"}})
# Actual token in secure storage with access controls
```

## Process Dictionary

### Dangers

The process dictionary is:
- Visible via `Process.info(pid, :dictionary)`
- Included in crash reports
- Not access controlled

```elixir
# BAD - secret in process dictionary
Process.put(:api_token, "secret123")

# After crash, token visible in error reports!
```

### Safe Alternatives

```elixir
# Use GenServer state (not in crash reports by default)
defmodule SecureWorker do
  use GenServer

  def init(token) do
    {:ok, %{token: token}}  # In state, not dictionary
  end
end

# Or dedicated secret storage
defmodule Vault do
  def store(key, secret) do
    # Encrypted storage or external secret manager
  end
end
```

## Registered Process Names

### Enumerable

```elixir
# All registered names are visible
Process.registered()  # Returns list of all registered names

# Don't encode secrets in names
# BAD
Process.register(self(), :"worker_secret_token_abc123")

# GOOD
Process.register(self(), :worker_1)
```

## Observer / Remote Shell

In production:
- Observer can inspect all processes
- Remote shell has full access
- Limit who can connect

```elixir
# Restrict remote shell in production
config :my_app, MyAppWeb.Endpoint,
  server: true

# Use firewall rules to limit epmd/distribution ports
```

## Crash Reports

### Sensitive Data Redaction

```elixir
# Custom formatting to redact secrets
defmodule MyApp.ErrorReporter do
  def format_state(state) do
    state
    |> Map.update(:token, "[REDACTED]", fn _ -> "[REDACTED]" end)
    |> Map.update(:password, "[REDACTED]", fn _ -> "[REDACTED]" end)
  end
end

# In GenServer
def format_status(_reason, [_pdict, state]) do
  [data: [{'State', MyApp.ErrorReporter.format_state(state)}]]
end
```

## Review Questions

1. Do ETS tables with sensitive data use :private?
2. Is sensitive data stored in process dictionary?
3. Are crash reports configured to redact secrets?
4. Is production remote access properly restricted?
