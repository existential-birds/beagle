# Phoenix Contexts

## Bounded Contexts

### Domain Boundaries

```elixir
# GOOD - contexts bounded by domain
lib/my_app/
├── accounts/           # User identity & auth
│   ├── scope.ex
│   ├── user.ex
│   └── accounts.ex
├── catalog/            # Product information
│   ├── product.ex
│   └── catalog.ex
└── orders/             # Purchase workflow
    ├── order.ex
    └── orders.ex

# BAD - contexts bounded by technical layer
lib/my_app/
├── models/
├── queries/
└── services/
```

### Public API Design

```elixir
# GOOD - domain-focused function names
defmodule MyApp.Accounts do
  def register_user(attrs)
  def authenticate_user(email, password)
  def reset_password(user, new_password)
end

# BAD - CRUD-focused names
defmodule MyApp.Accounts do
  def create_user(attrs)
  def get_user(id)
  def update_user(user, attrs)
end
```

## Phoenix 1.8 Scopes

Phoenix 1.8+ introduces `%Scope{}` structs (assigned as `:current_scope` on `conn` and `socket` by `mix phx.gen.auth`) to enforce per-user and multi-tenant authorization directly at the context boundary:

```elixir
defmodule MyApp.Accounts.Scope do
  alias MyApp.Accounts.User

  defstruct user: nil

  def for_user(%User{} = user), do: %__MODULE__{user: user}
  def for_user(nil), do: nil
end

defmodule MyApp.Posts do
  alias MyApp.Accounts.Scope
  alias MyApp.Posts.Post

  # GOOD - scope constrains queries and mutations to the authorized caller
  def list_posts(%Scope{user: user}) do
    Repo.all(from p in Post, where: p.user_id == ^user.id)
  end

  def create_post(%Scope{user: user}, attrs) do
    %Post{user_id: user.id}
    |> Post.changeset(attrs)
    |> Repo.insert()
  end
end
```

When reviewing Phoenix 1.8+ applications, verify that scoped context functions receive `%Scope{}` from `conn.assigns.current_scope` / `socket.assigns.current_scope` rather than trusting client-supplied `user_id` or `tenant_id` parameters.

## Ecto Integration

### Changesets in Contexts

```elixir
defmodule MyApp.Accounts do
  alias MyApp.Accounts.User

  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  def update_user(%User{} = user, attrs) do
    user
    |> User.profile_changeset(attrs)
    |> Repo.update()
  end
end
```

### Schema Definitions & Password Changesets

Keep password hashing in a dedicated `password_changeset/3` (or invoked only from registration/password-reset changesets) so unrelated profile updates never accidentally re-hash or overwrite `password_hash`:

```elixir
defmodule MyApp.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :password_hash, :string
    field :password, :string, virtual: true, redact: true

    timestamps()
  end

  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :password])
    |> validate_email(opts)
    |> validate_password(opts)
  end

  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      |> put_change(:password_hash, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end
end
```

## Cross-Context Communication

```elixir
# GOOD - contexts communicate through public APIs
defmodule MyApp.Orders do
  alias MyApp.Accounts

  def create_order(user_id, items) do
    with {:ok, user} <- Accounts.fetch_user(user_id),
         :ok <- Accounts.verify_can_purchase(user) do
      # Create order
    end
  end
end

# BAD - reaching into another context's internals
defmodule MyApp.Orders do
  alias MyApp.Accounts.User
  alias MyApp.Repo

  def create_order(user_id, items) do
    user = Repo.get!(User, user_id)  # Bypasses Accounts context!
    # ...
  end
end
```

## Review Questions

1. Are contexts bounded by business domain, not technical layer?
2. Do scoped operations accept `%Scope{}` (Phoenix 1.8+) or verify ownership inside the context?
3. Are password changesets separated from general profile changesets (with `redact: true` and `delete_change(:password)`)?
4. Do contexts communicate through public APIs only?
