# Elixir Documentation Skills Design

## Summary

Three new skills for the `beagle-elixir` plugin covering Elixir documentation writing, ExDoc configuration, and documentation review.

## Skills

### 1. `elixir-writing-docs` (Development Skill)

**Trigger:** "Guides writing Elixir documentation with @moduledoc, @doc, @typedoc, doctests, cross-references, and metadata. Use when adding or improving documentation in .ex files."

**SKILL.md:**
- First-line summary rule (tools use opening paragraph for summaries)
- @moduledoc structure: purpose, examples, configuration sections
- @doc structure: description, return values, examples
- @typedoc for custom types
- Metadata: `@doc since:`, `@doc deprecated:`
- When to use `@doc false` / `@moduledoc false`
- Documentation vs code comments (the Elixir distinction)

**references/:**
- `doctests.md` — When to use/avoid doctests, iex> syntax, multi-line examples, doctest for error tuples
- `cross-references.md` — Auto-linking syntax (modules, functions, types, callbacks, erlang modules, custom text links, cross-app refs)
- `admonitions-and-formatting.md` — Admonition blocks (warning, error, info, tip), tabbed content, headers (## only, not #), code blocks

### 2. `exdoc-config` (Development Skill)

**Trigger:** "Configures ExDoc for Elixir projects including mix.exs setup, extras, groups, cheatsheets, and livebooks. Use when setting up or modifying ExDoc documentation generation."

**SKILL.md:**
- mix.exs dependency setup (`{:ex_doc, "~> 0.34", only: :dev, runtime: false}`)
- Project config: `name`, `source_url`, `homepage_url`, `docs` key
- The `docs/0` function: `main`, `logo`, `output`, `formatters`
- Extras: README, guides, ordering
- Groups: grouping modules and functions
- Dependency doc links

**references/:**
- `extras-formats.md` — Markdown (`.md`), cheatsheets (`.cheatmd` structure and syntax), livebooks (`.livemd`), organizing and ordering extras
- `advanced-config.md` — Before/after closing tags (custom JS/CSS), syntax highlighting with Makeup, nest modules under types, `api-reference` page, `skip_undefined_reference_warnings_on`, `skip_code_autolink_to`

### 3. `elixir-docs-review` (Review Skill)

**Trigger:** "Reviews Elixir documentation for completeness, quality, and ExDoc best practices. Use when auditing @moduledoc, @doc, @spec coverage, doctest correctness, and cross-reference usage in .ex files."

**SKILL.md:**
- Review checklist:
  - All public modules have @moduledoc
  - All public functions have @doc and @spec
  - First-line summaries are concise and one-line
  - Doctests present for pure functions, absent for side-effectful ones
  - Cross-references use backtick auto-linking (not plain text)
  - Metadata (@since, @deprecated) used where appropriate
  - @doc false / @moduledoc false only on genuinely internal items
- Valid patterns (do NOT flag) section
- Context-sensitive rules table
- "Before Submitting Findings" links to review-verification-protocol

**references/:**
- `doc-quality.md` — Good vs bad module/function docs, common anti-patterns (empty docs, restating function name, missing return values, wrong doctests)
- `spec-coverage.md` — @spec patterns, @type/@typedoc, when @spec is required vs optional, common spec mistakes

## File Structure

```text
plugins/beagle-elixir/skills/
├── elixir-writing-docs/
│   ├── SKILL.md
│   └── references/
│       ├── doctests.md
│       ├── cross-references.md
│       └── admonitions-and-formatting.md
├── exdoc-config/
│   ├── SKILL.md
│   └── references/
│       ├── extras-formats.md
│       └── advanced-config.md
└── elixir-docs-review/
    ├── SKILL.md
    └── references/
        ├── doc-quality.md
        └── spec-coverage.md
```

## Plugin Updates

- Update `beagle-elixir/.claude-plugin/plugin.json` keywords to include `exdoc`, `documentation`
- Update `beagle-elixir/README.md` to list the three new skills
- Bump plugin version to 1.1.0 (new skills = minor version bump)
