# Integration Tests

## What to Mock vs Real

### Mock at External Boundaries Only

| Layer | Integration Test |
|-------|-----------------|
| HTTP endpoints | Mock with Bypass |
| Email delivery | Swoosh.TestAdapter |
| Payment processing | Mock |
| Database | Real (sandbox) |
| Contexts | Real |
| GenServers | Real |
| PubSub | Real |

### Example Integration Test

```elixir
defmodule MyAppWeb.RegistrationFlowTest do
  use MyAppWeb.ConnCase
  use Swoosh.TestAssertions

  setup %{conn: conn} do
    bypass = Bypass.open()
    # Mock only external HTTP calls
    Application.put_env(:my_app, :verification_api_url, "http://localhost:#{bypass.port}")
    {:ok, conn: conn, bypass: bypass}
  end

  test "full registration flow", %{conn: conn, bypass: bypass} do
    # Mock external email verification API
    Bypass.expect_once(bypass, "POST", "/verify", fn conn ->
      Plug.Conn.resp(conn, 200, ~s({"valid": true}))
    end)

    # Test real controller -> context -> repo flow
    conn = post(conn, ~p"/register", %{
      user: %{email: "test@example.com", password: "password123"}
    })

    assert redirected_to(conn) == ~p"/welcome"

    # Verify real database state
    assert user = Repo.get_by(User, email: "test@example.com")
    assert user.confirmed_at == nil

    # Verify real email was "sent" via test adapter
    assert_email_sent(to: "test@example.com", subject: "Confirm your account")
  end
end
```

## Ecto Sandbox

### Configuration

```elixir
# test/support/data_case.ex
defmodule MyApp.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias MyApp.Repo
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import MyApp.DataCase
    end
  end

  setup tags do
    MyApp.DataCase.setup_sandbox(tags)
    :ok
  end

  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(MyApp.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end
end
```

### Async vs Shared Mode

```elixir
# Async - each test gets its own transaction
defmodule MyApp.FastTest do
  use MyApp.DataCase, async: true  # Isolated, can run parallel
end

# Shared - tests share database connection
defmodule MyApp.SlowTest do
  use MyApp.DataCase, async: false  # Sequential, shared state
end
```

### Allowing Processes

```elixir
test "async process accesses database" do
  # Allow spawned process to use test's database connection
  Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), some_pid)

  # Or use :shared mode
  Ecto.Adapters.SQL.Sandbox.mode(Repo, :shared)
end
```

## Test Data

### Fixtures vs Factories

```elixir
# Fixture - simple helper functions
defmodule MyApp.TestHelpers do
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        email: "test#{System.unique_integer()}@example.com",
        password: "password123"
      })
      |> Accounts.create_user()

    user
  end
end

# Factory - with ex_machina
defmodule MyApp.Factory do
  use ExMachina.Ecto, repo: MyApp.Repo

  def user_factory do
    %MyApp.Accounts.User{
      email: sequence(:email, &"user#{&1}@example.com"),
      password_hash: Bcrypt.hash_pwd_salt("password123")
    }
  end
end
```

## LiveView Integration Tests

### Testing Async Assigns

```elixir
defmodule MyAppWeb.DashboardLiveTest do
  use MyAppWeb.ConnCase
  import Phoenix.LiveViewTest

  test "loads data asynchronously", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/dashboard")

    # Initial render shows loading state
    assert html =~ "Loading..."

    # Wait for async to complete
    assert render_async(view) =~ "Dashboard Data"
  end
end
```

### Testing Events

```elixir
test "handles form submission", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/posts/new")

  view
  |> form("#post-form", post: %{title: "Test", body: "Content"})
  |> render_submit()

  assert_redirect(view, ~p"/posts")
  assert Repo.get_by(Post, title: "Test")
end
```

## Review Questions

1. Are only external boundaries mocked in integration tests?
2. Is Ecto sandbox properly configured?
3. Are async tests truly isolated?
4. Is test data created consistently (fixtures or factories)?
