# Tech Stack and Entry Point Discovery

This reference keeps the detailed stack-detection and entry-point tracing logic that would otherwise make `SKILL.md` too long.

## Step 2: Detect Tech Stack

Scan for project configuration files to determine the stack:

```bash
# Rust detection
ls Cargo.toml Cargo.lock 2>/dev/null

# Elixir detection
ls mix.exs mix.lock 2>/dev/null

# Node.js detection
ls package.json pnpm-lock.yaml package-lock.json yarn.lock 2>/dev/null

# Python detection
ls pyproject.toml requirements.txt setup.py 2>/dev/null
ls uv.lock poetry.lock 2>/dev/null

# Go detection
ls go.mod 2>/dev/null

# Docker detection
ls docker-compose.yml docker-compose.yaml Dockerfile 2>/dev/null

# Makefile detection
ls Makefile 2>/dev/null && grep -q "dev:" Makefile && echo "has-dev-target"

# Database detection
ls migrations/ db/migrate/ priv/repo/migrations/ 2>/dev/null
grep -rl "DATABASE_URL\|postgres\|PgPool\|sqlx\|Ecto.Repo" --include="*.rs" --include="*.ex" --include="*.py" --include="*.ts" --include="*.go" 2>/dev/null | head -5
```

### Stack Detection Rules

| Files Found | Stack | Build Commands | Default Port |
|-------------|-------|----------------|--------------|
| `Cargo.toml` | Rust (cargo) | `cargo build --release` | N/A (CLI) or 8080 |
| `mix.exs` | Elixir (mix) | `mix deps.get && mix compile` | 4000 |
| `package.json` + `pnpm-lock.yaml` | Node.js (pnpm) | `pnpm install && pnpm run build` | 5173, 3000 |
| `package.json` + `package-lock.json` | Node.js (npm) | `npm install && npm run build` | 5173, 3000 |
| `package.json` + `yarn.lock` | Node.js (yarn) | `yarn install && yarn build` | 5173, 3000 |
| `pyproject.toml` + `uv.lock` | Python (uv) | `uv sync` | 8000 |
| `pyproject.toml` + `poetry.lock` | Python (poetry) | `poetry install` | 8000 |
| `go.mod` | Go | `go build ./...` | 8080 |
| `docker-compose.yml` | Docker | `docker-compose up -d` | Parse from compose |
| `Makefile` with `dev:` target | Make-based | `make dev` | Infer from Makefile |

### Determine Project Type

After detecting the stack, classify the project:

| Type | How to detect | E2E test approach |
|------|--------------|-------------------|
| **CLI tool** | Has `fn main` / `if __name__` / binary targets, no HTTP listener | Build binary, invoke subcommands with real args, check stdout/stderr/exit code/side effects |
| **HTTP server** | Has route definitions, listens on a port | Start server, hit endpoints with curl, verify responses and database state |
| **Web app (frontend)** | Has React/Vue/Svelte routes, serves HTML | Start dev server, use agent-browser for UI interactions |
| **Full-stack** | Has both server and frontend | Start both, test API + UI |
| **Library only** | No binary, no server, no main — only `lib.rs`/`__init__.py`/package exports | Write a small driver script that exercises the public API, or test through a downstream consumer |

### Entrypoint Discovery

**Rust (clap CLI):**
```bash
# Find CLI subcommands
grep -rn "Subcommand\|#\[command\]" --include="*.rs" | head -20
# Find binary targets
grep -rn "\[\[bin\]\]\|fn main" --include="*.rs" --include="*.toml" | head -20
# Find HTTP routes (axum/actix/rocket)
grep -rn "Router::new\|\.route(\|#\[get\]\|#\[post\]\|HttpServer" --include="*.rs" | head -20
```

**Elixir (Phoenix):**
```bash
grep -rn "get \"/\|post \"/\|pipe_through\|live \"/\|scope \"/\"" --include="*.ex" | head -20
grep -rn "def handle_event\|def mount" --include="*.ex" | head -20
```

**Python:**
```bash
grep -rn "@app\.\(get\|post\|put\|delete\|patch\)" --include="*.py" | head -20
grep -rn "@router\.\(get\|post\|put\|delete\|patch\)" --include="*.py" | head -20
grep -rn "@click.command\|@app.command\|add_parser" --include="*.py" | head -20
```

**Node.js (Express/Fastify):**
```bash
grep -rn "app\.\(get\|post\|put\|delete\)" --include="*.ts" --include="*.js" | head -20
grep -rn "router\.\(get\|post\|put\|delete\)" --include="*.ts" --include="*.js" | head -20
```

**React Router:**
```bash
grep -rn "createBrowserRouter\|<Route\|path=" --include="*.tsx" --include="*.jsx" | head -20
```

**Go (net/http, gin, chi):**
```bash
grep -rn "http.HandleFunc\|r.GET\|r.POST\|router.Get\|router.Post" --include="*.go" | head -20
grep -rn "cobra.Command\|AddCommand" --include="*.go" | head -20
```

Build a map of:
- CLI subcommands: name + args + description + file:line
- API endpoints: method + path + file:line
- UI routes: path + component + file:line
- Database migrations: filename + tables affected

### Port Discovery

```bash
grep -E "^PORT=" .env .env.example .env.local 2>/dev/null
grep -A2 "ports:" docker-compose.yml 2>/dev/null
grep -E "port:" vite.config.ts vite.config.js 2>/dev/null
```

## Step 4: Trace Changes to Entry Points

For each changed file, determine if it affects user-facing functionality:

1. Direct entry point change - file contains route definitions
2. Import chain analysis - find what imports the changed file and trace up to entry points
3. Architecture-aware tracing - read CLAUDE.md, README, or architecture docs for module relationships
4. Document the trace path in test context

### Import Chain Analysis by Ecosystem

```bash
# Rust — use/mod/crate references
grep -rn "use.*<crate>\|mod <module>" --include="*.rs"
# Also check Cargo.toml dependencies between workspace crates
grep -rn "<crate-name>" --include="Cargo.toml"

# Python
grep -rn "from.*<module>\|import.*<module>" --include="*.py"

# TypeScript/JavaScript
grep -rn "from.*<module>\|require.*<module>" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx"

# Elixir
grep -rn "alias.*<Module>\|import.*<Module>\|use.*<Module>" --include="*.ex" --include="*.exs"

# Go
grep -rn "<package>\." --include="*.go"
```

If the ecosystem is not covered above, or grep results are inconclusive, read the project's CLAUDE.md, README, or architecture docs to understand the module graph and trace the data flow from changed files to user-facing entry points.

### Classify Affected Entry Points

| Category | Description | Examples | Priority |
|----------|-------------|----------|----------|
| Core functionality | Entry points where the feature does its actual work for the end user | Chat endpoint, API action, data processing pipeline, generation flow | High - test first |
| Configuration/admin | Entry points where the feature is set up, toggled, or configured | Settings page, admin dashboard, preference toggles, dropdown selections | Lower - test after core |

Requirement: At least one test must target a core functionality entry point before generating configuration/admin tests.
