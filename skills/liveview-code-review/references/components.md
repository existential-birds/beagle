# LiveView Components

## Function Components vs LiveComponents

### Prefer Function Components

```elixir
# GOOD - stateless, simple
defmodule MyAppWeb.Components do
  use Phoenix.Component

  attr :user, :map, required: true
  def user_card(assigns) do
    ~H"""
    <div class="card">
      <h3><%= @user.name %></h3>
      <p><%= @user.email %></p>
    </div>
    """
  end
end
```

### Use LiveComponent When Needed

Only use LiveComponent when you need:
- Component-local state
- Component-local event handling
- Lifecycle callbacks (mount, update)

```elixir
defmodule MyAppWeb.LiveComponents.EditableField do
  use MyAppWeb, :live_component

  def mount(socket) do
    {:ok, assign(socket, editing: false)}
  end

  def handle_event("toggle_edit", _, socket) do
    {:noreply, assign(socket, editing: !socket.assigns.editing)}
  end

  def render(assigns) do
    ~H"""
    <div phx-click="toggle_edit" phx-target={@myself}>
      <%= if @editing do %>
        <input value={@value} />
      <% else %>
        <%= @value %>
      <% end %>
    </div>
    """
  end
end
```

## Slots

### Basic Slots

```elixir
slot :inner_block, required: true

def card(assigns) do
  ~H"""
  <div class="card">
    <%= render_slot(@inner_block) %>
  </div>
  """
end

# Usage
<.card>
  <p>Card content</p>
</.card>
```

### Named Slots

```elixir
slot :header
slot :inner_block, required: true
slot :footer

def modal(assigns) do
  ~H"""
  <div class="modal">
    <header :if={@header != []}>
      <%= render_slot(@header) %>
    </header>
    <main>
      <%= render_slot(@inner_block) %>
    </main>
    <footer :if={@footer != []}>
      <%= render_slot(@footer) %>
    </footer>
  </div>
  """
end

# Usage
<.modal>
  <:header>Title</:header>
  Main content
  <:footer>
    <button>Close</button>
  </:footer>
</.modal>
```

### Slots with Arguments

```elixir
slot :col, doc: "Table columns" do
  attr :label, :string, required: true
end

attr :rows, :list, required: true

def table(assigns) do
  ~H"""
  <table>
    <thead>
      <tr>
        <th :for={col <- @col}><%= col.label %></th>
      </tr>
    </thead>
    <tbody>
      <tr :for={row <- @rows}>
        <td :for={col <- @col}>
          <%= render_slot(col, row) %>
        </td>
      </tr>
    </tbody>
  </table>
  """
end

# Usage
<.table rows={@users}>
  <:col :let={user} label="Name"><%= user.name %></:col>
  <:col :let={user} label="Email"><%= user.email %></:col>
</.table>
```

## LiveComponent Gotchas

### Preserve inner_block in update/2

```elixir
# BAD - loses inner_block
def update(assigns, socket) do
  {:ok, assign(socket, field: assigns.field)}
end

# GOOD - preserve inner_block
def update(assigns, socket) do
  {:ok,
   socket
   |> assign(:field, assigns.field)
   |> assign(:inner_block, assigns[:inner_block])}
end

# BETTER - assign all and override
def update(assigns, socket) do
  {:ok,
   socket
   |> assign(assigns)
   |> assign(:computed, compute(assigns.field))}
end
```

### Target Events Correctly

```elixir
# Event goes to LiveComponent
<button phx-click="save" phx-target={@myself}>Save</button>

# Event goes to parent LiveView
<button phx-click="close">Close</button>
```

## Review Questions

1. Are function components used for stateless UI?
2. Do LiveComponents actually need component-local state?
3. Are slots properly declared with attr/slot?
4. Is inner_block preserved in update/2?
