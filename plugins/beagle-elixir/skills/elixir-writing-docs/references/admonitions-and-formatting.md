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

## Heading Levels

In `@moduledoc` and `@doc`, use **second-level headings** (`##`) as the highest level. First-level headings (`#`) are reserved for the module or function name in ExDoc output.

```elixir
# GOOD
@moduledoc """
Handles webhook delivery and retry logic.

## Retry Strategy

Failed deliveries are retried with exponential backoff.

## Configuration

Set the maximum retry count in your config.
"""

# BAD - # will clash with ExDoc's page title
@moduledoc """
# Webhook Delivery

Handles webhook delivery and retry logic.
"""
```

Within reference documentation and extra pages, `#` is acceptable as a page title.

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

## Code Blocks

Use fenced code blocks with a language tag for syntax highlighting:

````elixir
@moduledoc """
## Usage

```elixir
{:ok, conn} = MyApp.Connection.open("localhost", 5432)
MyApp.Connection.query(conn, "SELECT 1")
```

Configuration in `config/runtime.exs`:

```elixir
config :my_app, MyApp.Connection,
  hostname: System.get_env("DB_HOST", "localhost"),
  port: String.to_integer(System.get_env("DB_PORT", "5432"))
```
"""
````

For shell commands:

````elixir
@moduledoc """
## Getting Started

```bash
mix deps.get
mix ecto.setup
mix phx.server
```
"""
````

### Indented Code Blocks in Doctests

Within `## Examples` sections, use four-space indentation (not fenced blocks) so that ExDoc can detect and run doctests:

```elixir
@doc """
## Examples

    iex> MyApp.Math.add(2, 3)
    5
"""
```

## Lists

### Unordered Lists

```elixir
@doc """
Supported formats:

* `:json` - JSON encoding via Jason
* `:msgpack` - MessagePack via Msgpax
* `:csv` - CSV encoding via NimbleCSV
"""
```

### Ordered Lists

```elixir
@doc """
Processing pipeline:

1. Validate input against the schema
2. Transform to internal representation
3. Persist to the database
4. Broadcast change event
"""
```

### Nested Lists

```elixir
@doc """
Options:

* `:format` - Output format
  * `:json` - Default
  * `:csv` - Comma-separated
* `:compress` - Whether to gzip the output
  * `true` - Enable compression
  * `false` - Default, no compression
"""
```

## Tables

```elixir
@moduledoc """
## HTTP Status Mapping

| Status | Atom | Description |
|--------|------|-------------|
| 200 | `:ok` | Successful request |
| 201 | `:created` | Resource created |
| 400 | `:bad_request` | Invalid input |
| 404 | `:not_found` | Resource missing |
| 422 | `:unprocessable_entity` | Validation failed |
"""
```

Tables must have a header row and a separator row. Alignment colons (`:---`, `:---:`, `---:`) are supported.

## Inline Formatting

| Syntax | Renders as | Use for |
|--------|-----------|---------|
| `` `code` `` | `code` | Module names, functions, atoms, options |
| `**bold**` | **bold** | Emphasis on key terms |
| `*italic*` | *italic* | Titles, introducing terms |
| `[text](url)` | link | External URLs |
| `` [`text`](`Module`) `` | code link | Cross-references (see cross-references.md) |

## Combining Formatting Techniques

A well-formatted `@moduledoc` uses several of these elements together:

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

  ## Configuration

  | Key | Type | Default | Description |
  |-----|------|---------|-------------|
  | `:window_ms` | `pos_integer()` | `60_000` | Window duration |
  | `:max_requests` | `pos_integer()` | `100` | Requests per window |
  | `:ban_duration_ms` | `pos_integer()` | `300_000` | Ban duration after exceeding limit |

  ## Architecture

  <!-- tabs-open -->

  ### Single Node

  Uses a local ETS table. Suitable for development and single-instance
  deployments.

  ### Distributed

  Wraps the ETS table with `:pg`-based synchronization. Each node
  maintains its own counter and periodically reconciles with peers.

  <!-- tabs-close -->
  """
end
```
