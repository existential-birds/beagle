# ExUnit Pitfalls and Async Safety

## `async: true` with Ecto Sandbox vs Global State

`use MyApp.DataCase, async: true` **IS safe** for database tests because `Ecto.Adapters.SQL.Sandbox` gives each test its own isolated transaction via `start_owner!(MyApp.Repo, shared: not tags[:async])`.

Set `async: false` **only** when a test touches global, cross-process state:

```elixir
# SAFE with async: true (isolated via Ecto Sandbox + $callers)
defmodule MyApp.AccountsTest do
  use MyApp.DataCase, async: true
  # ...
end

# MUST use async: false when mutating global application env or named singletons
defmodule MyApp.FeatureFlagTest do
  use MyApp.DataCase, async: false
  # ...
end
```

## Common `async: true` Race Conditions

### 1. `Application.put_env/3` in `async: true` Tests

`Application.put_env/3` mutates VM-global ETS config. Running it in an `async: true` test causes flaky failures in other concurrent tests:

```elixir
# BAD - races with every other async test reading :my_app config
defmodule MyApp.RateLimitTest do
  use ExUnit.Case, async: true

  setup do
    Application.put_env(:my_app, :rate_limit, 5)
    on_exit(fn -> Application.delete_env(:my_app, :rate_limit) end)
  end
end

# GOOD - pass options explicitly or use async: false with restore
defmodule MyApp.RateLimitTest do
  use ExUnit.Case, async: false

  setup do
    prev = Application.get_env(:my_app, :rate_limit)
    Application.put_env(:my_app, :rate_limit, 5)
    on_exit(fn -> restore_env(:my_app, :rate_limit, prev) end)
  end
end
```

### 2. `ExUnit.CaptureLog` in `async: true` Tests

`capture_log/1` captures **all** Logger messages emitted on the node unless `Logger` level/filtering or `async: false` is accounted for — concurrent `async: true` tests can pollute the captured log buffer:

```elixir
# Watch out for false assertions when async: true tests log concurrently
defmodule MyApp.AuditLogTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  test "logs warning on invalid token" do
    log = capture_log(fn -> MyApp.Auth.verify("bad") end)
    assert log =~ "invalid token"
  end
end
```

### 3. `setup_all` Sharing Pitfalls

`setup_all` runs once in a separate process before all tests in the module:
- Do **not** check out an Ecto Sandbox connection in `setup_all` for `async: true` tests or expect per-test rollback for data inserted in `setup_all` without explicit shared setup.
- Do **not** call `Mox.expect/3` or `Req.Test.expect/3` in `setup_all` — expectations are owned by individual test processes.

### 4. `$callers` Automatic Allowance vs Manual `allow`

In modern Elixir (`Mox`, `Req.Test` via `nimble_ownership`, `Ecto.Adapters.SQL.Sandbox`), processes spawned with `Task.async/1` or `Task.Supervisor.async_nolink/2` automatically inherit the test process in `$callers`. Only long-lived named GenServers or unmanaged `spawn/1` processes require explicit `Mox.allow/3`, `Req.Test.allow/3`, or `Sandbox.allow/3`.

## Review Questions

1. Are any `async: true` tests mutating `Application` env, shared ETS tables, or named singletons?
2. Is `async: false` avoided unnecessarily on standard `DataCase` tests that only use Ecto Sandbox?
3. Does `CaptureLog` or `setup_all` leak state across concurrent or sequential tests?
