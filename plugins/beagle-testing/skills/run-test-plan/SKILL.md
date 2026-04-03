---
description: Execute YAML test plan, stop on first failure, output rich debug prompt
name: run-test-plan
disable-model-invocation: true
---

# Run Test Plan

Execute a YAML test plan, run setup commands, health checks, and each test sequentially. Stop on first failure with rich debug output.

## Prerequisites

- **agent-browser skill**: Browser tests require the `agent-browser:agent-browser` skill to be available

## Arguments

- `--plan <path>`: Path to test plan (default: `docs/testing/test-plan.yaml`)
- `--skip-setup`: Skip setup commands and health checks (for re-running after failure)

## Step 1: Parse Test Plan

Read and validate the test plan:

```bash
# Check file exists
ls docs/testing/test-plan.yaml || { echo "Error: Test plan not found"; exit 1; }

# Validate YAML
python3 -c "import yaml; yaml.safe_load(open('docs/testing/test-plan.yaml'))" || { echo "Error: Invalid YAML"; exit 1; }
```

Extract from the YAML:
- `setup.commands`: List of setup commands
- `setup.health_checks`: List of URLs to poll
- `tests`: Array of test cases

## Step 2: Run Setup (unless --skip-setup)

### 2a. Check Prerequisites

If `setup.prerequisites` exists, verify each one:

```bash
# For each prerequisite in setup.prerequisites
<prerequisite.check> || { echo "Prerequisite not met: <prerequisite.name>"; exit 1; }
```

### 2b. Set Environment Variables

If `setup.env` exists, export each variable. Variables using `${VAR}` syntax should be resolved from the current environment:

```bash
# For each key/value in setup.env
export <key>="<value>"
```

### 2c. Build

If `setup.build` exists, execute build commands sequentially:

```bash
# For each command in setup.build
<command> || { echo "Build failed: <command>"; exit 1; }
```

### 2d. Start Services

If `setup.services` exists, start long-running processes and wait for health checks:

```bash
# For each service in setup.services
nohup <service.command> > .beagle/service-<index>.log 2>&1 &
echo $! > .beagle/service-<index>.pid
```

For each service with a `health_check`, poll until ready:

```bash
timeout=<service.health_check.timeout or 30>
url=<service.health_check.url>
elapsed=0

while [ $elapsed -lt $timeout ]; do
  if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -qE "^(200|301|302)"; then
    echo "✓ Health check passed: $url"
    break
  fi
  sleep 2
  elapsed=$((elapsed + 2))
done

if [ $elapsed -ge $timeout ]; then
  echo "✗ Health check timeout: $url"
  exit 1
fi
```

### 2e. Legacy Setup Format

If the plan uses the older flat format (`setup.commands` + `setup.health_checks` instead of `prerequisites`/`build`/`services`), fall back to executing `setup.commands` sequentially and polling `setup.health_checks` as before.

## Step 4: Execute Tests Sequentially

For each test in the plan:

### 4a. Log Test Start

```markdown
## Running: TC-XX - <test.name>

Context: <test.context>
```

### 4b. Execute Steps

For each step in `test.steps`, determine the step type and execute accordingly:

**Shell commands (`run:` steps):**

The most common step type. Execute the command via Bash and capture stdout, stderr, and exit code:

```bash
# Execute the command, capture output and exit code
<command> 2>&1
echo "EXIT_CODE: $?"
```

Capture all output for evaluation in step 4c. Shell steps cover:
- CLI binary invocations (e.g., `./target/debug/myapp status --all`)
- Database queries (e.g., `psql "${DATABASE_URL}" -c "SELECT ..."`)
- File inspection (e.g., `ls -la /path/to/expected/output`)
- Process lifecycle checks (e.g., `timeout 5 ./myapp 2>&1 || true`)
- Any other command a human would type in a terminal

**curl actions (`action: curl` steps):**

```bash
curl -X <method> \
  -H "Content-Type: application/json" \
  <additional headers> \
  -d '<body>' \
  "<url>" \
  -o response.json \
  -w "%{http_code}" > status_code.txt

# Capture response for evaluation
cat response.json
cat status_code.txt
```

**agent-browser CLI actions:**

Steps starting with `agent-browser` are browser automation commands:

```bash
# Navigate
agent-browser open <url>

# Snapshot interactive elements (always do before interacting)
agent-browser snapshot -i

# Interact using refs from snapshot output (@e1, @e2, etc.)
agent-browser fill @<ref> "<value>"
agent-browser click @<ref>

# Wait for conditions
agent-browser wait --url "<pattern>"
agent-browser wait --text "<text>"
agent-browser wait --load networkidle

# Capture evidence
agent-browser screenshot docs/testing/evidence/<test.id>.png
```

**Important:** Always run `agent-browser snapshot -i` before interacting with elements to get valid refs, and re-snapshot after navigation or significant DOM changes.

Save screenshots to `docs/testing/evidence/<test.id>.png`

### 4c. Evaluate Result

Using agent reasoning, compare actual outcome against `test.expected`:

- Read the expected behavior description
- Compare with actual response/screenshot
- Determine PASS or FAIL

### 4d. On PASS

```markdown
✓ TC-XX PASSED: <test.name>
```

Continue to next test.

### 4e. On FAIL

Stop immediately. Go to Step 6.

## Step 5: On All Tests Pass

```markdown
## Test Results: ALL PASSED

| ID | Name | Result |
|----|------|--------|
| TC-01 | <name> | ✓ PASS |
| TC-02 | <name> | ✓ PASS |
| ... | ... | ... |

**Total:** N/N tests passed

### Evidence

Screenshots saved to `docs/testing/evidence/`

### Cleanup

Stopping background services...
```

Clean up:
```bash
# Kill background services
for pidfile in .beagle/service-*.pid .beagle/dev-server.pid; do
  if [ -f "$pidfile" ]; then
    kill $(cat "$pidfile") 2>/dev/null
    rm "$pidfile"
  fi
done
```

## Step 6: On Failure - Generate Debug Prompt

When a test fails, generate rich debug output:

### 6a. Gather Context

```bash
# Get changed files relevant to the failure
git diff --name-only $(git merge-base HEAD origin/main)..HEAD

# Get recent changes in files mentioned in test.context
git diff $(git merge-base HEAD origin/main)..HEAD -- <relevant_files>
```

### 6b. Output Debug Report

```markdown
## Test Failure: TC-XX - <test.name>

### What Failed

**Test:** <test.name>
**Expected:**
<test.expected>

**Actual:**
<Describe what actually happened - response code, error message, screenshot description>

### Relevant Changes in This PR

<For each file mentioned in test.context or related to the failure:>
- `<file>` (lines X-Y) - <brief description of changes>

### Evidence

<If screenshot exists:>
- Screenshot: `docs/testing/evidence/<test.id>.png`

<If API response:>
- Status code: <code>
- Response body:
```json
<response>
```

### Error Details

<If error message in response or logs:>
```
<error message>
```

### Suggested Investigation

<Based on the error, suggest 2-3 specific things to check:>
1. <First thing to check based on error type>
2. <Second thing related to changed files>
3. <Third thing about environment/setup>

### Debug Session Prompt

Copy this to start a new Claude session:

---
I'm debugging a test failure in branch `<branch>`.

**Test:** <test.name>
**Error:** <brief error description>

<Summarize what the test was checking and what went wrong>

Relevant files:
<List changed files related to this test>

Help me investigate why <specific failure reason>.
---
```

### 6c. Preserve Evidence

```bash
# Ensure evidence directory exists
mkdir -p docs/testing/evidence

# Save failure context
cat > docs/testing/evidence/<test.id>-failure.md << 'EOF'
# Failure Report: <test.id>

<Full debug report content>
EOF
```

### 6d. Cleanup and Exit

```bash
# Kill background services
for pidfile in .beagle/service-*.pid .beagle/dev-server.pid; do
  if [ -f "$pidfile" ]; then
    kill $(cat "$pidfile") 2>/dev/null
    rm "$pidfile"
  fi
done
```

## Test Results Summary Table

Always output a summary table showing progress:

```markdown
## Test Results

| ID | Name | Result |
|----|------|--------|
| TC-01 | <name> | ✓ PASS |
| TC-02 | <name> | ✗ FAIL |
| TC-03 | <name> | - SKIP |

**Passed:** 1/3
**Failed:** TC-02
```

Tests after a failure are marked as SKIP (not executed).

## Verification

Before completing:

```bash
# Verify evidence directory exists
ls -la docs/testing/evidence/

# List captured evidence
ls docs/testing/evidence/*.png docs/testing/evidence/*.md 2>/dev/null
```

**Verification Checklist:**
- [ ] Setup commands executed successfully
- [ ] Health checks passed before test execution
- [ ] Each executed test has recorded result
- [ ] Evidence captured in `docs/testing/evidence/`
- [ ] On failure: debug prompt includes expected vs actual
- [ ] On failure: relevant PR changes listed
- [ ] Background processes cleaned up

## Rules

- Stop on first test failure (do not continue to other tests)
- Always capture evidence (screenshots, responses)
- Include file:line references in debug prompts when possible
- Use `--skip-setup` flag to re-run after fixing issues
- Never hardcode secrets - use environment variables
- Clean up background processes even on failure
- Preserve failure evidence for debugging
- Make debug prompts copy-paste ready for new sessions
