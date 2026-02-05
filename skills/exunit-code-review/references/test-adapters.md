# Test Adapters

## Bypass for HTTP

### Setup

```elixir
# mix.exs
{:bypass, "~> 2.1", only: :test}
```

### Basic Usage

```elixir
defmodule MyApp.APIClientTest do
  use ExUnit.Case, async: true

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass}
  end

  test "fetches user data", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/users/123", fn conn ->
      Plug.Conn.resp(conn, 200, ~s({"id": 123, "name": "Test"}))
    end)

    assert {:ok, user} = APIClient.get_user("http://localhost:#{bypass.port}", 123)
    assert user.name == "Test"
  end

  test "handles server error", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/users/123", fn conn ->
      Plug.Conn.resp(conn, 500, "Internal Server Error")
    end)

    assert {:error, :server_error} = APIClient.get_user("http://localhost:#{bypass.port}", 123)
  end
end
```

### Verify Request Body

```elixir
test "sends correct payload", %{bypass: bypass} do
  Bypass.expect_once(bypass, "POST", "/webhooks", fn conn ->
    {:ok, body, conn} = Plug.Conn.read_body(conn)
    assert %{"event" => "user.created"} = Jason.decode!(body)
    Plug.Conn.resp(conn, 200, "OK")
  end)

  Webhooks.notify(:user_created, %{id: 1})
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

### Configuration

```elixir
# config/test.exs
config :my_app, Oban, testing: :inline  # Jobs run immediately
# OR
config :my_app, Oban, testing: :manual  # Control when jobs run
```

### Testing Job Enqueue

```elixir
defmodule MyApp.WorkerTest do
  use MyApp.DataCase
  use Oban.Testing, repo: MyApp.Repo

  test "enqueues email job" do
    Notifications.schedule_email(user_id: 123)

    assert_enqueued(worker: MyApp.Workers.EmailWorker, args: %{user_id: 123})
  end

  test "job processes correctly" do
    assert :ok = perform_job(MyApp.Workers.EmailWorker, %{user_id: 123})
  end
end
```

### Testing with :manual mode

```elixir
# config/test.exs
config :my_app, Oban, testing: :manual

test "job side effects" do
  # Enqueue job
  Notifications.schedule_email(user_id: 123)

  # Job not yet run
  refute_email_sent()

  # Manually drain the queue
  Oban.drain_queue(queue: :mailers)

  # Now email sent
  assert_email_sent(to: "test@example.com")
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

1. Is Bypass used for HTTP endpoint mocking?
2. Is Swoosh.TestAdapter configured for email tests?
3. Is Oban.Testing used for job assertions?
4. Are time-dependent tests properly controlled?
