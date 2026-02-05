# ExUnit Patterns

## Async Tests

### Default to Async

```elixir
# GOOD - isolated test
defmodule MyApp.CalculatorTest do
  use ExUnit.Case, async: true

  test "adds numbers" do
    assert Calculator.add(1, 2) == 3
  end
end
```

### When to Disable Async

```elixir
# Sharing database with other tests
defmodule MyApp.UserTest do
  use MyApp.DataCase  # Sets async: false if needed

  test "creates user" do
    assert {:ok, _} = Accounts.create_user(%{email: "test@example.com"})
  end
end
```

## Describe Blocks

### Group Related Tests

```elixir
defmodule MyApp.UserTest do
  use MyApp.DataCase

  describe "create_user/1" do
    test "with valid attrs creates user" do
      assert {:ok, user} = Accounts.create_user(valid_attrs())
      assert user.email == "test@example.com"
    end

    test "with invalid email returns error" do
      assert {:error, changeset} = Accounts.create_user(%{email: "invalid"})
      assert "is invalid" in errors_on(changeset).email
    end

    test "with duplicate email returns error" do
      Accounts.create_user(valid_attrs())
      assert {:error, changeset} = Accounts.create_user(valid_attrs())
      assert "has already been taken" in errors_on(changeset).email
    end
  end

  describe "authenticate_user/2" do
    # ...
  end
end
```

## Setup

### Shared Setup

```elixir
defmodule MyApp.PostTest do
  use MyApp.DataCase

  setup do
    user = insert(:user)
    {:ok, user: user}
  end

  test "creates post for user", %{user: user} do
    assert {:ok, post} = Posts.create_post(user, %{title: "Test"})
    assert post.user_id == user.id
  end
end
```

### Setup per Describe

```elixir
describe "admin functions" do
  setup do
    admin = insert(:user, role: :admin)
    {:ok, admin: admin}
  end

  test "admin can delete", %{admin: admin} do
    # ...
  end
end

describe "user functions" do
  setup do
    user = insert(:user, role: :user)
    {:ok, user: user}
  end

  test "user cannot delete", %{user: user} do
    # ...
  end
end
```

## Tags

### Skip Tests

```elixir
@tag :skip
test "not implemented yet" do
end

# Run: mix test --exclude skip
```

### Slow Tests

```elixir
@tag :slow
test "integration with external service" do
end

# Run: mix test --exclude slow
# Or: mix test --only slow
```

### Custom Tags

```elixir
@tag :integration
test "full workflow" do
end

# In test_helper.exs
ExUnit.configure(exclude: [:integration])

# Run: mix test --include integration
```

## Assertions

### Pattern Matching

```elixir
# GOOD - precise matching
assert {:ok, %User{email: "test@example.com"}} = Accounts.create_user(attrs)

# GOOD - extract for further assertions
assert {:ok, user} = Accounts.create_user(attrs)
assert user.email == "test@example.com"
assert user.confirmed_at == nil
```

### Refute

```elixir
test "does not include deleted" do
  refute deleted_user in Accounts.list_active_users()
end
```

### Assert Raise

```elixir
test "raises on invalid input" do
  assert_raise ArgumentError, ~r/must be positive/, fn ->
    Calculator.sqrt(-1)
  end
end
```

## Review Questions

1. Are tests async when possible?
2. Are describe blocks used to group related tests?
3. Is setup used to reduce duplication?
4. Are assertions using pattern matching effectively?
