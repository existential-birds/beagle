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
        |> put_status(:unprocessable_content)
        |> render(:error, changeset: changeset)
    end
  end
end

# BAD - business logic in controller
defmodule MyAppWeb.UserController do
  def create(conn, %{"user" => params}) do
    changeset = User.registration_changeset(%User{}, params)

    if changeset.valid? do
      # Validation logic here...
      # Email verification logic here...
      # Password hashing here...
    end
  end
end
```

### Action Fallback

Use Phoenix 1.7+ format keyword syntax in `put_view/2` (`put_view(json: ...)` or `put_view(html: ...)`):

```elixir
defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller

  action_fallback MyAppWeb.FallbackController

  def show(conn, %{"id" => id}) do
    with {:ok, user} <- Accounts.fetch_user(id) do
      render(conn, :show, user: user)
    end
  end
end

defmodule MyAppWeb.FallbackController do
  use MyAppWeb, :controller

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: MyAppWeb.ErrorJSON)
    |> render(:"404")
  end

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_content)
    |> put_view(json: MyAppWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end
end
```

> Note: Plug 1.16+ and Phoenix 1.8+ map HTTP 422 to `:unprocessable_content` (per RFC 9110). `:unprocessable_entity` remains a valid legacy alias — do not flag `:unprocessable_entity` as an error in existing codebases unless project conventions standardize on `:unprocessable_content`.

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
def profile_changeset(user, attrs) do
  user
  |> cast(attrs, [:name, :bio])  # Only allowed fields; never :role or :admin
  |> validate_required([:name])
end
```

## HTTP Status Codes

| Action | Success | Common Errors |
|--------|---------|---------------|
| create | 201 Created (`:created`) | 422 (`:unprocessable_content` / legacy `:unprocessable_entity`) |
| show | 200 OK (`:ok`) | 404 Not Found (`:not_found`) |
| update | 200 OK (`:ok`) | 404, 422 |
| delete | 204 No Content (`:no_content`) | 404 |
| index | 200 OK (`:ok`) | - |

## Review Questions

1. Is business logic delegated to contexts?
2. Do actions use appropriate HTTP status codes?
3. Is `action_fallback` used with Phoenix 1.7+ `put_view(json: ...)` / `put_view(html: ...)`?
4. Are parameters filtered via explicit changeset `cast/3` allowlists?
