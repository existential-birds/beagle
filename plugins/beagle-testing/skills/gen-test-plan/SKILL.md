---
description: Analyze repo, detect stack, trace changes to user-facing entry points, generate E2E YAML test plan
name: gen-test-plan
disable-model-invocation: true
---

# Generate Test Plan

Analyze the repository's tech stack, branch changes vs default, and generate an executable YAML test plan focused on user-facing impact.

**This is an E2E test plan — not an automated test wrapper.** The generated plan will be executed by an autonomous agent acting exactly as a human QA tester would: launching real binaries, hitting real endpoints, interacting with real databases, and verifying real observable behavior.

## Critical Rule: No Automated Test Duplication

**NEVER generate test steps that re-run the project's existing automated test suite.** This means:
- No `cargo test`, `pytest`, `npm test`, `go test`, `mix test`, or equivalent commands as test steps
- No wrapping unit/integration test modules in a test case
- No "run the tests and check they pass" — that's CI's job, not QA's

If you find yourself writing a test step that invokes the project's test runner, **stop and rethink**. Ask: "What would a human tester do to verify this feature works?" The answer is never "run the unit tests."

**What E2E test steps look like:**
- Build the binary and run it with real arguments, check stdout/stderr/exit code
- Start a server and hit it with curl
- Run a CLI command that writes to a real database, then query the database to verify
- Launch the TUI and verify it renders (via screenshot or process lifecycle)
- Chain multiple commands that exercise a full user workflow end-to-end

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

See [references/stack-discovery.md](references/stack-discovery.md) for stack detection commands, entrypoint discovery, port discovery, and trace rules.

## Step 3: Discover User-Facing Entry Points

A "user-facing entry point" is anything a human interacts with: CLI subcommands, HTTP endpoints, UI routes, TUI screens, gRPC services, database migrations, or configuration files that affect runtime behavior.

### CLI Applications (Rust/clap, Python/argparse/click, Go/cobra)

```bash
# Rust (clap) — look for Subcommand derives and command enums
grep -rn "Subcommand\|#\[command\]" --include="*.rs" | head -20

# Python (click/typer/argparse)
grep -rn "@click.command\|@app.command\|add_parser\|add_subparser" --include="*.py" | head -20

# Go (cobra)
grep -rn "cobra.Command\|AddCommand" --include="*.go" | head -20
```

Build a map of:
- CLI subcommands: command name + description + file:line
- Required arguments and flags per subcommand
- Environment variables the binary reads (grep for `env`, `std::env::var`, `os.Getenv`, `os.environ`)

### HTTP/API Services

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

**Rust (axum/actix/rocket):**
```bash
grep -rn "Router::new\|\.route(\|#\[get\]\|#\[post\]\|HttpServer" --include="*.rs" | head -20
```

**Go (net/http, gin, chi):**
```bash
grep -rn "http.HandleFunc\|r.GET\|r.POST\|router.Get\|router.Post" --include="*.go" | head -20
```

**Elixir (Phoenix):**
```bash
grep -rn "get \"/\|post \"/\|pipe_through\|live \"/\|scope \"/\"" --include="*.ex" | head -20
```

### Browser UI Routes

```bash
grep -rn "createBrowserRouter\|<Route\|path=" --include="*.tsx" --include="*.jsx" | head -20
```

### Database and Migrations

```bash
# SQL migrations
ls migrations/ db/migrate/ priv/repo/migrations/ 2>/dev/null
# Schema files
ls schema.sql schema.prisma 2>/dev/null
```

### Build a consolidated map of:
- CLI subcommands: name + args + file:line
- API endpoints: method + path + file:line
- UI routes: path + component + file:line
- Database migrations: filename + what they create/alter
- Configuration: env vars and config files that affect behavior

## Step 4: Trace Changes to Entry Points

For each changed file, determine if it affects user-facing functionality:

1. **Direct entry point change** — File contains route definitions
2. **Import chain analysis** — Find what imports the changed file and trace up to entry points
3. **Architecture-aware tracing** — Read the project's CLAUDE.md, README, or architecture docs to understand data flow and module relationships, rather than relying solely on grep
4. **Document the trace path** in test context

### Import Chain Analysis by Ecosystem

```bash
# Rust — use/mod/crate references and workspace deps
grep -rn "use.*<crate>\|mod <module>" --include="*.rs"
grep -rn "<crate-name>" --include="Cargo.toml"

# Python — from/import
grep -rn "from.*<module>\|import.*<module>" --include="*.py"

# TypeScript/JavaScript — import/require
grep -rn "from.*<module>\|require.*<module>" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx"

# Elixir — alias/import/use
grep -rn "alias.*<Module>\|import.*<Module>\|use.*<Module>" --include="*.ex" --include="*.exs"

# Go — package references
grep -rn "<package>\." --include="*.go"
```

If the ecosystem is not covered above, or grep results are inconclusive, read the project's CLAUDE.md, README, or architecture docs to understand the module graph and trace the data flow from changed files to user-facing entry points.

### Classify Affected Entry Points

After identifying all affected entry points, classify each one:

| Category | Description | Examples | Priority |
|----------|-------------|----------|----------|
| **Core functionality** | Entry points where the feature does its actual work for the end user | Chat endpoint, API action, data processing pipeline, generation flow | **High — test first** |
| **Configuration/admin** | Entry points where the feature is set up, toggled, or configured | Settings page, admin dashboard, preference toggles, dropdown selections | Lower — test after core |

**Classification rules:**
- Ask: "If a user wanted to *use* this feature (not configure it), which entry point would they interact with?" — that's core functionality
- A settings page that adds a new dropdown option is configuration; the endpoint that actually *uses* that option is core functionality
- The same changed file (e.g., a new provider module) may affect both a settings page and a functional endpoint — both must be traced

**Requirement:** At least one test must target a core functionality entry point before generating configuration/admin tests. If no core functionality entry point can be identified, explicitly document why and flag this for manual review.

**Output:**
For each affected entry point, document:
- Which changed files affect it
- The import/dependency chain
- **Classification:** Core functionality or Configuration/admin
- Why this entry point needs testing

## Step 5: Generate Test Cases

See [references/test-case-generation.md](references/test-case-generation.md) for the detailed API/browser templates, prioritization rules, and test-case guidelines.

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
    - type: <rust|node|python|go|elixir|docker>
      package_manager: <cargo|pnpm|npm|yarn|uv|poetry|mix|none>
  prerequisites:
    # Services or infrastructure the tests need running
    - name: <e.g., PostgreSQL>
      check: <command to verify it's available, e.g., "pg_isready -h localhost">
  build:
    # Commands to build the project artifacts (binaries, assets, etc.)
    - <build command, e.g., "cargo build --workspace">
  services:
    # Long-running processes to start before tests (servers, watchers, etc.)
    # Omit if the project is a CLI tool or library with no server component
    - command: <start command>
      health_check:
        url: http://localhost:<port>/health
        timeout: 30
  env:
    # Environment variables needed by tests (use ${VAR} for secrets)
    DATABASE_URL: "${DATABASE_URL}"

tests:
  # CLI test example — run the built binary with real arguments:
  - id: TC-01
    name: <CLI test name>
    context: |
      <Why this test exists, which changes affect it>
    steps:
      - run: <command that a human would type in their terminal>
      - run: <follow-up command to verify the effect>
    expected: |
      <Expected behavior: exit code, stdout content, side effects>

  # API test example:
  - id: TC-02
    name: <API test name>
    context: |
      <Why this test exists, which changes affect it>
    steps:
      - action: curl
        method: GET
        url: http://localhost:<port>/<path>
    expected: |
      <Expected behavior in natural language>

  # Database verification example:
  - id: TC-03
    name: <Database test name>
    context: |
      <Why this test exists, which changes affect it>
    steps:
      - run: <command that writes to the database>
      - run: psql "${DATABASE_URL}" -c "SELECT ... FROM ... WHERE ..."
    expected: |
      <Expected rows, schema state, or migration effect>

  # Browser test example (always use agent-browser CLI commands):
  - id: TC-04
    name: <UI test name>
    context: |
      <Why this test exists, which changes affect it>
    steps:
      - run: agent-browser open http://localhost:<port>/<path>
      - run: agent-browser snapshot -i
      - run: agent-browser click @<ref>
      - run: agent-browser snapshot -i
      - run: agent-browser screenshot evidence/tc-04.png
    expected: |
      <Expected behavior in natural language>
    evidence:
      screenshot: evidence/tc-04.png
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
   /beagle-testing:run-test-plan
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
- [ ] Each test has id, name, steps, and expected fields
- [ ] **No automated test duplication:** Grep every `run:` and `command:` step in the plan for test runner invocations (`cargo test`, `pytest`, `npm test`, `go test`, `mix test`, `jest`, `vitest`, `mocha`, etc.). If ANY step invokes the project's test runner, the plan **fails verification**. Remove those steps and replace them with real E2E actions.
- [ ] **Behavioral coverage:** At least one test exercises the primary behavioral change described in `changes_summary`. Re-read the `changes_summary` and commit messages — if they describe a capability (e.g., "adds Claude Code as a new LLM provider") but no test invokes that capability (e.g., sends a message through the provider), the plan fails verification. Add the missing core functionality test before completing.
- [ ] **No config-only plans:** If all tests target configuration/admin entry points and zero tests target core functionality entry points, the plan is incomplete. Go back to Step 4, identify the core functionality entry points, and add tests for them.

## Rules

- **E2E only** — every test step must exercise the real built artifact (binary, server, UI) as a human would. Never wrap automated test suites.
- Always create `docs/testing/` directory if it doesn't exist
- Generate at least one test per affected entry point
- Include context explaining why each test matters (trace from changes)
- Use natural language for `expected` field (agent will interpret)
- **CLI projects:** Test steps should invoke the actual binary with real arguments and verify stdout, stderr, exit codes, and side effects (files created, database rows written, processes spawned)
- **Server projects:** Start the server in setup, test via curl/agent-browser
- **Library-only projects with no binary or server:** If the change is purely internal library code with no user-facing entry point (no CLI, no server, no UI), state this explicitly and generate tests that exercise the library through its public API via a small driver script — not by running the test suite
- Default to conservative port detection (8000 for API, 5173/3000 for frontend)
- **Browser automation steps MUST use `agent-browser` CLI commands** (e.g., `agent-browser open`, `agent-browser snapshot -i`, `agent-browser click @ref`) — never use abstract action syntax
- Always `agent-browser snapshot -i` before interacting with elements and after navigation/DOM changes
- Use `agent-browser screenshot <path>` to capture evidence for browser tests
- Use `${ENV_VAR}` syntax for secrets, never hardcode credentials
- If no user-facing changes detected, explain why and suggest manual verification
