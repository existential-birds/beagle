# Documentation Quality

## What Makes Good Module Docs

A well-documented module tells the reader four things: what it does, when to use it, how to use it, and how to configure it.

### Structure

```elixir
defmodule MyApp.RateLimiter do
  @moduledoc """
  Token bucket rate limiter for API endpoints.

  Use this module to throttle incoming requests per client. It tracks
  request counts in ETS and supports configurable burst and refill rates.

  ## Examples

      iex> {:ok, limiter} = RateLimiter.start_link(rate: 100, interval: :timer.seconds(1))
      iex> RateLimiter.allow?(limiter, "client-123")
      true

  ## Configuration

  Expects the following options:

    * `:rate` - Maximum requests per interval (required)
    * `:interval` - Refill interval in milliseconds (default: 1000)
    * `:burst` - Maximum burst size (default: same as `:rate`)
  """
end
```

The first line ("Token bucket rate limiter for API endpoints.") is critical -- ExDoc uses it as the module summary in sidebar listings and search results. Keep it to one sentence.

## What Makes Good Function Docs

Good function docs answer: what does it do, what are the inputs, what does it return, and what are the edge cases.

```elixir
@doc """
Checks whether a client is allowed to make a request.

Decrements the token count for the given `client_id` and returns
whether the request should proceed. When tokens are exhausted,
returns `false` until the next refill interval.

Returns `{:ok, remaining}` with the remaining token count, or
`{:error, :rate_limited}` when the limit is exceeded.

## Examples

    iex> RateLimiter.check("client-123")
    {:ok, 99}

    iex> RateLimiter.check("exhausted-client")
    {:error, :rate_limited}
"""
@spec check(client_id :: String.t()) :: {:ok, non_neg_integer()} | {:error, :rate_limited}
def check(client_id) do
  # ...
end
```

## Anti-Patterns

### Empty @moduledoc String

```elixir
# BAD - empty string still shows in ExDoc as a blank page
defmodule MyApp.Internal.Parser do
  @moduledoc ""
end

# GOOD - explicitly hidden from ExDoc output
defmodule MyApp.Internal.Parser do
  @moduledoc false
end
```

If you want to hide a module from documentation, use `@moduledoc false`. An empty string creates a confusing blank entry in generated docs.

### Restating the Function Name

```elixir
# BAD - tells the reader nothing they didn't already know
@doc "Gets the user."
@spec get_user(integer()) :: User.t() | nil
def get_user(id), do: Repo.get(User, id)

# GOOD - explains behavior, return semantics, edge cases
@doc """
Fetches a user by primary key.

Returns the `%User{}` struct if found, or `nil` if no user exists
with the given `id`. Does not raise on missing records.
"""
@spec get_user(integer()) :: User.t() | nil
def get_user(id), do: Repo.get(User, id)
```

### Missing Return Value Documentation

```elixir
# BAD - what does it return on success? On failure?
@doc "Processes the payment."
def process_payment(order), do: # ...

# GOOD - return values are explicit
@doc """
Submits a payment for the given order to the payment gateway.

Returns `{:ok, %Transaction{}}` on successful charge, or
`{:error, %PaymentError{}}` if the charge is declined or
the gateway is unavailable.
"""
def process_payment(order), do: # ...
```

### Wrong or Outdated Doctest Examples

```elixir
# BAD - doctest will fail because the function now returns a tuple
@doc """
Formats a price in cents as a dollar string.

## Examples

    iex> format_price(1999)
    "$19.99"
"""
def format_price(cents) do
  {:ok, "$#{cents / 100}"}  # Return type changed but doctest wasn't updated
end

# GOOD - doctest matches actual return value
@doc """
Formats a price in cents as a dollar string.

## Examples

    iex> format_price(1999)
    {:ok, "$19.99"}
"""
def format_price(cents) do
  {:ok, "$#{cents / 100}"}
end
```

### Documenting Obvious Params but Not Edge Cases

```elixir
# BAD - documents obvious params, ignores what matters
@doc """
Divides `a` by `b`.

## Parameters

  * `a` - The numerator
  * `b` - The denominator
"""
def divide(a, b), do: a / b

# GOOD - documents the interesting behavior
@doc """
Divides `a` by `b`.

Raises `ArithmeticError` when `b` is zero. Returns a float
even when both arguments are integers.

## Examples

    iex> divide(10, 3)
    3.3333333333333335

    iex> divide(10, 0)
    ** (ArithmeticError) bad argument in arithmetic expression
"""
def divide(a, b), do: a / b
```

### Using @doc When @impl true Would Suffice

```elixir
# BAD - redundant doc that duplicates the behaviour's documentation
defmodule MyApp.Cache do
  @behaviour MyApp.Store

  @doc "Initializes the store."
  @impl true
  def init(opts), do: # ...
end

# GOOD - @impl true inherits docs from the behaviour
defmodule MyApp.Cache do
  @behaviour MyApp.Store

  @impl true
  def init(opts), do: # ...
end
```

When a module implements a behaviour, using `@impl true` signals that the function's contract is defined by the behaviour. Adding a separate `@doc` that just restates the behaviour's docs creates maintenance burden with no benefit. Only add `@doc` on `@impl true` callbacks when the implementation has important details the behaviour docs don't cover.

## The "Write for the Reader" Principle

Documentation is read by developers who don't have your current context. Ask yourself:

1. **Would a new team member understand this module's purpose from @moduledoc alone?**
2. **Would a caller know what to pass and what to expect back from @doc alone?**
3. **Would someone debugging a failure understand the error cases from the docs?**

If the answer to any of these is no, the docs need improvement -- regardless of whether they technically exist.

## Review Questions

1. Does the @moduledoc first line work as a standalone summary?
2. Do @doc blocks describe return values and error cases?
3. Are doctests current and matching actual function behavior?
4. Do docs add value beyond what the function name and @spec already convey?
