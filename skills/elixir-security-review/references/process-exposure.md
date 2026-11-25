# Process Exposure

## ETS Visibility

### Access Levels

```elixir
# :public    - any process can read/write
# :protected - owner writes, ANY process can read (default!)
# :private   - ONLY owner process can read/write

# DANGEROUS if table contains sensitive tokens or secrets
:ets.new(:sessions, [:public])     # Any process can read and write!
:ets.new(:sessions, [:protected])  # Any process on the node can STILL read!

# SAFE for sensitive data - restrict reads and writes to owner process
:ets.new(:sessions, [:private])
```

### Sensitive Data in ETS

```elixir
# BAD - plaintext tokens readable by any process in :public/:protected ETS
:ets.insert(:cache, {:user_123, %{token: "secret_token"}})

# GOOD - store opaque reference or use :private ETS owned by a dedicated process
:ets.insert(:cache, {:user_123, %{token_id: "ref_abc"}})
```

## Process Dictionary

### Dangers

The process dictionary is:
- Readable by any process via `Process.info(pid, :dictionary)`
- Included in OTP crash reports
- Not access-controlled

```elixir
# BAD - secret in process dictionary
Process.put(:api_token, "secret123")
# After crash, token is dumped in crash/error reports!
```

### GenServer State & Crash Reports

OTP GenServer crash reports **DO log `State` (and `Last message`) by default** on abnormal termination unless you explicitly redact them using `GenServer.format_status/1` or `@derive {Inspect, except: [...]}`:

```elixir
defmodule SecureWorker do
  use GenServer

  def init(token) do
    {:ok, %{token: token}}
  end

  # OTP 25+ / Elixir 1.15+: format_status/1 (format_status/2 is deprecated)
  @impl GenServer
  def format_status(status) do
    Map.update(status, :state, nil, &MyApp.ErrorReporter.format_state/1)
  end
end
```

## Registered Process Names

### Enumerable

```elixir
# All registered names are globally visible via Process.registered()
# BAD - encodes secret in registered name
Process.register(self(), :"worker_secret_token_abc123")

# GOOD
Process.register(self(), :worker_1)
```

## Observer / Remote Shell

In production:
- Observer / Erlang distribution exposes all processes and ETS tables
- Restrict distribution ports via firewall / TLS distribution and disable unnecessary remote shell exposure

## Crash Reports

### Sensitive Data Redaction (`format_status/1`)

`format_status/2` (`def format_status(_reason, [_pdict, state])`) is deprecated in OTP 25+ / Elixir 1.15+. Always implement `format_status/1` taking and returning the status map:

```elixir
defmodule MyApp.ErrorReporter do
  def format_state(state) when is_map(state) do
    state
    |> Map.replace(:token, "[REDACTED]")
    |> Map.replace(:password, "[REDACTED]")
  end
end

# Inside GenServer
@impl GenServer
def format_status(status) do
  Map.update(status, :state, nil, &MyApp.ErrorReporter.format_state/1)
end
```

## Review Questions

1. Do ETS tables storing sensitive secrets or session tokens use `:private` (never `:protected` or `:public`)?
2. Is sensitive data stored in the process dictionary or encoded in registered process names?
3. Do GenServers holding sensitive state implement `format_status/1` (not deprecated `format_status/2`) or `@derive {Inspect, except: [...]}` to redact crash reports?
4. Is production Erlang distribution / remote shell access properly restricted?
