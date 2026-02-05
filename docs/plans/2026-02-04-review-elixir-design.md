# Review Elixir Command & Skills Design

## Overview

Create a `review-elixir` command and 6 supporting skills for comprehensive Elixir/Phoenix code review, following the pattern established by `review-python`.

## Target Versions

- Elixir 1.19+
- Phoenix 1.8.3+
- LiveView 0.20+

## Command: `review-elixir`

**File**: `commands/review-elixir.md`

### Arguments

- `--parallel`: Spawn specialized subagents per technology area
- Path: Target directory (default: current working directory)

### Step 1: Identify Changed Files

```bash
git diff --name-only $(git merge-base HEAD main)..HEAD | grep -E '\.ex$|\.exs$|\.heex$'
```

### Step 2: Verify Linter/Formatter Status

```bash
# Check formatting
mix format --check-formatted

# Check Credo if present
if [ -f ".credo.exs" ] || grep -q ":credo" mix.exs; then
    mix credo --strict
fi

# Check Dialyzer if configured
if grep -q ":dialyxir" mix.exs; then
    mix dialyzer --format short
fi
```

**Rules:**
- If a linter passes for a specific rule, DO NOT flag that issue manually
- Linter configuration is authoritative for style rules
- Only flag issues that linters cannot detect (semantic issues, architectural problems)

### Step 3: Detect Technologies

```bash
# Detect Phoenix
grep -r "use Phoenix\|Phoenix.Router\|Phoenix.Controller" --include="*.ex" -l | head -3

# Detect LiveView
grep -r "use Phoenix.LiveView\|Phoenix.LiveComponent\|~H" --include="*.ex" -l | head -3

# Detect Oban
grep -r "use Oban.Worker\|Oban.insert" --include="*.ex" -l | head -3

# Check for test files
git diff --name-only $(git merge-base HEAD main)..HEAD | grep -E '_test\.exs$'
```

### Step 4: Load Verification Protocol

Load `beagle:review-verification-protocol` skill and keep its checklist in mind throughout the review.

### Step 5: Load Skills

**Always load:**
- `beagle:elixir-code-review`

**Conditionally load based on detection:**

| Condition | Skill |
|-----------|-------|
| Phoenix detected | `beagle:phoenix-code-review` |
| LiveView detected | `beagle:liveview-code-review` |
| Performance focus requested | `beagle:elixir-performance-review` |
| Security focus requested | `beagle:elixir-security-review` |
| Test files changed | `beagle:exunit-code-review` |

### Step 6: Review

**Sequential (default):**
1. Load applicable skills
2. Review Elixir quality issues first
3. Review Phoenix patterns (if detected)
4. Review LiveView patterns (if detected)
5. Review detected technology areas
6. Consolidate findings

**Parallel (--parallel flag):**
1. Detect all technologies upfront
2. Spawn one subagent per technology area with `Task` tool
3. Each agent loads its skill and reviews its domain
4. Wait for all agents
5. Consolidate findings

### Output Format

```markdown
## Review Summary

[1-2 sentence overview of findings]

## Issues

### Critical (Blocking)

1. [FILE:LINE] ISSUE_TITLE
   - Issue: Description of what's wrong
   - Why: Why this matters (bug, type safety, security)
   - Fix: Specific recommended fix

### Major (Should Fix)

2. [FILE:LINE] ISSUE_TITLE
   - Issue: ...
   - Why: ...
   - Fix: ...

### Minor (Nice to Have)

N. [FILE:LINE] ISSUE_TITLE
   - Issue: ...
   - Why: ...
   - Fix: ...

## Good Patterns

- [FILE:LINE] Pattern description (preserve this)

## Verdict

Ready: Yes | No | With fixes 1-N
Rationale: [1-2 sentences]
```

### Post-Fix Verification

```bash
mix format --check-formatted
mix credo --strict
mix dialyzer
mix test
```

---

## Skills

### 1. `elixir-code-review` (Always loaded)

**Focus**: Core Elixir patterns, OTP basics, documentation (HexDocs compliance)

**References**:
- `references/code-style.md` - Naming, formatting, module structure
- `references/pattern-matching.md` - With clauses, guards, destructuring
- `references/otp-basics.md` - GenServer, Supervisor, Application patterns
- `references/documentation.md` - @moduledoc, @doc, @spec, doctests, HexDocs

**Checklist**:
- [ ] Functions use pattern matching over conditionals where appropriate
- [ ] With clauses have else handling for error cases
- [ ] GenServers use handle_continue for expensive init work
- [ ] All public functions have @doc and @spec
- [ ] Modules have @moduledoc describing purpose
- [ ] No `String.to_atom/1` on user input
- [ ] Pipe chains start with raw data, not function calls
- [ ] Private functions grouped after public functions

### 2. `phoenix-code-review` (When Phoenix detected)

**Focus**: Controllers, contexts, routing, plugs

**References**:
- `references/contexts.md` - Bounded contexts, Ecto integration
- `references/controllers.md` - Actions, params, error handling
- `references/routing.md` - Pipelines, scopes, verified routes (~p)
- `references/plugs.md` - Custom plugs, authentication, authorization

**Checklist**:
- [ ] Business logic in contexts, not controllers
- [ ] Controllers return proper status codes
- [ ] Verified routes (~p sigil) used, not string paths
- [ ] Plugs used for cross-cutting concerns (auth, logging)
- [ ] Changesets validate all user input
- [ ] Fallback controllers handle errors consistently
- [ ] JSON APIs use proper content negotiation

### 3. `liveview-code-review` (When LiveView detected)

**Focus**: Lifecycle, assigns, streams, components

**References**:
- `references/lifecycle.md` - mount, handle_params, handle_event, handle_async
- `references/assigns-streams.md` - When to use each, temporary_assigns, AsyncResult
- `references/components.md` - Function vs LiveComponent, slots, attrs
- `references/security.md` - Validation, authorization per event

**Checklist**:
- [ ] No socket copying into async functions (extract values first)
- [ ] Subscriptions wrapped in `connected?(socket)`
- [ ] Streams used for large collections, not assigns
- [ ] Function components preferred over LiveComponents
- [ ] Every handle_event validates authorization
- [ ] phx-debounce on text inputs
- [ ] AsyncResult patterns handle :loading and :error states
- [ ] LiveComponents preserve :inner_block in update/2
- [ ] No sensitive data in assigns

### 4. `elixir-performance-review` (On request or --performance flag)

**Focus**: Process bottlenecks, memory, concurrency

**References**:
- `references/genserver-bottlenecks.md` - Mailbox overflow, blocking calls, timeouts
- `references/ets-patterns.md` - When to use ETS vs GenServer state, read/write concurrency
- `references/memory.md` - Binary handling, large message passing, process heap
- `references/concurrency.md` - Task.async, Task.Supervisor, flow control

**Checklist**:
- [ ] GenServer not a bottleneck (single process handling all requests)
- [ ] Large binaries not copied between processes unnecessarily
- [ ] ETS used for read-heavy shared state
- [ ] Task.Supervisor used for dynamic tasks (not raw Task.async)
- [ ] No unbounded process spawning
- [ ] Streams used for large data transformations
- [ ] Database queries use preloading to avoid N+1
- [ ] Pagination used for large result sets

### 5. `elixir-security-review` (On request or --security flag)

**Focus**: Language-level vulnerabilities (not Phoenix-specific)

**References**:
- `references/code-injection.md` - Code.eval_string, :erlang.binary_to_term safety
- `references/atom-exhaustion.md` - String.to_atom, :erlang.list_to_atom dangers
- `references/secrets.md` - Config handling, environment variables, no hardcoded secrets
- `references/process-exposure.md` - ETS visibility, process dictionary, registered names

**Checklist**:
- [ ] No `Code.eval_string/1` on user input
- [ ] No `:erlang.binary_to_term/1` without `:safe` option on untrusted data
- [ ] `String.to_existing_atom/1` used, never `String.to_atom/1` on external input
- [ ] Secrets loaded from environment, not hardcoded
- [ ] ETS tables use appropriate access controls (:protected/:private)
- [ ] No sensitive data in process dictionary
- [ ] No dynamic module creation from user input
- [ ] Path traversal prevented in file operations

### 6. `exunit-code-review` (When test files changed)

**Focus**: Testing patterns with boundary mocking philosophy

**Mock Boundary Rules**:
- Mock at external boundaries: HTTP clients, external APIs, third-party services
- Mock slow resources: File system, email (Swoosh), job queues (Oban)
- Mock non-deterministic: DateTime.utc_now(), :rand
- DO NOT mock: Internal modules, contexts, schemas, GenServers, PubSub

**References**:
- `references/exunit-patterns.md` - Async tests, setup, describe blocks, tags
- `references/mox-boundaries.md` - Behavior-based mocking, expectations, verify_on_exit
- `references/test-adapters.md` - Bypass, Swoosh.TestAdapter, Oban.Testing
- `references/integration-tests.md` - What to mock vs real, Ecto sandbox

**Checklist**:
- [ ] Tests are async: true unless sharing database state
- [ ] Mox used for external boundaries (HTTP clients, APIs)
- [ ] Bypass used for HTTP endpoint mocking
- [ ] Swoosh.TestAdapter used, not mocking Mailer internals
- [ ] Oban.Testing used for job assertions
- [ ] Integration tests only mock at external boundaries
- [ ] No mocking of internal modules (contexts, schemas)
- [ ] Ecto.Adapters.SQL.Sandbox for database isolation
- [ ] render_async/2 used when testing async assigns

---

## File Structure

```
commands/
└── review-elixir.md

skills/
├── elixir-code-review/
│   ├── SKILL.md
│   └── references/
│       ├── code-style.md
│       ├── pattern-matching.md
│       ├── otp-basics.md
│       └── documentation.md
├── phoenix-code-review/
│   ├── SKILL.md
│   └── references/
│       ├── contexts.md
│       ├── controllers.md
│       ├── routing.md
│       └── plugs.md
├── liveview-code-review/
│   ├── SKILL.md
│   └── references/
│       ├── lifecycle.md
│       ├── assigns-streams.md
│       ├── components.md
│       └── security.md
├── elixir-performance-review/
│   ├── SKILL.md
│   └── references/
│       ├── genserver-bottlenecks.md
│       ├── ets-patterns.md
│       ├── memory.md
│       └── concurrency.md
├── elixir-security-review/
│   ├── SKILL.md
│   └── references/
│       ├── code-injection.md
│       ├── atom-exhaustion.md
│       ├── secrets.md
│       └── process-exposure.md
└── exunit-code-review/
    ├── SKILL.md
    └── references/
        ├── exunit-patterns.md
        ├── mox-boundaries.md
        ├── test-adapters.md
        └── integration-tests.md
```

---

## Implementation Notes

### LiveView Patterns (from docs exploration)

Key anti-patterns to flag:
1. **Socket copying** - Most critical. Extract values before async functions.
2. **Missing debounce** - Text inputs without phx-debounce cause excessive events.
3. **Assigns for large collections** - Use streams instead.
4. **LiveComponent overuse** - Function components preferred for stateless UI.
5. **Missing authorization** - Every handle_event must validate permissions.
6. **Trusting phx-value** - All params are user-modifiable, validate everything.

### Testing Philosophy

Integration tests should use real implementations except at these boundaries:
- HTTP clients (use Bypass or Mox with behaviour)
- Email delivery (use Swoosh.TestAdapter)
- Background jobs (use Oban.Testing)
- Time/randomness (inject or mock)
- File I/O (mock or use tmp directories)

Everything else (database, GenServers, PubSub, contexts) should be real.

---

## References

- [Phoenix 1.8 Documentation](https://hexdocs.pm/phoenix)
- [Phoenix LiveView Documentation](https://hexdocs.pm/phoenix_live_view)
- [DeepWiki Phoenix Analysis](https://deepwiki.com/phoenixframework/phoenix)
- Existing beagle skills: review-python, python-code-review, fastapi-code-review
