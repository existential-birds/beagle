# Integration Tests

## What to Mock vs Real

### Mock at External Boundaries Only

| Layer | Integration Test |
|-------|-----------------|
| HTTP endpoints (`Req`) | `Req.Test` (`stub/2`, `expect/3`, `json/2`) |
| HTTP endpoints (other clients) | `Bypass` or `Mox` behaviour |
| Email delivery | `Swoosh.Adapters.Test` |
| Payment processing | Mock at boundary |
| Database | Real (Ecto Sandbox) |
| Contexts | Real |
| GenServers | Real |
| PubSub | Real |

### Example Integration Test (`Req.Test` + `Swoosh.Adapters.Test`)

Prefer `Req.Test` for `Req`-based HTTP clients — it uses `nimble_ownership` so tests run cleanly with `async: true` without binding TCP ports or mutating `Application.put_env/3`:

```elixir
defmodule MyAppWeb.RegistrationFlowTest do
  use MyAppWeb.ConnCase, async: true
  use Swoosh.TestAssertions

  test "full registration flow", %{conn: conn} do
    # Stub/expect only the external HTTP boundary via Req.Test
    Req.Test.expect(MyApp.VerificationClient, fn conn ->
      Req.Test.json(conn, %{"valid" => true})
    end)

    # Test real controller -> context -> repo flow
    conn = post(conn, ~p"/register", %{
      user: %{email: "test@example.com", password: "password123"}
    })

    assert redirected_to(conn) == ~p"/welcome"

    # Verify real database state
    assert user = Repo.get_by(User, email: "test@example.com")
    assert user.confirmed_at == nil

    # Verify real email was captured by Swoosh.Adapters.Test
    assert_email_sent(to: "test@example.com", subject: "Confirm your account")
  end
end
```

*(For non-`Req` clients such as `Finch` or legacy `Hackney`, use `Bypass.open()` with `async: false` if configuring URL via `Application.put_env/3`, or pass the base URL as an explicit option.)*

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
# Async - each test gets its own sandbox owner transaction
defmodule MyApp.FastTest do
  use MyApp.DataCase, async: true
end

# Non-async - start_owner!(Repo, shared: not tags[:async]) shares owner with spawned named processes
defmodule MyApp.SlowTest do
  use MyApp.DataCase, async: false
end
```

### Allowing Processes

```elixir
test "spawned process accesses database" do
  # Allow a specific spawned process to use the test's database connection
  Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), some_pid)

  # Or set shared mode explicitly with {:shared, pid} (NOT bare :shared; requires async: false)
  Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
end
```

## Test Data

### Fixtures (Phoenix Default) vs Legacy Factories

Phoenix projects default to plain fixture functions under `test/support/fixtures/`. Older codebases may use `ExMachina.Ecto` (legacy/unmaintained):

```elixir
# Modern Phoenix default: test/support/fixtures/accounts_fixtures.ex
defmodule MyApp.AccountsFixtures do
  def unique_user_email, do: "user#{System.unique_integer()}@example.com"

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        email: unique_user_email(),
        password: "valid_password_123"
      })
      |> MyApp.Accounts.register_user()

    user
  end
end

# Legacy (do not recommend for new code): ExMachina.Ecto
defmodule MyApp.Factory do
  use ExMachina.Ecto, repo: MyApp.Repo
  # ...
end
```

## LiveView Integration Tests

### Testing Async Assigns

```elixir
defmodule MyAppWeb.DashboardLiveTest do
  use MyAppWeb.ConnCase, async: true
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
2. Is Ecto Sandbox configured via `start_owner!(Repo, shared: not tags[:async])` or `{:shared, self()}` (never bare `:shared`)?
3. Are async tests truly isolated (preferring `Req.Test` over `Application.put_env` + `Bypass`)?
4. Is test data created via context-backed fixtures (`test/support/fixtures/`)?
