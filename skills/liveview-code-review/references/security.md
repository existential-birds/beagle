# LiveView Security

## Event Authorization

### Every Event Must Authorize

```elixir
# BAD - trusts phx-value blindly
def handle_event("delete", %{"id" => id}, socket) do
  Post.delete!(id)  # Anyone can delete any post!
  {:noreply, socket}
end

# GOOD - verify ownership
def handle_event("delete", %{"id" => id}, socket) do
  post = Posts.get_post!(id)

  if authorized?(socket.assigns.current_user, :delete, post) do
    Posts.delete_post!(post)
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

### Use Session for Sensitive State

```elixir
# In mount, fetch from session
def mount(_params, session, socket) do
  user_id = session["user_id"]
  user = Accounts.get_user!(user_id)

  {:ok, assign(socket, current_user: %{id: user.id, name: user.name})}
end
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

### Use Changesets

```elixir
def handle_event("save", %{"post" => params}, socket) do
  changeset = Post.changeset(%Post{}, params)

  if changeset.valid? do
    # Proceed
  else
    {:noreply, assign(socket, changeset: changeset)}
  end
end
```

## CSRF Protection

LiveView has built-in CSRF protection via the socket token. Ensure:

```elixir
# In app.js
let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken}  # Required!
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

### Validate in consume_uploaded_entries

```elixir
def handle_event("save", _, socket) do
  uploaded_files =
    consume_uploaded_entries(socket, :avatar, fn %{path: path}, entry ->
      # Validate actual file content, not just extension
      case ExImageInfo.info(File.read!(path)) do
        {"image/jpeg", _, _} -> {:ok, save_file(path)}
        {"image/png", _, _} -> {:ok, save_file(path)}
        _ -> {:error, :invalid_file_type}
      end
    end)
end
```

## Review Questions

1. Does every handle_event validate authorization?
2. Is phx-value data treated as untrusted?
3. Are sensitive fields excluded from assigns?
4. Are file uploads validated by content, not just extension?
