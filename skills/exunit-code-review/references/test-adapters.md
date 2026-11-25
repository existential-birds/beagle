# Test Adapters

## `Req.Test` for `Req` HTTP Clients (Recommended)

`Req.Test` (built into `Req`, backed by `nimble_ownership`) lets `async: true` tests stub and assert HTTP requests concurrently without opening TCP ports or mutating global `Application` env.

### Configuration

```elixir
# config/test.exs
config :my_app, req_options: [plug: {Req.Test, MyApp.APIClient}]

# lib/my_app/api_client.ex
defmodule MyApp.APIClient do
  def get_user(id) do
    Req.new(base_url: "https://api.example.com")
    |> Req.merge(Application.get_env(:my_app, :req_options, []))
    |> Req.get(url: "/users/#{id}")
  end
end
```

### Stubbing and Expectations

```elixir
defmodule MyApp.APIClientTest do
  use ExUnit.Case, async: true

  test "fetches user data" do
    Req.Test.stub(MyApp.APIClient, fn conn ->
      Req.Test.json(conn, %{"id" => 123, "name" => "Test"})
    end)

    assert {:ok, %{status: 200, body: %{"name" => "Test"}}} = APIClient.get_user(123)
  end

  test "enforces request count and inspects payload" do
    Req.Test.expect(MyApp.APIClient, 1, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/webhooks"
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert %{"event" => "user.created"} = JSON.decode!(body)
      Req.Test.json(conn, %{"ok" => true})
    end)

    assert {:ok, _} = Webhooks.notify(:user_created, %{id: 1})
  end
end
```

## Bypass for Non-`Req` HTTP Clients

Use `Bypass` when testing non-`Req` HTTP clients (e.g. `Finch`, `:httpc`, or third-party SDKs) that connect to an actual localhost URL:

```elixir
# mix.exs
{:bypass, "~> 2.1", only: :test}
```

```elixir
defmodule MyApp.LegacyClientTest do
  use ExUnit.Case, async: true

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass}
  end

  test "fetches user data", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/users/123", fn conn ->
      Plug.Conn.resp(conn, 200, ~s({"id": 123, "name": "Test"}))
    end)

    assert {:ok, user} = LegacyClient.get_user("http://localhost:#{bypass.port}", 123)
    assert user.name == "Test"
  end
end
```

## Swoosh for Email

### Configuration

```elixir
# config/test.exs
config :my_app, MyApp.Mailer, adapter: Swoosh.Adapters.Test
```

### Testing Emails

```elixir
defmodule MyApp.NotificationsTest do
  use ExUnit.Case, async: true
  use Swoosh.TestAssertions

  test "sends welcome email" do
    user = %{email: "test@example.com", name: "Test"}

    Notifications.send_welcome(user)

    assert_email_sent(
      to: "test@example.com",
      subject: "Welcome!"
    )
  end

  test "includes user name in body" do
    user = %{email: "test@example.com", name: "Alice"}

    Notifications.send_welcome(user)

    assert_email_sent(fn email ->
      assert email.html_body =~ "Hello, Alice"
    end)
  end
end
```

## Oban for Jobs

### Configuration (`config/test.exs`)

```elixir
# config/test.exs
config :my_app, Oban, testing: :inline  # Jobs run immediately
# OR
config :my_app, Oban, testing: :manual  # Control when jobs run
```

### Testing Job Enqueue & Execution

```elixir
defmodule MyApp.WorkerTest do
  use MyApp.DataCase, async: true
  use Oban.Testing, repo: MyApp.Repo

  test "enqueues email job" do
    Notifications.schedule_email(user_id: 123)

    assert_enqueued(worker: MyApp.Workers.EmailWorker, args: %{user_id: 123})
  end

  test "job processes correctly" do
    assert :ok = perform_job(MyApp.Workers.EmailWorker, %{user_id: 123})
  end

  test "draining manual queue runs side effects without failures" do
    Notifications.schedule_email(user_id: 123)
    refute_email_sent()

    assert %{success: 1, failure: 0} = Oban.drain_queue(queue: :mailers)
    assert_email_sent(to: "test@example.com")
  end
end
```

## DateTime Mocking

### Simple Approach

```elixir
# In code, accept optional time
def expires_at(duration, now \\ DateTime.utc_now()) do
  DateTime.add(now, duration, :second)
end

# In test
test "calculates expiry" do
  now = ~U[2024-01-01 12:00:00Z]
  assert Token.expires_at(3600, now) == ~U[2024-01-01 13:00:00Z]
end
```

### With Mox

```elixir
# Define behavior
defmodule MyApp.Clock do
  @callback utc_now() :: DateTime.t()
end

# Production implementation
defmodule MyApp.Clock.System do
  @behaviour MyApp.Clock
  def utc_now, do: DateTime.utc_now()
end

# Test mock
Mox.defmock(MyApp.ClockMock, for: MyApp.Clock)

# In test
expect(MyApp.ClockMock, :utc_now, fn -> ~U[2024-01-01 12:00:00Z] end)
```

## Review Questions

1. Is `Req.Test` used for `Req` clients (or `Bypass` for non-`Req` HTTP clients)?
2. Is `Swoosh.Adapters.Test` configured for email tests?
3. Is `Oban.Testing` used, and does `Oban.drain_queue` assert `%{success: _, failure: 0}`?
4. Are time-dependent tests properly controlled without `Process.sleep`?
