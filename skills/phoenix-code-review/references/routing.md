# Phoenix Routing

## Verified Routes

### Use ~p Sigil

```elixir
# GOOD - verified at compile time
~p"/users/#{user.id}"
~p"/users/#{user}/edit"

# BAD - string interpolation (no compile-time check)
"/users/#{user.id}"
"/users/#{user.id}/edit"
```

### In Templates

```heex
<%# GOOD %>
<.link navigate={~p"/users/#{@user}"}>Profile</.link>

<%# BAD %>
<.link navigate={"/users/#{@user.id}"}>Profile</.link>
```

## Pipelines

### Group Related Plugs

```elixir
pipeline :browser do
  plug :accepts, ["html"]
  plug :fetch_session
  plug :fetch_live_flash
  plug :put_root_layout, html: {MyAppWeb.Layouts, :root}
  plug :protect_from_forgery
  plug :put_secure_browser_headers
end

pipeline :api do
  plug :accepts, ["json"]
end

pipeline :authenticated do
  plug MyAppWeb.Plugs.RequireAuth
  plug MyAppWeb.Plugs.LoadCurrentUser
end
```

### Compose Pipelines

```elixir
scope "/", MyAppWeb do
  pipe_through [:browser, :authenticated]

  resources "/settings", SettingsController, only: [:edit, :update]
end

scope "/admin", MyAppWeb.Admin do
  pipe_through [:browser, :authenticated, :require_admin]

  resources "/users", UserController
end
```

## Resources

### Limit Actions

```elixir
# GOOD - only needed actions
resources "/users", UserController, only: [:index, :show, :create]
resources "/sessions", SessionController, only: [:new, :create, :delete]

# BAD - all actions when not needed
resources "/users", UserController  # Generates 7 routes
```

### Nested Resources

```elixir
# GOOD - shallow nesting
resources "/posts", PostController do
  resources "/comments", CommentController, only: [:create]
end

resources "/comments", CommentController, only: [:show, :update, :delete]

# BAD - deep nesting
resources "/users", UserController do
  resources "/posts", PostController do
    resources "/comments", CommentController  # Too deep!
  end
end
```

## Scopes

```elixir
# API versioning
scope "/api", MyAppWeb.API do
  scope "/v1", V1 do
    pipe_through :api
    resources "/users", UserController
  end

  scope "/v2", V2 do
    pipe_through [:api, :v2_transforms]
    resources "/users", UserController
  end
end
```

## Review Questions

1. Are verified routes (~p) used instead of string paths?
2. Are pipelines composed for authentication/authorization?
3. Do resources specify only needed actions?
4. Is nesting kept shallow (max 1 level)?
