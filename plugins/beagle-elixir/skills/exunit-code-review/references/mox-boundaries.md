# Mox Boundaries

## Core Principle

Mock at **external boundaries**, not internal code.

| Mock | Don't Mock |
|------|------------|
| HTTP clients | Contexts |
| External APIs | Schemas |
| Email delivery | GenServers |
| Payment processors | Internal modules |
| Time/randomness | PubSub |

## Setting Up Mox

### Define Behaviors

```elixir
# lib/my_app/http_client.ex
defmodule MyApp.HTTPClient do
  @callback get(String.t()) :: {:ok, map()} | {:error, term()}
  @callback post(String.t(), map()) :: {:ok, map()} | {:error, term()}
end

# lib/my_app/http_client/hackney.ex
defmodule MyApp.HTTPClient.Hackney do
  @behaviour MyApp.HTTPClient

  @impl true
  def get(url), do: # real implementation

  @impl true
  def post(url, body), do: # real implementation
end
```

### Configure Mock

```elixir
# test/support/mocks.ex
Mox.defmock(MyApp.HTTPClientMock, for: MyApp.HTTPClient)

# config/test.exs
config :my_app, http_client: MyApp.HTTPClientMock

# config/prod.exs
config :my_app, http_client: MyApp.HTTPClient.Hackney
```

### Inject Dependency

```elixir
defmodule MyApp.ExternalService do
  @http_client Application.compile_env(:my_app, :http_client)

  def fetch_data(id) do
    @http_client.get("/api/data/#{id}")
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

### Allow for Async

```elixir
test "async process uses mock" do
  parent = self()
  ref = make_ref()

  expect(MyApp.HTTPClientMock, :get, fn _ ->
    send(parent, {ref, :called})
    {:ok, %{}}
  end)

  # Allow the spawned process to use expectations set by parent
  Task.async(fn ->
    Mox.allow(MyApp.HTTPClientMock, parent, self())
    ExternalService.fetch_data(123)
  end)
  |> Task.await()

  assert_receive {^ref, :called}
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
test "controller creates user" do
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
use MyApp.DataCase
```

## Review Questions

1. Are only external boundaries being mocked?
2. Are behaviors defined for mockable interfaces?
3. Is verify_on_exit! used in setup?
4. Are internal modules tested with real implementations?
