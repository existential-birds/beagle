# LiveView Lifecycle

## Mount

### connected?/1 for Subscriptions

```elixir
def mount(_params, _session, socket) do
  # Only subscribe when actually connected (not during static render)
  if connected?(socket) do
    Phoenix.PubSub.subscribe(MyApp.PubSub, "updates")
  end

  {:ok, assign(socket, items: [])}
end
```

### Expensive Operations

```elixir
# BAD - blocks initial render
def mount(_params, _session, socket) do
  items = Repo.all(Item)  # Blocks!
  {:ok, assign(socket, items: items)}
end

# GOOD - defer with assign_async (or stream_async in LiveView 1.1+)
def mount(_params, _session, socket) do
  {:ok,
   socket
   |> assign(:page_title, "Items")
   |> assign_async(:items, fn -> {:ok, %{items: Repo.all(Item)}} end)}
end
```

## handle_params

### URL-Based State

```elixir
def handle_params(%{"page" => page}, _uri, socket) do
  page =
    case Integer.parse(page) do
      {n, ""} when n > 0 -> n
      _ -> 1
    end
  {:noreply, assign(socket, page: page, items: load_page(page))}
end

def handle_params(_params, _uri, socket) do
  {:noreply, assign(socket, page: 1, items: load_page(1))}
end
```

### Live Navigation

```heex
<%# Triggers handle_params, not full remount %>
<.link patch={~p"/items?page=2"}>Page 2</.link>

<%# Full remount (different LiveView) %>
<.link navigate={~p"/other"}>Other Page</.link>
```

## handle_event

### Pattern Match Events

```elixir
def handle_event("save", %{"form" => form_params}, socket) do
  # Handle save
end

def handle_event("delete", %{"id" => id}, socket) do
  # Handle delete
end

def handle_event("toggle", %{"value" => value}, socket) do
  # Handle toggle
end
```

### Form Events (`to_form/2`)

Always wrap Ecto changesets with `to_form/2` and render `<.form for={@form}>` — passing raw `@changeset` directly to `<.form>` is discouraged in LiveView 1.0+ because it hurts change tracking:

```elixir
def handle_event("validate", %{"user" => params}, socket) do
  changeset =
    socket.assigns.user
    |> User.changeset(params)
    |> Map.put(:action, :validate)

  {:noreply, assign(socket, form: to_form(changeset))}
end

def handle_event("save", %{"user" => params}, socket) do
  case Accounts.update_user(socket.assigns.user, params) do
    {:ok, user} ->
      {:noreply,
       socket
       |> put_flash(:info, "Saved!")
       |> push_navigate(to: ~p"/users/#{user}")}

    {:error, changeset} ->
      {:noreply, assign(socket, form: to_form(changeset))}
  end
end
```

## handle_async

### With assign_async

Handle both `{:error, reason}` and `{:exit, reason}` in `<:failed :let={failure}>` (avoid `:let={{:error, reason}}`, which raises `MatchError` if the async task crashes with `{:exit, reason}`):

```elixir
def mount(_params, _session, socket) do
  {:ok,
   socket
   |> assign_async(:user, fn -> {:ok, %{user: load_user()}} end)}
end
```

```heex
<.async_result :let={user} assign={@user}>
  <:loading>Loading user...</:loading>
  <:failed :let={failure}>Error: {inspect(failure)}</:failed>
  {user.name}
</.async_result>
```

### With start_async

```elixir
def handle_event("refresh", _, socket) do
  user_id = socket.assigns.current_user.id
  {:noreply, start_async(socket, :refresh, fn -> fetch_data(user_id) end)}
end

def handle_async(:refresh, {:ok, data}, socket) do
  {:noreply, assign(socket, data: data)}
end

def handle_async(:refresh, {:exit, reason}, socket) do
  {:noreply, put_flash(socket, :error, "Refresh failed: #{inspect(reason)}")}
end
```

## Review Questions

1. Are PubSub subscriptions wrapped in `connected?(socket)`?
2. Is `handle_params` used for URL-based state changes?
3. Do forms use `to_form(changeset)` + `<.form for={@form}>` instead of raw `@changeset`?
4. Do async operations handle `{:ok, ...}`, `{:error, ...}`, and `{:exit, ...}` safely?
