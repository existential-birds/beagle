# Advanced Configuration

## Injecting Custom HTML

### before_closing_head_tag

Inject CSS or meta tags into the `<head>` section. Accepts a function that receives the format (`:html` or `:epub`):

```elixir
defp docs do
  [
    before_closing_head_tag: &before_closing_head_tag/1
  ]
end

defp before_closing_head_tag(:html) do
  """
  <style>
    .content-inner {
      max-width: 900px;
    }
    .deprecated .detail-header {
      background-color: #fff3cd;
    }
  </style>
  """
end

defp before_closing_head_tag(:epub), do: ""
```

### before_closing_body_tag

Inject JavaScript before the closing `</body>` tag. Useful for analytics, custom interactions, or additional syntax highlighting:

```elixir
defp docs do
  [
    before_closing_body_tag: &before_closing_body_tag/1
  ]
end

defp before_closing_body_tag(:html) do
  """
  <script>
    document.querySelectorAll('pre code').forEach((block) => {
      block.addEventListener('click', () => {
        navigator.clipboard.writeText(block.innerText);
      });
    });
  </script>
  """
end

defp before_closing_body_tag(:epub), do: ""
```

### Format-Specific Injection

Both hooks receive the format atom, allowing different content per output:

```elixir
defp before_closing_head_tag(:html) do
  """
  <link rel="stylesheet" href="assets/custom.css">
  """
end

defp before_closing_head_tag(:epub) do
  """
  <style>
    /* epub-specific overrides */
    .content { font-size: 14pt; }
  </style>
  """
end
```

## Syntax Highlighting

ExDoc uses the [Makeup](https://hexdocs.pm/makeup) library for syntax highlighting. Elixir and Erlang are included by default.

### Adding Language Support

Add Makeup lexer packages to your deps for additional languages:

```elixir
defp deps do
  [
    {:ex_doc, "~> 0.34", only: :dev, runtime: false},
    {:makeup_html, ">= 0.0.0", only: :dev, runtime: false},
    {:makeup_json, ">= 0.0.0", only: :dev, runtime: false},
    {:makeup_diff, ">= 0.0.0", only: :dev, runtime: false},
    {:makeup_sql, ">= 0.0.0", only: :dev, runtime: false}
  ]
end
```

Available Makeup lexers:

| Package | Languages |
|---------|-----------|
| `makeup_elixir` | Elixir (included by default) |
| `makeup_erlang` | Erlang (included by default) |
| `makeup_html` | HTML |
| `makeup_json` | JSON |
| `makeup_diff` | Diff/patch |
| `makeup_sql` | SQL |
| `makeup_eex` | EEx templates |
| `makeup_c` | C |
| `makeup_rust` | Rust |

Languages without a Makeup lexer fall back to plain text rendering.

## Module Nesting

### Automatic Nesting

ExDoc automatically nests modules based on their naming hierarchy. For example:

- `WeatherStation.Sensor` appears as a top-level module
- `WeatherStation.Sensor.Temperature` nests under `WeatherStation.Sensor`
- `WeatherStation.Sensor.Temperature.Calibration` nests under `WeatherStation.Sensor.Temperature`

This creates a collapsible tree in the sidebar.

### nest_modules_by_prefix

Control which prefixes trigger nesting. By default, ExDoc nests all modules. Use `nest_modules_by_prefix` to restrict it:

```elixir
defp docs do
  [
    nest_modules_by_prefix: [
      WeatherStation.Sensor,
      WeatherStation.Pipeline
    ]
  ]
end
```

With this config:
- `WeatherStation.Sensor.Temperature` nests under `WeatherStation.Sensor`
- `WeatherStation.Pipeline.Transform` nests under `WeatherStation.Pipeline`
- `WeatherStation.Schema.Reading` stays at the top level (prefix not listed)

Set to an empty list to disable all nesting:

```elixir
nest_modules_by_prefix: []
```

## The api-reference Page

ExDoc generates an `api-reference` page by default, listing all documented modules. This is the default landing page unless you set `main` to something else.

The page groups modules according to `groups_for_modules` and shows a brief description from each module's `@moduledoc`.

To make it the explicit landing page:

```elixir
docs: [main: "api-reference"]
```

## Suppressing Warnings

### skip_undefined_reference_warnings_on

Suppress warnings about undefined references in specific pages. Useful for changelogs and guides that mention modules or functions from other projects:

```elixir
defp docs do
  [
    skip_undefined_reference_warnings_on: [
      "CHANGELOG.md",
      "guides/migration-from-v1.md"
    ]
  ]
end
```

### skip_code_autolink_to

Prevent ExDoc from auto-linking specific terms that look like module or function references but are not:

```elixir
defp docs do
  [
    skip_code_autolink_to: [
      "Ecto.Schema",
      "Phoenix.Controller",
      "mix phx.gen.schema"
    ]
  ]
end
```

Use this when you reference external modules that are not in your deps, or when backticked terms like `` `Config` `` should not link to a module.

## Annotations

Add version or status annotations that appear next to module names in the sidebar:

```elixir
defp docs do
  [
    annotations_for_docs: fn metadata ->
      cond do
        metadata[:since] -> "since #{metadata[:since]}"
        metadata[:deprecated] -> "deprecated"
        true -> nil
      end
    end
  ]
end
```

Tag functions in your code:

```elixir
@doc since: "1.2.0"
def stream_readings(station_id, opts \\ []) do
  # ...
end

@doc deprecated: "Use stream_readings/2 instead"
def poll_readings(station_id) do
  # ...
end
```

## Static Assets

Include images, CSS, or other static files in your generated docs:

```elixir
defp docs do
  [
    assets: %{
      "guides/images" => "images",
      "guides/diagrams" => "diagrams"
    }
  ]
end
```

This copies files from the source directory (key) to the target directory (value) inside the generated docs. Reference them in your extras:

```markdown
## System Architecture

![Architecture diagram](diagrams/architecture.png)

## Sensor Placement

![Sensor layout](images/sensor-layout.svg)
```

### Asset Path Rules

- Source paths are relative to the project root
- Target paths are relative to the doc output directory
- Files are copied as-is (no processing)
- Use consistent directory names between source and your markdown references

## Complete Advanced Example

```elixir
defp docs do
  [
    main: "readme",
    logo: "priv/static/images/logo.png",
    source_ref: "v#{@version}",
    extras: extras(),
    groups_for_modules: groups_for_modules(),
    groups_for_extras: groups_for_extras(),
    nest_modules_by_prefix: [
      WeatherStation.Sensor,
      WeatherStation.Pipeline,
      WeatherStation.Schema
    ],
    skip_undefined_reference_warnings_on: ["CHANGELOG.md"],
    skip_code_autolink_to: ["Config"],
    assets: %{"guides/images" => "images"},
    before_closing_head_tag: &before_closing_head_tag/1,
    before_closing_body_tag: &before_closing_body_tag/1,
    deps: [
      ecto: "https://hexdocs.pm/ecto",
      phoenix: "https://hexdocs.pm/phoenix"
    ]
  ]
end
```
