# Assigns and Streams

## When to Use Each

| Use Case | Solution |
|----------|----------|
| Small list (< 100 items) | assigns |
| Large list (100+ items) | streams |
| Paginated/infinite scroll | streams |
| Data not needed after render | temporary_assigns |
| Async loading with states | AsyncResult |

## Streams

### Basic Usage

```elixir
def mount(_params, _session, socket) do
  {:ok, stream(socket, :posts, Posts.list_posts())}
end

def handle_event("delete", %{"id" => id}, socket) do
  post = Posts.get_post!(id)
  Posts.delete_post!(post)
  {:noreply, stream_delete(socket, :posts, post)}
end
```

### In Templates

```heex
<div id="posts" phx-update="stream">
  <div :for={{dom_id, post} <- @streams.posts} id={dom_id}>
    <%= post.title %>
    <button phx-click="delete" phx-value-id={post.id}>Delete</button>
  </div>
</div>
```

### Stream Operations

```elixir
# Insert at end (default)
stream_insert(socket, :posts, new_post)

# Insert at beginning
stream_insert(socket, :posts, new_post, at: 0)

# Delete
stream_delete(socket, :posts, post)

# Delete by DOM ID
stream_delete_by_dom_id(socket, :posts, "posts-123")

# Reset entire stream
stream(socket, :posts, new_list, reset: true)
```

## AsyncResult

### assign_async

```elixir
def mount(_params, _session, socket) do
  {:ok,
   socket
   |> assign_async(:user, fn ->
     {:ok, %{user: Accounts.get_user!(1)}}
   end)
   |> assign_async([:posts, :comments], fn ->
     {:ok, %{posts: Posts.list(), comments: Comments.list()}}
   end)}
end
```

### Template Handling

```heex
<%# Using async_result component %>
<.async_result :let={user} assign={@user}>
  <:loading>
    <div class="animate-pulse">Loading...</div>
  </:loading>
  <:failed :let={{:error, reason}}>
    <div class="text-red-500">Failed: <%= reason %></div>
  </:failed>
  <div><%= user.name %></div>
</.async_result>

<%# Manual pattern matching %>
<%= case @user do %>
  <% %AsyncResult{ok?: true, result: user} -> %>
    <%= user.name %>
  <% %AsyncResult{loading: true} -> %>
    Loading...
  <% %AsyncResult{failed: reason} -> %>
    Error: <%= inspect(reason) %>
<% end %>
```

## Temporary Assigns

### For Large Rendered Data

```elixir
def mount(_params, _session, socket) do
  {:ok,
   socket
   |> assign(:messages, load_messages())
   |> assign(:form, to_form(%{})),
   temporary_assigns: [messages: []]}
end
```

**Important**: Temporary assigns are cleared after render. Only use for data that doesn't need to persist in socket state.

## Common Mistakes

### Assigns for Large Lists

```elixir
# BAD - 10k items in assigns
def mount(_, _, socket) do
  {:ok, assign(socket, items: Repo.all(Item))}  # All 10k in memory!
end

# GOOD - stream with pagination
def mount(_, _, socket) do
  {:ok,
   socket
   |> assign(:page, 1)
   |> stream(:items, load_page(1))}
end
```

### Not Handling AsyncResult States

```elixir
# BAD - assumes result exists
<%= @user.result.name %>

# GOOD - handle all states
<%= if @user.ok?, do: @user.result.name, else: "Loading..." %>
```

## Review Questions

1. Are streams used for large or paginated collections?
2. Do AsyncResult templates handle loading and error states?
3. Are temporary_assigns used appropriately (not for needed state)?
4. Is stream DOM properly configured (id, phx-update)?
