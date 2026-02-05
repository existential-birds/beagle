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

# GOOD - defer with assign_async
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
  page = String.to_integer(page)
  {:noreply, assign(socket, page: page, items: load_page(page))}
end

def handle_params(_params, _uri, socket) do
  {:noreply, assign(socket, page: 1, items: load_page(1))}
end
```

### Live Navigation

```elixir
# Triggers handle_params, not full remount
<.link patch={~p"/items?page=2"}>Page 2</.link>

# Full remount (different LiveView)
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

### Form Events

```elixir
def handle_event("validate", %{"user" => params}, socket) do
  changeset =
    socket.assigns.user
    |> User.changeset(params)
    |> Map.put(:action, :validate)

  {:noreply, assign(socket, changeset: changeset)}
end

def handle_event("save", %{"user" => params}, socket) do
  case Accounts.update_user(socket.assigns.user, params) do
    {:ok, user} ->
      {:noreply,
       socket
       |> put_flash(:info, "Saved!")
       |> push_navigate(to: ~p"/users/#{user}")}

    {:error, changeset} ->
      {:noreply, assign(socket, changeset: changeset)}
  end
end
```

## handle_async

### With assign_async

```elixir
def mount(_params, _session, socket) do
  {:ok,
   socket
   |> assign_async(:user, fn -> {:ok, %{user: load_user()}} end)}
end

# In template - handle all states
<.async_result :let={user} assign={@user}>
  <:loading>Loading user...</:loading>
  <:failed :let={reason}>Error: <%= inspect(reason) %></:failed>
  <%= user.name %>
</.async_result>
```

### With start_async

```elixir
def handle_event("refresh", _, socket) do
  {:noreply, start_async(socket, :refresh, fn -> fetch_data() end)}
end

def handle_async(:refresh, {:ok, data}, socket) do
  {:noreply, assign(socket, data: data)}
end

def handle_async(:refresh, {:exit, reason}, socket) do
  {:noreply, put_flash(socket, :error, "Refresh failed")}
end
```

## Review Questions

1. Are PubSub subscriptions wrapped in connected?(socket)?
2. Is handle_params used for URL-based state changes?
3. Do async operations handle both success and failure?
4. Is expensive loading deferred with assign_async?
