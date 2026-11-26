# Admonitions and Formatting

## Admonition Blocks

Admonitions are callout boxes rendered by ExDoc. They use blockquote syntax with a special heading:

```markdown
> #### Watch out for atom exhaustion {: .warning}
>
> Calling `String.to_atom/1` on user input can exhaust the atom table.
> Use `String.to_existing_atom/1` instead.
```

### Structure

1. Start with `> ####` followed by the admonition title
2. Add `{: .class}` at the end of the title line
3. Follow with `>` blank line and `>` content lines

### Available Classes

| Class | Use for | Rendered appearance |
|-------|---------|---------------------|
| `.warning` | Potential pitfalls, breaking changes | Yellow/amber box |
| `.error` | Dangerous operations, common mistakes | Red box |
| `.info` | Additional context, background | Blue box |
| `.tip` | Best practices, performance hints | Green box |
| `.neutral` | General callouts without urgency | Grey box |

### Examples

```elixir
@moduledoc """
Manages database connections for the application.

> #### Requires database access {: .info}
>
> This module expects a running PostgreSQL instance. See the
> [setup guide](setup.md) for local development configuration.

> #### Connection pooling {: .tip}
>
> For high-throughput workloads, increase the pool size in
> `config/runtime.exs`:
>
>     config :my_app, MyApp.Repo,
>       pool_size: 20

> #### Do not call at compile time {: .error}
>
> Functions in this module require the application to be started.
> Calling them in module attributes or at compile time will raise.
"""
```

### Multi-Paragraph Admonitions

Continue with `>` on each line:

```elixir
@doc """
> #### Migration required {: .warning}
>
> After upgrading to v2.0, run the following migration:
>
>     mix ecto.migrate
>
> This adds the `archived_at` column used by the new soft-delete
> feature. Existing rows will have `NULL` in this column, which
> the query functions treat as "not archived."
"""
```

## Heading Levels (`#` vs `##`)

In `@moduledoc` and `@doc`, use **second-level headings** (`##`) as the highest level. First-level headings (`#`) are reserved for the module or function name in ExDoc output:

```elixir
# GOOD
@moduledoc """
Handles webhook delivery and retry logic.

## Retry Strategy

Failed deliveries are retried with exponential backoff.

## Configuration

Set the maximum retry count in your config.
"""

# BAD - # clashes with ExDoc's page title
@moduledoc """
# Webhook Delivery

Handles webhook delivery and retry logic.
"""
```

Within extra Markdown guides, `#` is used as the page title.

## Tabbed Content

ExDoc supports tabbed content blocks using HTML comments and third-level headings:

```elixir
@moduledoc """
## Installation

<!-- tabs-open -->

### Mix

Add to your `mix.exs` dependencies:

    {:my_library, "~> 1.0"}

### Rebar3

Add to your `rebar.config`:

    {deps, [{my_library, "1.0.0"}]}.

### Erlang.mk

Add to your `Makefile`:

    dep_my_library = hex 1.0.0

<!-- tabs-close -->
"""
```

**Rules:**

- Open with `<!-- tabs-open -->`
- Each tab is a `###` heading
- Close with `<!-- tabs-close -->`
- Content between `###` headings becomes that tab's body
- Tabs work in `@moduledoc`, `@doc`, and extra pages

### Realistic Example

```elixir
@doc """
Serializes a struct to a transport format.

## Examples

<!-- tabs-open -->

### JSON

    iex> MyApp.Serializer.encode(%User{name: "Alice"}, :json)
    {:ok, ~s({"name":"Alice"})}

### MessagePack

    iex> MyApp.Serializer.encode(%User{name: "Alice"}, :msgpack)
    {:ok, <<129, 164, 110, 97, 109, 101, 165, 65, 108, 105, 99, 101>>}

<!-- tabs-close -->
"""
```

## Four-Space Doctests vs Fenced Code Blocks

Within `## Examples` sections, use **four-space indentation** (not fenced ```` ```elixir ```` blocks) whenever you want ExDoc and ExUnit's `doctest` macro to detect and execute examples:

```elixir
@doc """
## Examples

    iex> MyApp.Math.add(2, 3)
    5
"""
```

Use fenced blocks with language tags (```` ```elixir ````, ```` ```bash ````) only for non-executable snippets such as configuration files or CLI commands.

## Combining ExDoc Elements

```elixir
defmodule MyApp.RateLimiter do
  @moduledoc """
  Token-bucket rate limiter backed by ETS.

  Limits are configured per endpoint and enforced in the
  `MyApp.Plugs.RateLimit` plug.

  > #### Production configuration {: .tip}
  >
  > Set limits based on your capacity planning. Start conservative
  > and adjust based on metrics from `MyApp.Telemetry`.

  ## Examples

      iex> {:ok, limiter} = MyApp.RateLimiter.start_link(name: :api)
      iex> MyApp.RateLimiter.check(limiter, "user:42", :search)
      :allow

  ## Architecture

  <!-- tabs-open -->

  ### Single Node

  Uses a local ETS table with `read_concurrency: true`.

  ### Distributed

  Synchronizes buckets across nodes via `:pg`.

  <!-- tabs-close -->
  """
end
```
