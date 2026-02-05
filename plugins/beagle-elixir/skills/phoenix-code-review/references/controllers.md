# Phoenix Controllers

## Action Structure

### Keep Controllers Thin

```elixir
# GOOD - delegates to context
defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller

  alias MyApp.Accounts

  def create(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        conn
        |> put_status(:created)
        |> render(:show, user: user)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, changeset: changeset)
    end
  end
end

# BAD - business logic in controller
defmodule MyAppWeb.UserController do
  def create(conn, %{"user" => params}) do
    changeset = User.changeset(%User{}, params)

    if changeset.valid? do
      # Validation logic here...
      # Email verification logic here...
      # Password hashing here...
    end
  end
end
```

### Action Fallback

```elixir
defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller

  action_fallback MyAppWeb.FallbackController

  def show(conn, %{"id" => id}) do
    with {:ok, user} <- Accounts.get_user(id) do
      render(conn, :show, user: user)
    end
  end
end

defmodule MyAppWeb.FallbackController do
  use MyAppWeb, :controller

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(MyAppWeb.ErrorJSON)
    |> render(:"404")
  end

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(MyAppWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end
end
```

## Parameter Handling

### Pattern Match in Function Head

```elixir
# GOOD - pattern match expected params
def update(conn, %{"id" => id, "user" => user_params}) do
  # ...
end

# GOOD - handle missing params explicitly
def update(conn, %{"id" => id}) do
  conn
  |> put_status(:bad_request)
  |> json(%{error: "Missing user params"})
end
```

### Strong Parameters via Changesets

```elixir
# Changeset controls which fields are accepted
def registration_changeset(user, attrs) do
  user
  |> cast(attrs, [:email, :password, :name])  # Only these fields
  |> validate_required([:email, :password])
end
```

## HTTP Status Codes

| Action | Success | Common Errors |
|--------|---------|---------------|
| create | 201 Created | 422 Unprocessable |
| show | 200 OK | 404 Not Found |
| update | 200 OK | 404, 422 |
| delete | 204 No Content | 404 |
| index | 200 OK | - |

## Review Questions

1. Is business logic delegated to contexts?
2. Do actions use appropriate HTTP status codes?
3. Is action_fallback used for consistent error handling?
4. Are parameters validated via changesets?
