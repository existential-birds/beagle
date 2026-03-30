# Tech Stack and Entry Point Discovery

This reference keeps the detailed stack-detection and entry-point tracing logic that would otherwise make `SKILL.md` too long.

## Step 2: Detect Tech Stack

Scan for project configuration files to determine the stack:

```bash
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
```

### Stack Detection Rules

| Files Found | Stack | Setup Commands | Default Port |
|-------------|-------|----------------|--------------|
| `package.json` + `pnpm-lock.yaml` | Node.js (pnpm) | `pnpm install && pnpm run dev` | 5173, 3000 |
| `package.json` + `package-lock.json` | Node.js (npm) | `npm install && npm run dev` | 5173, 3000 |
| `package.json` + `yarn.lock` | Node.js (yarn) | `yarn install && yarn dev` | 5173, 3000 |
| `pyproject.toml` + `uv.lock` | Python (uv) | `uv sync && uv run <entrypoint>` | 8000 |
| `pyproject.toml` + `poetry.lock` | Python (poetry) | `poetry install && poetry run <entrypoint>` | 8000 |
| `go.mod` | Go | `go run .` or `make dev` | 8080 |
| `docker-compose.yml` | Docker | `docker-compose up -d` | Parse from compose |
| `Makefile` with `dev:` target | Make-based | `make dev` | Infer from Makefile |

### Entrypoint Discovery

**Python:**
```bash
grep -rn "@app\.\(get\|post\|put\|delete\|patch\)" --include="*.py" | head -20
grep -rn "@router\.\(get\|post\|put\|delete\|patch\)" --include="*.py" | head -20
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
```

Build a map of:
- API endpoints: method + path + file:line
- UI routes: path + component + file:line

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
