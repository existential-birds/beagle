# Doctests

## When to Use Doctests

Doctests serve double duty: they are runnable examples in your documentation **and** lightweight tests. Use them for:

- **Pure functions** with deterministic output
- **String/data transformations** where the input and output are easy to read
- **Simple calculations** and formatting helpers
- **Demonstrating API usage** to new developers

```elixir
@doc """
Converts a price in cents to a formatted dollar string.

## Examples

    iex> MyApp.Format.price_in_dollars(1050)
    "$10.50"

    iex> MyApp.Format.price_in_dollars(0)
    "$0.00"

    iex> MyApp.Format.price_in_dollars(7)
    "$0.07"
"""
def price_in_dollars(cents) when is_integer(cents) and cents >= 0 do
  "$#{div(cents, 100)}.#{cents |> rem(100) |> Integer.to_string() |> String.pad_leading(2, "0")}"
end
```

## When NOT to Use Doctests

Skip doctests when the function:

- **Touches the database** -- results depend on test state
- **Makes HTTP requests** or calls external services
- **Depends on time** -- `DateTime.utc_now/0`, timers, TTLs
- **Produces random output** -- UUIDs, tokens, nonces
- **Has side effects** -- sends emails, writes files, publishes messages
- **Returns large or complex structures** -- hard to read and brittle

```elixir
# BAD - database dependency
@doc """
    iex> MyApp.Accounts.create_user(%{email: "test@example.com"})
    {:ok, %User{}}
"""

# BAD - time dependent
@doc """
    iex> MyApp.Token.generate_expiring()
    %{token: "abc", expires_at: ~U[2025-01-01 12:00:00Z]}
"""

# GOOD - write a regular ExUnit test instead
test "create_user/1 persists a valid user" do
  assert {:ok, %User{email: "test@example.com"}} =
           MyApp.Accounts.create_user(%{email: "test@example.com"})
end
```

## iex> Syntax Basics

### Single-Line Expressions

Each doctest begins with `iex>` followed by a space and the expression. The expected result goes on the next line, unindented relative to `iex>`:

```elixir
@doc """
    iex> String.upcase("hello")
    "HELLO"
"""
```

### Multi-Line Expressions

Use `...>` for continuation lines. The result still follows on the next line:

```elixir
@doc """
    iex> %{name: "Alice", role: :admin}
    ...> |> MyApp.Accounts.display_name()
    "Alice (admin)"
"""
```

### Multiple Examples in One Docstring

Separate independent examples with a blank line:

```elixir
@doc """
    iex> MyApp.Math.clamp(15, 0, 10)
    10

    iex> MyApp.Math.clamp(-3, 0, 10)
    0

    iex> MyApp.Math.clamp(5, 0, 10)
    5
"""
```

### Binding Variables Across Lines

Variables bound in one `iex>` line carry forward within the same example block:

```elixir
@doc """
    iex> list = [3, 1, 4, 1, 5]
    iex> Enum.sort(list)
    [1, 1, 3, 4, 5]
"""
```

## Testing Error Tuples

Return error tuples directly:

```elixir
@doc """
    iex> MyApp.Validation.parse_age("not a number")
    {:error, :invalid_integer}

    iex> MyApp.Validation.parse_age("-5")
    {:error, :must_be_positive}

    iex> MyApp.Validation.parse_age("25")
    {:ok, 25}
"""
```

## Testing Exceptions

Use `** (ExceptionModule)` syntax:

```elixir
@doc """
    iex> MyApp.Validation.parse_age!(nil)
    ** (ArgumentError) expected a string, got: nil
"""
```

The message after the exception module name is matched as a prefix, so you do not need the full message if it is long. However, the exception module must match exactly.

```elixir
# Matches any FunctionClauseError regardless of message
@doc """
    iex> MyApp.Math.factorial(-1)
    ** (FunctionClauseError)
"""
```

## Doctests with Structs

### Inspect-Based Output

When a struct implements the `Inspect` protocol with a custom format, match against that format:

```elixir
@doc """
    iex> MyApp.Money.new(1099, :USD)
    #MyApp.Money<$10.99 USD>
"""
```

### Default Struct Inspect

By default, structs inspect as `%Module{}`:

```elixir
@doc """
    iex> MyApp.Coordinate.origin()
    %MyApp.Coordinate{x: 0, y: 0}
"""
```

### Partial Matching with Pattern Variables

When a struct has fields you cannot predict (like IDs or timestamps), avoid doctests. Write a regular test instead, or only test the fields you control:

```elixir
# Instead of a doctest, use a regular test:
test "build/1 sets the correct defaults" do
  coord = MyApp.Coordinate.build(%{x: 5})
  assert coord.x == 5
  assert coord.y == 0
end
```

## Setting Up Doctests in Test Files

Add `doctest` to any ExUnit test file:

```elixir
defmodule MyApp.FormatTest do
  use ExUnit.Case, async: true

  # Run all doctests in the module
  doctest MyApp.Format

  # Additional unit tests
  test "price_in_dollars/1 handles large values" do
    assert MyApp.Format.price_in_dollars(1_000_000) == "$10000.00"
  end
end
```

You can also place doctests in a dedicated file:

```elixir
defmodule MyApp.DoctestTest do
  use ExUnit.Case, async: true

  doctest MyApp.Format
  doctest MyApp.Math
  doctest MyApp.Validation
end
```

### Running Specific Doctests

```bash
# Run all tests in a file containing doctests
mix test test/my_app/format_test.exs

# Run a specific doctest by line number (line of the iex> prompt in source)
mix test test/my_app/format_test.exs:14
```

## Common Gotchas

### Whitespace Sensitivity

The expected output must match **exactly**, including whitespace. Trailing spaces will cause failures that are hard to spot:

```elixir
# This will FAIL if inspect output has no trailing space
@doc """
    iex> inspect(%{a: 1})
    "%{a: 1} "
"""
```

### Map Key Ordering

Maps with atom keys are printed in alphabetical order by `inspect/1`. Match that order:

```elixir
# GOOD - keys in alphabetical order
@doc """
    iex> MyApp.Config.defaults()
    %{host: "localhost", port: 4000, scheme: :https}
"""

# BAD - keys in insertion order (will fail)
@doc """
    iex> MyApp.Config.defaults()
    %{scheme: :https, host: "localhost", port: 4000}
"""
```

### String Escaping

Strings containing special characters must match the inspected form:

```elixir
@doc """
    iex> MyApp.CSV.escape("value with \\"quotes\\"")
    "\\"value with \\\\\\\"quotes\\\\\\\"\\""
"""
```

When string escaping gets complex, skip the doctest and write a regular test for clarity.

### Large or Multiline Output

If output spans many lines, it becomes brittle. Prefer regular tests:

```elixir
# BAD - long output makes doctest fragile and hard to read
@doc """
    iex> MyApp.Report.generate(:monthly)
    %{
      title: "Monthly Report",
      sections: [
        %{name: "Revenue", ...},
        ...
      ]
    }
"""

# GOOD - test what matters in a regular test
test "generate/1 returns a report with expected sections" do
  report = MyApp.Report.generate(:monthly)
  assert report.title == "Monthly Report"
  assert length(report.sections) == 3
end
```

### Opaque Types

You cannot match on the internals of an `@opaque` type in a doctest. Instead, show usage patterns:

```elixir
@doc """
    iex> conn = MyApp.Connection.open("localhost", 5432)
    iex> is_struct(conn, MyApp.Connection)
    true
"""
```
