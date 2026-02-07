# Extras Formats

ExDoc supports three formats for extra pages: Markdown, Cheatsheets, and Livebooks.

## Markdown (.md)

Standard Markdown files for long-form documentation. Use for conceptual guides, architecture overviews, getting started guides, and changelogs.

### Structure

```markdown
# Getting Started with WeatherStation

## Prerequisites

- Elixir 1.17+
- PostgreSQL 15+

## Installation

Add `weather_station` to your dependencies:

    {:weather_station, "~> 1.3"}

## Configuration

Configure your sensor endpoints in `config/config.exs`:

    config :weather_station,
      sensors: ["temp_01", "humidity_01"],
      poll_interval: :timer.seconds(30)
```

### Tips

- Use the first `h1` heading as the page title (ExDoc picks it up automatically)
- Fenced code blocks with language tags get syntax highlighting
- Relative links between extras work: `[Configuration](configuration.md)`
- Link to modules with backticks: `` `WeatherStation.Sensor` ``
- Link to functions: `` `WeatherStation.Sensor.read/1` ``

## Cheatsheets (.cheatmd)

Quick-reference cards rendered in a visual card layout. Use for syntax summaries, common patterns, and lookup tables.

### Basic Structure

A cheatsheet uses specific heading levels to create the card layout:

- `h1` (`#`) -- Page title
- `h2` (`##`) -- Section heading (rendered as a card group)
- `h3` (`###`) -- Individual card within a section
- Content under each `h3` becomes the card body

### Example Cheatsheet

```markdown
# Ecto Query Syntax

## Basic Queries

### Select all records

```elixir
Repo.all(User)
```

### Filter with where

```elixir
from u in User,
  where: u.active == true,
  select: u
```

### Limit and offset

```elixir
from u in User,
  limit: 10,
  offset: 20
```

## Associations

### Preload associations

```elixir
Repo.all(User) |> Repo.preload(:posts)

# Or in the query
from u in User, preload: [:posts]
```

### Join and select

```elixir
from u in User,
  join: p in assoc(u, :posts),
  where: p.published == true,
  select: {u.name, p.title}
```
```

### Card Layout Rules

- Each `h2` section becomes a visually distinct group with a header
- Each `h3` under an `h2` becomes a card in that group
- Code blocks inside cards are rendered as styled examples
- Keep card content concise -- cheatsheets are for quick scanning
- Plain text under `h2` (before any `h3`) appears as an intro for that section
- Content before the first `h2` appears as a page introduction

### When to Use Cheatsheets

- API quick reference (common function calls)
- Syntax summaries (Ecto queries, Phoenix routes)
- Configuration option lookup tables
- Migration from another library (side-by-side comparisons)

## Livebooks (.livemd)

Interactive Livebook notebooks that render as rich documentation pages. Use for tutorials, data exploration walkthroughs, and interactive examples.

### How They Render in ExDoc

ExDoc renders `.livemd` files as static documentation pages with:

- Code cells displayed as syntax-highlighted code blocks
- Markdown cells rendered normally
- A "Run in Livebook" badge linking to the raw `.livemd` file so readers can open it interactively
- Mermaid diagrams rendered if present
- Output cells are **not** included -- only source and markdown cells render

### Example Livebook Structure

```markdown
# Data Pipeline Tutorial

## Setup

```elixir
Mix.install([
  {:weather_station, "~> 1.3"},
  {:kino, "~> 0.14"}
])
```

## Connecting to Sensors

First, start the sensor supervisor:

```elixir
{:ok, pid} = WeatherStation.Sensor.Supervisor.start_link(
  sensors: ["temp_01", "humidity_01"]
)
```

## Reading Data

Poll the sensors and inspect the results:

```elixir
readings = WeatherStation.Sensor.read_all()
Kino.DataTable.new(readings)
```
```

### Best Practices for Livebooks in ExDoc

- Include `Mix.install/1` in the first code cell so readers can run the notebook standalone
- Write Livebooks that make sense both as static docs and interactive sessions
- Use Markdown cells to explain what each code cell does
- Keep notebooks focused on a single workflow or concept
- Place livebooks in a dedicated directory (e.g., `notebooks/` or `livebooks/`)

## Organizing Extras

### Directory Conventions

```
project/
  README.md
  CHANGELOG.md
  guides/
    getting-started.md
    configuration.md
    deployment.md
    architecture.md
  cheatsheets/
    query-syntax.cheatmd
    router-helpers.cheatmd
  notebooks/
    data-pipeline.livemd
    sensor-setup.livemd
```

### Ordering in Sidebar

Extras appear in the order they are listed in the `extras` option. Group related pages together:

```elixir
defp extras do
  [
    "README.md",
    "guides/getting-started.md",
    "guides/configuration.md",
    "guides/architecture.md",
    "guides/deployment.md",
    "cheatsheets/query-syntax.cheatmd",
    "cheatsheets/router-helpers.cheatmd",
    "notebooks/data-pipeline.livemd",
    "CHANGELOG.md"
  ]
end
```

### Naming Conventions

- Use kebab-case for filenames: `getting-started.md`, not `Getting Started.md`
- The first `h1` heading becomes the sidebar title (override with the keyword tuple form)
- Keep filenames short -- they become part of the URL in hosted docs
- Prefix with numbers if you need explicit ordering without `groups_for_extras`: `01-getting-started.md`

### Grouping with groups_for_extras

Combine ordering with grouping for the best sidebar organization:

```elixir
defp groups_for_extras do
  [
    "Introduction": [
      "README.md"
    ],
    "Guides": [
      "guides/getting-started.md",
      "guides/configuration.md",
      "guides/architecture.md",
      "guides/deployment.md"
    ],
    "Cheatsheets": [
      "cheatsheets/query-syntax.cheatmd",
      "cheatsheets/router-helpers.cheatmd"
    ],
    "Tutorials": [
      "notebooks/data-pipeline.livemd",
      "notebooks/sensor-setup.livemd"
    ]
  ]
end
```

Extras not matching any group appear in a default section at the bottom of the sidebar.
