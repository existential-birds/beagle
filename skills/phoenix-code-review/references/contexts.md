# Phoenix Contexts

## Bounded Contexts

### Domain Boundaries

```elixir
# GOOD - contexts bounded by domain
lib/my_app/
├── accounts/           # User identity & auth
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

## Ecto Integration

### Changesets in Contexts

```elixir
defmodule MyApp.Accounts do
  alias MyApp.Accounts.User

  def create_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  def update_user(%User{} = user, attrs) do
    user
    |> User.update_changeset(attrs)
    |> Repo.update()
  end
end
```

### Schema Definitions

```elixir
defmodule MyApp.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :password_hash, :string
    field :password, :string, virtual: true

    timestamps()
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password])
    |> validate_required([:email, :password])
    |> validate_format(:email, ~r/@/)
    |> validate_length(:password, min: 8)
    |> unique_constraint(:email)
    |> hash_password()
  end
end
```

## Cross-Context Communication

```elixir
# GOOD - contexts communicate through public APIs
defmodule MyApp.Orders do
  alias MyApp.Accounts

  def create_order(user_id, items) do
    with {:ok, user} <- Accounts.get_user(user_id),
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
2. Do public functions have domain-focused names?
3. Are changesets used for all data validation?
4. Do contexts communicate through public APIs only?
