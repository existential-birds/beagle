# Mox & Boundary Mocking

## Core Principle

Mock at **external boundaries**, not internal code. For `Req`-based HTTP clients, prefer `Req.Test` (see [test-adapters.md](test-adapters.md)) before introducing custom behaviour + `Mox` boilerplate.

| Mock | Don't Mock |
|------|------------|
| HTTP clients | Contexts |
| External APIs | Schemas |
| Email delivery | GenServers |
| Payment processors | Internal modules |
| Time/randomness | PubSub |

## Setting Up Mox (Non-`Req` Boundaries)

### Define Behaviors

```elixir
# lib/my_app/http_client.ex
defmodule MyApp.HTTPClient do
  @callback get(String.t()) :: {:ok, map()} | {:error, term()}
  @callback post(String.t(), map()) :: {:ok, map()} | {:error, term()}
end

# lib/my_app/http_client/req_impl.ex
defmodule MyApp.HTTPClient.ReqImpl do
  @behaviour MyApp.HTTPClient

  @impl true
  def get(url), do: # real Req/Finch implementation

  @impl true
  def post(url, body), do: # real Req/Finch implementation
end
```

### Configure Mock

```elixir
# test/support/mocks.ex
Mox.defmock(MyApp.HTTPClientMock, for: MyApp.HTTPClient)

# config/test.exs
config :my_app, http_client: MyApp.HTTPClientMock

# config/prod.exs
config :my_app, http_client: MyApp.HTTPClient.ReqImpl
```

### Inject Dependency

```elixir
defmodule MyApp.ExternalService do
  def fetch_data(id) do
    http_client().get("/api/data/#{id}")
  end

  defp http_client do
    Application.get_env(:my_app, :http_client, MyApp.HTTPClient.ReqImpl)
  end
end
```

## Writing Tests with Mox

### Basic Expectation

```elixir
defmodule MyApp.ExternalServiceTest do
  use ExUnit.Case, async: true

  import Mox

  setup :set_mox_from_context
  setup :verify_on_exit!

  test "fetches data successfully" do
    expect(MyApp.HTTPClientMock, :get, fn "/api/data/123" ->
      {:ok, %{"name" => "Test"}}
    end)

    assert {:ok, %{"name" => "Test"}} = ExternalService.fetch_data(123)
  end
end
```

### Multiple Calls

```elixir
test "retries on failure" do
  MyApp.HTTPClientMock
  |> expect(:get, fn _ -> {:error, :timeout} end)
  |> expect(:get, fn _ -> {:ok, %{}} end)

  assert {:ok, _} = ExternalService.fetch_with_retry(123)
end
```

### Stub for Default Behavior

```elixir
setup do
  stub(MyApp.HTTPClientMock, :get, fn _ -> {:ok, %{}} end)
  :ok
end
```

### Async Allowance & `$callers` (Avoid `Mox.allow` Races)

`Task.async/1` and `Task.Supervisor.async_nolink/2` automatically propagate `$callers`, so `Mox` (and `Req.Test`) allow them without calling `Mox.allow/3`.

Calling `Mox.allow/3` **after** spawning a process that immediately calls the mock is a **race condition** (`Mox.UnexpectedCallError` if the child runs before `allow` executes). For existing long-lived or `GenServer` processes, pass the pid or call `Mox.allow/3` **before** triggering the operation:

```elixir
# GOOD - Task.async automatically inherits $callers (no manual allow needed)
test "task uses mock via $callers" do
  expect(MyApp.HTTPClientMock, :get, fn _ -> {:ok, %{}} end)

  task = Task.async(fn -> ExternalService.fetch_data(123) end)
  assert {:ok, %{}} = Task.await(task)
end

# GOOD - for a pre-started GenServer/worker, call Mox.allow BEFORE triggering the request
test "existing worker uses mock without race" do
  worker = start_supervised!(MyApp.Worker)

  expect(MyApp.HTTPClientMock, :get, fn _ -> {:ok, %{}} end)
  Mox.allow(MyApp.HTTPClientMock, self(), worker)

  assert {:ok, %{}} = MyApp.Worker.fetch(worker, 123)
end
```

## Anti-Patterns

### DON'T Mock Internal Modules

```elixir
# BAD - mocking your own context
defmock(MyApp.AccountsMock, for: MyApp.Accounts)

test "controller creates user" do
  expect(MyApp.AccountsMock, :create_user, fn _ -> {:ok, %User{}} end)
  # This tests nothing meaningful!
end

# GOOD - test the real context
test "controller creates user", %{conn: conn} do
  conn = post(conn, ~p"/users", %{user: valid_attrs()})
  assert %{"id" => _} = json_response(conn, 201)
  assert Repo.get_by(User, email: "test@example.com")
end
```

### DON'T Mock Database

```elixir
# BAD
defmock(MyApp.RepoMock, for: Ecto.Repo)

# GOOD - use Ecto.Adapters.SQL.Sandbox
use MyApp.DataCase, async: true
```

## Review Questions

1. Are only external boundaries being mocked?
2. Are behaviors defined for mockable interfaces (or `Req.Test` used for `Req`)?
3. Is `verify_on_exit!` used in setup, and is `Mox.allow/3` called before work starts (no spawn race)?
4. Are internal modules tested with real implementations?
