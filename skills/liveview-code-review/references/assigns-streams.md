# Assigns and Streams

## When to Use Each

| Use Case | Solution |
|----------|----------|
| Small list (< 100 items) | `assigns` |
| Large list (100+ items) | `stream/4` |
| Paginated / infinite scroll / bounded feed | `stream/4` (`:reset`, `:limit`) |
| Async stream loading (LiveView 1.1+) | `stream_async/4` |
| Async loading with states | `assign_async/3` + `AsyncResult` |
| Single non-collection render-only assign | `temporary_assigns` (legacy; streams supersede for collections) |

## Streams

### Basic Usage

```elixir
def mount(_params, _session, socket) do
  {:ok, stream(socket, :posts, Posts.list_posts())}
end

def handle_event("delete", %{"id" => id}, socket) do
  post = Posts.get_post!(id)
  {:ok, _} = Posts.delete_post(post)
  {:noreply, stream_delete(socket, :posts, post)}
end
```

### In Templates

```heex
<div id="posts" phx-update="stream">
  <div :for={{dom_id, post} <- @streams.posts} id={dom_id}>
    {post.title}
    <button phx-click="delete" phx-value-id={post.id}>Delete</button>
  </div>
</div>
```

### Stream Operations

```elixir
# Insert at end (default)
stream_insert(socket, :posts, new_post)

# Insert at beginning and prune to keep max 50 items in DOM
stream_insert(socket, :posts, new_post, at: 0, limit: 50)

# Delete
stream_delete(socket, :posts, post)

# Delete by DOM ID
stream_delete_by_dom_id(socket, :posts, "posts-123")

# Reset entire stream
stream(socket, :posts, new_list, reset: true)

# Async stream loading (LiveView 1.1+)
stream_async(socket, :posts, fn -> {:ok, Posts.list_posts()} end)
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

The `:failed` slot of `<.async_result>` receives the failure reason — either `{:error, reason}` (from returning `{:error, reason}`) or `{:exit, reason}` (if the async task crashes). Do NOT pattern-match solely on `{:error, reason}` in `:let`, and always format with `inspect/1` or a safe formatter so tuples don't raise `Protocol.UndefinedError`:

```heex
<%# Using async_result component %>
<.async_result :let={user} assign={@user}>
  <:loading>
    <div class="animate-pulse">Loading...</div>
  </:loading>
  <:failed :let={failure}>
    <div class="text-red-500">Failed: {format_async_error(failure)}</div>
  </:failed>
  <div>{user.name}</div>
</.async_result>

<%# Manual pattern matching %>
<%= case @user do %>
  <% %AsyncResult{ok?: true, result: user} -> %>
    {user.name}
  <% %AsyncResult{loading: true} -> %>
    Loading...
  <% %AsyncResult{failed: failure} -> %>
    Error: {inspect(failure)}
<% end %>
```

## Temporary Assigns (Legacy for Collections)

In LiveView 1.0+, `phx-update="append"` and `phx-update="prepend"` were removed and **Streams** (`stream/4`, `stream_async/4`) superseded `temporary_assigns` for managing collections. Reserve `temporary_assigns` only for rare non-collection values that do not need to persist in socket state after render (e.g. a one-off large binary blob):

```elixir
# Prefer stream/4 for collections; temporary_assigns only for single non-collection values
def mount(_params, _session, socket) do
  {:ok,
   socket
   |> assign(:initial_payload, load_once())
   |> assign(:form, to_form(%{})),
   temporary_assigns: [initial_payload: nil]}
end
```

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

### Not Handling All AsyncResult States

```elixir
# BAD - assumes result exists
{@user.result.name}

# BAD - renders "Loading..." forever when @user.failed is truthy!
<%= if @user.ok?, do: @user.result.name, else: "Loading..." %>

# GOOD - handle ok?, loading, and failed states explicitly
<%= cond do %>
  <% @user.ok? -> %>
    {@user.result.name}
  <% @user.failed -> %>
    Failed to load user
  <% true -> %>
    Loading...
<% end %>
```

## Review Questions

1. Are streams (`stream/4` / `stream_async/4`) used for large or paginated collections instead of assigns or legacy `temporary_assigns`?
2. Do `AsyncResult` templates handle loading, failed (`{:error, _}` and `{:exit, _}`), and ok states without falling through to `"Loading..."` on error?
3. Is stream DOM properly configured (`id` and `phx-update="stream"`, with `id={dom_id}` on children)?
