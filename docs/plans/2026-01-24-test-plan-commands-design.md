# Test Plan Commands Design

**Date:** 2026-01-24
**Status:** Approved

## Overview

Two complementary commands for generating and executing manual test plans that simulate human user behavior.

| Command | Purpose |
|---------|---------|
| `gen-test-plan` | Analyze repo, detect stack, trace changes to user-facing entry points, generate YAML test plan |
| `run-test-plan` | Execute YAML test plan, stop on first failure, output rich debug prompt |

## Workflow

```
Developer creates PR
        │
        ▼
┌─────────────────────┐
│  /beagle:gen-test-plan  │
│                     │
│  • Detect stack     │
│  • Analyze diff     │
│  • Trace to UI/API  │
│  • Generate YAML    │
└─────────────────────┘
        │
        ▼
  docs/testing/test-plan.yaml
        │
        ▼
    User reviews YAML
        │
        ▼
┌─────────────────────┐
│  /beagle:run-test-plan  │
│                     │
│  • Start services   │
│  • Execute tests    │
│  • Capture evidence │
└─────────────────────┘
        │
        ├── All pass ──► "✓ All N tests passed"
        │
        └── Failure ──► Debug prompt + evidence
                              │
                              ▼
                    New session to fix issue
```

## gen-test-plan Command

### Purpose

Analyze a repo's tech stack, changes in current branch vs default, and generate an executable YAML test plan focused on user-facing impact.

### Workflow

1. **Detect tech stack** - Scan for `package.json`, `pyproject.toml`, `docker-compose.yml`, `Makefile`, etc.
2. **Determine local run commands** - Map detected files to setup/run commands
3. **Analyze branch diff** - `git diff` against default branch, identify changed files
4. **Trace to user-facing entry points** - Find which API endpoints, UI routes, or CLI commands are affected
5. **Generate test cases** - Create test scenarios that exercise those user journeys
6. **Output YAML** - Write to `docs/testing/test-plan.yaml`

### Tech Stack Detection Rules

| File Found | Stack Detected | Setup Commands | Health Check |
|------------|----------------|----------------|--------------|
| `package.json` with `dev` script | Node.js webapp | `pnpm install && pnpm run dev` | Check for `PORT` env or default 5173/3000 |
| `package.json` + `apps/` dir | Monorepo | `pnpm install && pnpm run dev` | Multiple ports from workspace configs |
| `pyproject.toml` with `uv` | Python (uv) | `uv sync && uv run <entrypoint>` | Look for FastAPI/Flask patterns |
| `pyproject.toml` with `poetry` | Python (poetry) | `poetry install && poetry run <entrypoint>` | Look for FastAPI/Flask patterns |
| `docker-compose.yml` | Docker-based | `docker-compose up -d` | Parse exposed ports |
| `Makefile` with `dev` target | Make-based | `make dev` | Infer from Makefile |
| `go.mod` | Go | `go run .` or check Makefile | Infer from main.go |

### Entrypoint Discovery (Python)

- Look for `[project.scripts]` in pyproject.toml
- Look for `uvicorn` or `gunicorn` patterns in scripts
- Check for `main.py`, `app.py`, `server.py`

### Port Discovery

- Parse `.env`, `.env.example` for PORT variables
- Check docker-compose port mappings
- Look for hardcoded ports in config files
- Default fallbacks: 8000 (API), 5173/3000 (frontend)

## Test Plan YAML Schema

```yaml
version: 1
metadata:
  branch: feature/add-user-profile
  base: main
  generated: 2024-01-15T10:30:00Z
  changes_summary: |
    Modified user profile API endpoint and dashboard UI

setup:
  stack:
    - type: node
      package_manager: pnpm
    - type: python
      package_manager: uv
  commands:
    - pnpm install
    - uv sync
    - pnpm run dev
  health_checks:
    - url: http://localhost:8000/health
      timeout: 30
    - url: http://localhost:5173
      timeout: 30

tests:
  - id: TC-01
    name: User can view their profile
    context: |
      This PR modified api/routes/user.py which handles /api/user/profile.
      The dashboard now displays additional user fields.
    steps:
      - action: agent-browser open
        url: http://localhost:5173/login
      - action: agent-browser snapshot
      - action: agent-browser fill
        ref: "@email"
        value: "test@example.com"
      - action: agent-browser fill
        ref: "@password"
        value: "testpass123"
      - action: agent-browser click
        ref: "@submit"
      - action: agent-browser wait
        type: url
        value: "/dashboard"
      - action: agent-browser snapshot
    expected: |
      User should be redirected to /dashboard.
      Dashboard should display user's name and email.
      Profile section should show the new "member since" field added in this PR.
    evidence:
      screenshot: evidence/tc-01.png

  - id: TC-02
    name: Profile API returns correct data
    context: |
      Direct API test for the modified /api/user/profile endpoint.
    steps:
      - action: curl
        method: GET
        url: http://localhost:8000/api/user/profile
        headers:
          Authorization: "Bearer ${TEST_TOKEN}"
    expected: |
      Response should be 200 OK.
      JSON should include name, email, and the new "created_at" field.
      No sensitive fields (password hash) should be exposed.
```

## run-test-plan Command

### Purpose

Execute a YAML test plan, run each test case, stop on first failure with rich debug output.

### Workflow

1. **Parse YAML** - Load the test plan, validate schema
2. **Setup environment** - Run setup commands, wait for health checks to pass
3. **Execute tests sequentially** - For each test:
   - Log test ID and name
   - Execute each step (curl or agent-browser)
   - Capture output/screenshots as evidence
   - Have the agent evaluate the result against `expected`
   - If pass: continue to next test
   - If fail: stop immediately, generate debug prompt
4. **On success** - Report all tests passed, clean up
5. **On failure** - Generate rich debug prompt and exit

### Debug Prompt Output (on failure)

```markdown
## Test Failure: TC-02 - Profile API returns correct data

### What Failed
**Expected:** Response should be 200 OK with name, email, and created_at field.
**Actual:** Response was 500 Internal Server Error.

### Relevant Changes in This PR
- `api/routes/user.py` (lines 45-67) - Modified profile endpoint
- `api/models/user.py` (lines 12-18) - Added created_at field

### Evidence
- Screenshot: `docs/testing/evidence/tc-02.png`
- Response body:
```json
{"error": "column 'created_at' does not exist"}
```

### Suggested Investigation
1. Check if database migration for `created_at` was applied
2. Verify `api/models/user.py` matches the database schema
3. Run `alembic upgrade head` if migrations are pending

### Debug Session Prompt
Copy this to start a new Claude session:

---
I'm debugging a test failure in branch `feature/add-user-profile`.

TC-02 (Profile API returns correct data) failed with a 500 error:
"column 'created_at' does not exist"

The PR added a `created_at` field to the user model. Relevant files:
- api/routes/user.py (modified)
- api/models/user.py (modified)

Help me investigate why the database column doesn't exist.
---
```

## Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Stack detection | Convention-based | Works across repos without relying on documentation quality |
| Change analysis | User-facing impact | Tests what users experience, not just what code changed |
| Test plan format | Structured YAML | Machine-parseable for reliable execution |
| Verification | Agent-interpreted | Natural language expectations are flexible and handle edge cases |
| Failure behavior | Stop on first | Avoid cascading failures, get developer to fix immediately |
| Debug output | Rich context | Include PR changes, evidence, and ready-to-use debug prompt |

## File Locations

- Test plan output: `docs/testing/test-plan.yaml`
- Evidence directory: `docs/testing/evidence/`
- Debug prompts: Printed to stdout (copy-paste ready)

## Command Structure

```
commands/
├── gen-test-plan.md
└── run-test-plan.md
```

Commands are self-contained with all detection logic, YAML schema, and debug prompt templates embedded. No separate skills needed.

## First Use Case

Webapp monorepos (like amelia, shelfspace-mono) with:
- Frontend (React/Vite on port 5173)
- Backend (FastAPI on port 8000)
- UI testing via agent-browser
- API testing via curl
