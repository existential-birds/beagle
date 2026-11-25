# Test Case Generation

This reference keeps the long test-template examples and prioritization guidance out of `SKILL.md`.

## Critical: E2E Only

Every test case must exercise the **real built artifact** — the actual binary, server, or UI — exactly as a human QA tester would. A test case that invokes the project's automated test runner (`cargo test`, `pytest`, `npm test`, `go test`, `mix test`, etc.) is **never valid**. Those tests already run in CI. The purpose of this plan is to verify behavior that automated tests cannot: real end-to-end workflows through the actual user interface (CLI, HTTP, browser).

## Step 5: Generate Test Cases

Before generating test cases, answer: "What does this change do for the end user?"

Then ask: "How would a human tester — who has never seen the code — verify this works?"

Generate tests in this order:

1. Core functionality tests first - exercise the primary behavioral change through the actual user-facing interface.
2. Configuration/admin tests second - support the feature but do not replace the core test.

### CLI Applications (shell tests)

```yaml
- id: TC-XX
  name: <Describe what user action this represents>
  context: |
    <Which files changed and why this subcommand is affected>
  steps:
    # Build the binary first (or reference it from setup.build)
    - run: <invoke the CLI binary with real arguments>
    - run: <verify the effect — check stdout, query database, inspect files>
  expected: |
    <Exit code, stdout content, side effects (files created, DB rows, etc.)>
```

**CLI test examples by scenario:**

```yaml
# Subcommand that writes to a database
- id: TC-01
  name: "volant plan creates a workflow in PostgreSQL"
  steps:
    - run: ./target/debug/volant plan "Fix login bug" --description "Users can't log in" --sandbox local
    - run: psql "${DATABASE_URL}" -c "SELECT id, state FROM workflows ORDER BY created_at DESC LIMIT 1"
  expected: |
    Exit code 0. A new workflow row exists with state 'pending' or further.

# Subcommand that outputs to stdout
- id: TC-02
  name: "volant status lists workflows"
  steps:
    - run: ./target/debug/volant status --all
  expected: |
    Exit code 0. Outputs a table or list of workflows. Does not crash on empty database.

# Subcommand with --dry-run
- id: TC-03
  name: "volant run --dry-run validates without executing"
  steps:
    - run: ./target/debug/volant run example.toml --dry-run
  expected: |
    Exit code 0. Prints the resolved workflow structure. Does not execute any nodes.

# Error handling — missing config
- id: TC-04
  name: "volant plan errors gracefully without API key"
  steps:
    - run: env -u ANTHROPIC_API_KEY ./target/debug/volant plan "test" 2>&1 || true
  expected: |
    Non-zero exit code. Stderr contains a meaningful error about missing configuration,
    not a panic or stack trace.
```

### API Endpoints (curl tests)

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
    <HTTP status code, response body shape, side effects>
```

### Database Verification

```yaml
- id: TC-XX
  name: <Describe what data change this verifies>
  context: |
    <Which migration or data-writing code changed>
  steps:
    - run: <command that triggers the data write>
    - run: psql "${DATABASE_URL}" -c "<SQL query to verify>"
  expected: |
    <Expected rows, column values, or schema state>
```

**Database test examples:**

```yaml
# Migration applies cleanly
- id: TC-05
  name: "Session tables migration creates expected schema"
  steps:
    - run: psql "${DATABASE_URL}" -c "\dt sessions"
    - run: psql "${DATABASE_URL}" -c "\d sessions"
  expected: |
    The 'sessions' table exists with columns matching the migration definition.

# Data roundtrip through the application
- id: TC-06
  name: "Checkpoint save and resume preserves workflow state"
  steps:
    - run: ./target/debug/volant plan "test checkpoint" --sandbox local
    - run: psql "${DATABASE_URL}" -c "SELECT workflow_id, state FROM checkpoints ORDER BY created_at DESC LIMIT 1"
  expected: |
    A checkpoint row exists for the workflow with the expected state payload.
```

### UI Routes (agent-browser CLI tests)

```yaml
- id: TC-XX
  name: <Describe the user journey>
  context: |
    <Which files changed and why this route is affected>
  steps:
    - run: agent-browser open http://localhost:<port>/<path>
    - run: agent-browser snapshot -i
      note: Capture interactive elements with refs
    - run: agent-browser fill @<ref> "<test value>"
    - run: agent-browser click @<ref>
    - run: agent-browser wait --url "**/<expected-path>"
    - run: agent-browser snapshot -i
      note: Verify final state
    - run: agent-browser screenshot docs/testing/evidence/tc-XX.png
  expected: |
    <Natural language description of expected behavior>
  evidence:
    screenshot: docs/testing/evidence/tc-XX.png
```

### Process Lifecycle (TUI / long-running)

```yaml
- id: TC-XX
  name: <Describe the process behavior>
  steps:
    # Start the process in background, give it time to initialize, then verify
    - run: timeout 5 ./target/debug/volant 2>&1 || true
    - run: <verify it started correctly — check stderr output, temp files, etc.>
  expected: |
    Process starts without crash. Produces expected initial output.
    Exits cleanly on timeout/interrupt.
```

### Test Case Guidelines

- **Never invoke the project's test runner** — every step must be a real user action
- At least one test per affected user-facing entry point
- CLI tests for command-line tools — invoke the binary directly
- curl tests for HTTP servers
- Browser tests for web UIs — always use real `agent-browser` CLI commands
- Database tests when migrations or data-writing code changed
- Include authentication/config steps if commands require credentials
- Test error paths — missing config, bad input, unreachable services
- Always snapshot before interacting and re-snapshot after navigation or DOM changes

## Step 6: Write YAML Test Plan

Create `docs/testing/test-plan.yaml` with metadata, setup, prerequisites, and the generated tests.

## Step 7: Report Summary

Report the generated file, detected stack, tests generated, entry-point coverage, and next steps.

## Step 8: Verification

Verify the YAML file exists, parses successfully, and includes the required top-level keys.

**Additional verification:** Grep every `run:` step for test runner commands (`cargo test`, `pytest`, `npm test`, `go test`, `mix test`, `jest`, `vitest`). If any are found, the plan fails — replace with real E2E actions.
