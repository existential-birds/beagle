# Cross-References and Linking

ExDoc auto-links identifiers written in backtick-delimited code spans. This reference covers every linking syntax available.

## Module Links

Reference another module by writing its name in backticks:

```elixir
@moduledoc """
See `MyApp.Accounts` for user management functions.
"""
```

If the module name collides with a local function or could be ambiguous, use the `m:` prefix:

```elixir
@doc """
Delegates to `m:MyApp.Accounts` for persistence.
"""
```

The `m:` prefix is also useful when linking to modules whose names look like function calls.

## Function Links

### Remote Functions (Other Modules)

```elixir
@doc """
Similar to `MyApp.Accounts.get_user/1` but raises on failure.
Accepts the same options as `MyApp.Accounts.list_users/2`.
"""
```

### Local Functions (Same Module)

Omit the module name to link to a function in the current module:

```elixir
@doc """
The bang variant of `fetch_config/1`. Raises `KeyError` if the key is missing.
"""
```

### Operators

```elixir
@doc """
Works like the `Kernel.<>/2` operator but for lists.
"""
```

### Function Arity

Always include the arity. `function/1` and `function/2` are distinct links:

```elixir
@doc """
See `transform/1` for the single-argument version, or
`transform/2` to pass options.
"""
```

## Type Links

Use the `t:` prefix to link to types:

```elixir
@doc """
Returns a `t:MyApp.Money.amount/0` representing the balance.

Accepts any `t:Enumerable.t/0` as input.
"""
```

For types in the same module:

```elixir
@doc """
Returns a `t:result/0` tuple.
"""
```

## Callback Links

Use the `c:` prefix to link to behaviour callbacks:

```elixir
@doc """
Invoked by the framework. See `c:GenServer.init/1` for details.

Implementations must satisfy `c:MyApp.PaymentGateway.charge/2`.
"""
```

## Erlang Module and Function Links

### Erlang Modules

Use `m:` with the atom syntax:

```elixir
@doc """
Uses `m::ets` for fast in-memory lookups.
"""
```

### Erlang Functions

Use the atom syntax directly:

```elixir
@doc """
Wraps `:erlang.system_info/1` to fetch VM metrics.

Delegates to `:timer.send_interval/2` for periodic messages.
"""
```

### Erlang Types

```elixir
@doc """
Returns a `t::erlang.reference/0`.
"""
```

## Custom Text Links

When you want link text that differs from the identifier, use markdown link syntax with a backtick-delimited destination:

```elixir
@doc """
Returns a [money amount](`MyApp.Money.amount/0`) in the given currency.

See the [payment gateway behaviour](`MyApp.PaymentGateway`) for the
full contract.

Read the [validation rules](`MyApp.Validation.validate/2`) for details.
"""
```

## Cross-Application References

Link to documentation in other Hex packages or OTP apps using `e:`:

```elixir
@doc """
Follows the patterns described in the
[Elixir writing documentation guide](`e:elixir:writing-documentation.html`).

See [Plug.Conn](`e:plug:Plug.Conn.html`) for the full struct reference.
"""
```

For functions in other apps:

```elixir
@doc """
Wraps [`Ecto.Repo.transaction/2`](`e:ecto:Ecto.Repo.html#c:transaction/2`).
"""
```

## Linking to Extra Pages

If your project includes extra markdown pages in the ExDoc configuration, link to them by filename:

```elixir
@moduledoc """
For deployment instructions, see the [Operations Guide](operations-guide.md).

Architecture decisions are documented in [ADR-001](adr/001-event-sourcing.md).
"""
```

## Summary of Prefixes

| Prefix | Links to | Example |
|--------|----------|---------|
| *(none)* | Module or function | `` `MyApp.Repo` ``, `` `fetch/1` `` |
| `m:` | Module (explicit) | `` `m:MyApp.Repo` `` |
| `t:` | Type | `` `t:String.t/0` `` |
| `c:` | Callback | `` `c:GenServer.init/1` `` |
| `e:` | Cross-app page | `` `e:elixir:writing-documentation.html` `` |

## Common Mistakes

```elixir
# BAD - missing arity
@doc "See `MyApp.Accounts.get_user` for details."

# GOOD - include arity
@doc "See `MyApp.Accounts.get_user/1` for details."

# BAD - using URL-style links for internal modules
@doc "See [MyApp.Accounts](https://hexdocs.pm/my_app/MyApp.Accounts.html)."

# GOOD - let ExDoc resolve the link
@doc "See `MyApp.Accounts`."

# BAD - linking to private functions (ExDoc will warn)
@doc "Uses `do_internal_parse/2` under the hood."

# GOOD - only link to public API
@doc "Uses an internal parser to process the input."
```
