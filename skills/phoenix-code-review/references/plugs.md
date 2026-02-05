# Phoenix Plugs

## Custom Plugs

### Module Plug Structure

```elixir
defmodule MyAppWeb.Plugs.RequireAuth do
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_status(:unauthorized)
      |> put_view(MyAppWeb.ErrorJSON)
      |> render(:"401")
      |> halt()  # IMPORTANT: halt after sending response
    end
  end
end
```

### Function Plug

```elixir
defmodule MyAppWeb.UserController do
  plug :load_user when action in [:show, :edit, :update]

  defp load_user(conn, _opts) do
    case Accounts.get_user(conn.params["id"]) do
      {:ok, user} -> assign(conn, :user, user)
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> render(:not_found)
        |> halt()
    end
  end
end
```

## Authentication Pattern

```elixir
defmodule MyAppWeb.Plugs.LoadCurrentUser do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    user_id = get_session(conn, :user_id)

    cond do
      conn.assigns[:current_user] ->
        conn  # Already loaded

      user_id && user = Accounts.get_user!(user_id) ->
        assign(conn, :current_user, user)

      true ->
        assign(conn, :current_user, nil)
    end
  end
end
```

## Authorization Pattern

```elixir
defmodule MyAppWeb.Plugs.RequireAdmin do
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    user = conn.assigns[:current_user]

    if user && user.admin do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> put_view(MyAppWeb.ErrorJSON)
      |> render(:"403")
      |> halt()
    end
  end
end
```

## Plug Composition

```elixir
# In router
pipeline :authenticated do
  plug MyAppWeb.Plugs.LoadCurrentUser
  plug MyAppWeb.Plugs.RequireAuth
end

pipeline :admin do
  plug MyAppWeb.Plugs.RequireAdmin
end

scope "/admin", MyAppWeb.Admin do
  pipe_through [:browser, :authenticated, :admin]
  # ...
end
```

## Common Mistakes

### Forgetting to Halt

```elixir
# BAD - continues to controller after sending response
def call(conn, _opts) do
  if unauthorized?(conn) do
    conn
    |> send_resp(401, "Unauthorized")
    # Missing halt()! Controller still runs
  else
    conn
  end
end

# GOOD
def call(conn, _opts) do
  if unauthorized?(conn) do
    conn
    |> send_resp(401, "Unauthorized")
    |> halt()
  else
    conn
  end
end
```

### Modifying Halted Conn

```elixir
# BAD - checking after halt
def call(conn, _opts) do
  conn = maybe_halt(conn)
  assign(conn, :data, load_data())  # Runs even if halted!
end

# GOOD - check halted status
def call(conn, _opts) do
  conn = maybe_halt(conn)

  if conn.halted do
    conn
  else
    assign(conn, :data, load_data())
  end
end
```

## Review Questions

1. Do plugs call halt() after sending a response?
2. Is authentication handled via plugs, not controller logic?
3. Are plugs composable and single-purpose?
4. Is halted status checked before further processing?
