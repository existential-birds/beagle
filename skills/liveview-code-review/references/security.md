# LiveView Security

## WebSocket Authentication (`live_session` + `on_mount`)

Live navigation (`<.link navigate={...}>`, `push_navigate/2`) transitions between LiveViews over the existing WebSocket **without re-running HTTP Router Plugs**. Protected LiveViews MUST be grouped inside a `live_session` with an `on_mount` hook that authenticates from the session token using non-bang lookups:

```elixir
# In router.ex
live_session :require_authenticated_user,
  on_mount: [{MyAppWeb.UserAuth, :ensure_authenticated}] do
  live "/posts/new", PostLive.New
  live "/settings", UserSettingsLive
end

# In user_auth.ex
def on_mount(:ensure_authenticated, _params, %{"user_token" => token}, socket) do
  socket =
    Phoenix.Component.assign_new(socket, :current_scope, fn ->
      user = Accounts.get_user_by_session_token(token)
      Scope.for_user(user)
    end)

  if socket.assigns.current_scope && socket.assigns.current_scope.user do
    {:cont, socket}
  else
    {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/users/log_in")}
  end
end

def on_mount(:ensure_authenticated, _params, _session, socket) do
  {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/users/log_in")}
end
```

> Never call `Accounts.get_user!(session["user_id"])` in `mount/3` or `on_mount/4` — a nil or deleted user raises `Ecto.NoResultsError` and crashes the LiveView.

## Event Authorization

### Every Event Must Authorize

```elixir
# BAD - trusts phx-value blindly
def handle_event("delete", %{"id" => id}, socket) do
  Posts.delete_post!(id)  # Anyone can delete any post!
  {:noreply, socket}
end

# GOOD - verify ownership or pass current_scope to context
def handle_event("delete", %{"id" => id}, socket) do
  post = Posts.get_post!(id)

  if authorized?(socket.assigns.current_user, :delete, post) do
    {:ok, _} = Posts.delete_post(post)
    {:noreply, stream_delete(socket, :posts, post)}
  else
    {:noreply, put_flash(socket, :error, "Not authorized")}
  end
end

defp authorized?(user, :delete, post) do
  user.id == post.user_id || user.admin
end
```

### Don't Trust phx-value

```heex
<%# This is user-modifiable in browser DevTools! %>
<button phx-click="edit" phx-value-id={@post.id} phx-value-role="admin">
  Edit
</button>
```

Always validate on server:

```elixir
def handle_event("edit", %{"id" => id, "role" => _role}, socket) do
  # Ignore client-provided role, check actual user
  if socket.assigns.current_user.admin do
    # Allow edit
  end
end
```

## Sensitive Data in Assigns

### What Goes in Assigns is Visible

LiveView assigns can be inspected:
- In browser DevTools (morphdom payloads)
- In crash reports
- In logs

```elixir
# BAD - sensitive data in assigns
socket
|> assign(:user, %{
  email: "user@example.com",
  password_hash: "...",     # Sensitive!
  api_token: "secret123"    # Sensitive!
})

# GOOD - only needed fields
socket
|> assign(:user, %{
  id: user.id,
  name: user.name,
  email: user.email
})
```

## Input Validation

### Validate All User Input

```elixir
def handle_event("update", %{"quantity" => qty}, socket) do
  # BAD - no validation
  {:noreply, assign(socket, quantity: String.to_integer(qty))}
end

def handle_event("update", %{"quantity" => qty}, socket) do
  # GOOD - validate
  case Integer.parse(qty) do
    {n, ""} when n > 0 and n <= 100 ->
      {:noreply, assign(socket, quantity: n)}

    _ ->
      {:noreply, put_flash(socket, :error, "Invalid quantity")}
  end
end
```

### Use Changesets with `to_form/2`

```elixir
def handle_event("save", %{"post" => params}, socket) do
  case Posts.create_post(socket.assigns.current_scope, params) do
    {:ok, post} ->
      {:noreply, push_navigate(socket, to: ~p"/posts/#{post}")}

    {:error, %Ecto.Changeset{} = changeset} ->
      {:noreply, assign(socket, form: to_form(changeset))}
  end
end
```

## CSRF Protection

LiveView has built-in CSRF protection via the socket token. Ensure:

```javascript
// In app.js
let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken}  // Required!
})
```

## File Uploads

### Validate File Types

```elixir
allow_upload(socket, :avatar,
  accept: ~w(.jpg .jpeg .png),  # Whitelist extensions
  max_file_size: 5_000_000,     # 5MB limit
  max_entries: 1
)
```

### Validate Magic Bytes in `consume_uploaded_entries`

Do not trust `entry.client_type` or file extensions, and avoid reading an entire upload into memory just to inspect its header — read only the magic-byte prefix:

```elixir
def handle_event("save", _, socket) do
  uploaded_files =
    consume_uploaded_entries(socket, :avatar, fn %{path: path}, _entry ->
      header = File.open!(path, [:read, :binary], &IO.binread(&1, 16))

      case sniff_image_type(header) do
        {:ok, _ext} -> {:ok, save_file(path)}
        :error -> {:postpone, :invalid_file_type}
      end
    end)

  {:noreply, assign(socket, uploaded_files: uploaded_files)}
end

defp sniff_image_type(<<0xFF, 0xD8, 0xFF, _::binary>>), do: {:ok, :jpeg}
defp sniff_image_type(<<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, _::binary>>), do: {:ok, :png}
defp sniff_image_type(_), do: :error
```

## Review Questions

1. Are authenticated LiveViews protected by `live_session` + `on_mount` hooks (not just router plugs)?
2. Does every `handle_event` validate authorization and treat `phx-value-*` as untrusted?
3. Are sensitive fields excluded from assigns?
4. Are file uploads validated by magic-byte content rather than client extension/MIME type?
