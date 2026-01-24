---
description: Analyze repo, detect stack, trace changes to user-facing entry points, generate YAML test plan
---

# Generate Test Plan

Analyze the repository's tech stack, branch changes vs default, and generate an executable YAML test plan focused on user-facing impact.

## Arguments

- `--base <branch>`: Base branch to diff against (default: `main`)
- Path: Target directory (default: current working directory)

## Step 1: Gather Repository Context

```bash
# Get current branch
git rev-parse --abbrev-ref HEAD

# Get default base branch (try origin/main, then origin/master)
git rev-parse --verify origin/main >/dev/null 2>&1 && echo "main" || echo "master"

# Get changed files vs base
git diff --name-only $(git merge-base HEAD origin/main)..HEAD

# Get commit messages for context
git log --oneline $(git merge-base HEAD origin/main)..HEAD
```

**Capture:**
- `current_branch`: Branch name
- `base_branch`: Default branch to compare against
- `changed_files`: List of modified files
- `commit_messages`: What the PR is about

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
# Check pyproject.toml for scripts
grep -A5 '\[project.scripts\]' pyproject.toml 2>/dev/null

# Look for common entrypoints
ls main.py app.py server.py api/main.py src/main.py 2>/dev/null

# Check for uvicorn/gunicorn patterns
grep -r "uvicorn\|gunicorn" pyproject.toml Makefile 2>/dev/null
```

**Node.js:**
```bash
# Check package.json scripts
cat package.json | python3 -c "import sys,json; print(json.load(sys.stdin).get('scripts', {}).get('dev', ''))"

# Check for monorepo structure
ls apps/ packages/ 2>/dev/null
```

### Port Discovery

```bash
# Check .env files
grep -E "^PORT=" .env .env.example .env.local 2>/dev/null

# Check docker-compose port mappings
grep -A2 "ports:" docker-compose.yml 2>/dev/null

# Check vite.config for custom port
grep -E "port:" vite.config.ts vite.config.js 2>/dev/null
```

## Step 3: Discover User-Facing Entry Points

Grep for route definitions based on detected stack:

**Python (FastAPI/Flask):**
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

## Step 4: Trace Changes to Entry Points

For each changed file, determine if it affects user-facing functionality:

1. **Direct entry point change** - File contains route definitions
2. **Import chain analysis** - Find what imports the changed file and trace up to entry points
3. **Document the trace path** in test context

```bash
# For each changed file, find what imports it
grep -rn "from.*<module>\|import.*<module>" --include="*.py" --include="*.ts" --include="*.tsx"
```

**Output:**
For each affected entry point, document:
- Which changed files affect it
- The import/dependency chain
- Why this entry point needs testing

## Step 5: Generate Test Cases

For each affected entry point, create appropriate test cases:

### API Endpoints (curl tests)

For endpoints affected by changes:
```yaml
- id: TC-XX
  name: <Describe what user action this represents>
  context: |
    <Which files changed and why this endpoint is affected>
  steps:
    - action: curl
      method: <GET|POST|PUT|DELETE>
      url: http://localhost:<port>/<path>
      headers:
        Content-Type: application/json
      body: <JSON body if needed>
  expected: |
    <Natural language description of expected behavior>
```

### UI Routes (agent-browser tests)

For UI routes affected by changes:
```yaml
- id: TC-XX
  name: <Describe the user journey>
  context: |
    <Which files changed and why this route is affected>
  steps:
    - action: agent-browser open
      url: http://localhost:<port>/<path>
    - action: agent-browser snapshot
    - action: agent-browser fill
      ref: "@<field-name>"
      value: "<test value>"
    - action: agent-browser click
      ref: "@<button-name>"
    - action: agent-browser wait
      type: url
      value: "<expected-path>"
    - action: agent-browser snapshot
  expected: |
    <Natural language description of expected behavior>
  evidence:
    screenshot: evidence/tc-XX.png
```

### Test Case Guidelines

- At least one test per affected entry point
- API tests for backend-only changes
- Browser tests for UI changes
- Both when full-stack changes
- Include authentication steps if endpoints are protected
- Use `${ENV_VAR}` syntax for secrets/tokens

## Step 6: Write YAML Test Plan

Create the test plan file:

```bash
mkdir -p docs/testing
```

Write to `docs/testing/test-plan.yaml`:

```yaml
version: 1
metadata:
  branch: <current_branch>
  base: <base_branch>
  generated: <ISO timestamp>
  changes_summary: |
    <Summary of what this PR changes based on commit messages and diff>

setup:
  stack:
    - type: <node|python|go|docker>
      package_manager: <pnpm|npm|yarn|uv|poetry|none>
  commands:
    - <install command>
    - <run command>
  health_checks:
    - url: http://localhost:<port>/health
      timeout: 30
    - url: http://localhost:<frontend_port>
      timeout: 30

tests:
  - id: TC-01
    name: <Test name>
    context: |
      <Why this test exists, which changes affect it>
    steps:
      - <action steps>
    expected: |
      <Expected behavior in natural language>
    evidence:
      screenshot: evidence/tc-01.png
```

## Step 7: Report Summary

After generating the test plan:

```markdown
## Test Plan Generated

**File:** `docs/testing/test-plan.yaml`
**Branch:** <current_branch> → <base_branch>

### Detected Stack

| Component | Type | Port |
|-----------|------|------|
| <component> | <type> | <port> |

### Tests Generated

| ID | Name | Type | Affected By |
|----|------|------|-------------|
| TC-01 | <name> | curl/browser | <files> |

### Entry Point Coverage

- **Covered:** <N> entry points with tests
- **Unchanged:** <M> entry points not affected by this PR

### Next Steps

1. Review the generated test plan at `docs/testing/test-plan.yaml`
2. Adjust test values and expectations as needed
3. Run tests with:
   ```
   /beagle:run-test-plan
   ```
```

## Step 8: Verification

Before completing:

```bash
# Verify file was created
ls -la docs/testing/test-plan.yaml

# Validate YAML syntax
python3 -c "import yaml; yaml.safe_load(open('docs/testing/test-plan.yaml'))" && echo "Valid YAML"

# Check required fields
grep -E "^version:|^metadata:|^setup:|^tests:" docs/testing/test-plan.yaml
```

**Verification Checklist:**
- [ ] Test plan file created at `docs/testing/test-plan.yaml`
- [ ] YAML is syntactically valid
- [ ] At least one test case generated
- [ ] Setup commands match detected stack
- [ ] Health checks point to valid endpoints
- [ ] Each test has id, name, steps, and expected fields

## Rules

- Always create `docs/testing/` directory if it doesn't exist
- Generate at least one test per affected entry point
- Include context explaining why each test matters (trace from changes)
- Use natural language for `expected` field (agent will interpret)
- Default to conservative port detection (8000 for API, 5173/3000 for frontend)
- Include `agent-browser snapshot` after significant UI state changes
- Use `${ENV_VAR}` syntax for secrets, never hardcode credentials
- If no user-facing changes detected, explain why and suggest manual verification
