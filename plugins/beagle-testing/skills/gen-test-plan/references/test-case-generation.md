# Test Case Generation

This reference keeps the long test-template examples and prioritization guidance out of `SKILL.md`.

## Step 5: Generate Test Cases

Before generating test cases, answer: "What does this change do for the end user?"

Generate tests in this order:

1. Core functionality tests first - exercise the primary behavioral change through a user-facing entry point.
2. Configuration/admin tests second - support the feature but do not replace the core test.

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
    <Natural language description of expected behavior>
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

### Test Case Guidelines

- At least one test per affected entry point
- API tests for backend-only changes
- Browser tests for UI changes - always use real CLI commands
- Both when full-stack changes
- Include authentication steps if endpoints are protected
- Always snapshot before interacting and re-snapshot after navigation or DOM changes

## Step 6: Write YAML Test Plan

Create `docs/testing/test-plan.yaml` with metadata, setup, health checks, and the generated tests.

## Step 7: Report Summary

Report the generated file, detected stack, tests generated, entry-point coverage, and next steps.

## Step 8: Verification

Verify the YAML file exists, parses successfully, and includes the required top-level keys.
