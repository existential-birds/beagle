# Abstraction Criteria (language-neutral)

Detection criteria for over-engineering patterns commonly introduced by LLM coding agents. Everything here applies in any language.

Worked BAD/GOOD examples live in a separate per-language file. Load [examples/python/abstraction.md](examples/python/abstraction.md) **only** when the code under review is Python. For any other language, apply the criteria below directly — substitute the local equivalents (abstract base class ≈ interface, trait, protocol, behaviour, or module signature).

## 1. Over-Abstraction

**What to look for:** abstraction layers that add indirection without providing value.

| Sub-pattern | Signal |
|---|---|
| Pass-through wrapper | A type whose every method forwards to one held dependency, unchanged |
| Single-implementation interface | An interface/trait/protocol/abstract type with exactly one implementer |
| Constant factory | A constructor function that always returns the same concrete type with no branching |
| Layer stack | Three or more layers sharing the same method signatures, each delegating down |
| Speculative extension point | An abstraction justified by "for future extensibility" with no second use in sight |

**Before flagging:** a single-implementation interface is legitimate when it exists to define a **test seam**, a module boundary a build system enforces, or a published contract other repos implement. Check for test doubles implementing it before calling it dead weight.

## 2. Copy-Paste Drift

**What to look for:** three or more near-identical blocks that should be one parameterized unit.

| Sub-pattern | Signal |
|---|---|
| Near-identical functions | Same control flow, different type or field names |
| Repeated error handling | The same try/catch/recover-and-wrap shape in every method of a client |
| Parallel type structures | Several types with the same fields and the same methods differing only in what they name |

**How to identify:**

1. Search for name families — `get_X`, `process_X`, `validate_X`, `handleX`.
2. Look for identical control flow over different variables.
3. Check for repeated error-handling shapes.
4. Compare methods across sibling types.

**Before flagging:** three occurrences is the threshold, not two. Two similar blocks that are likely to diverge are cheaper duplicated than prematurely unified. Also check whether the "duplication" spans a module boundary that exists on purpose — coupling two independent modules to remove duplication is a net loss.

## 3. Over-Configuration

**What to look for:** configuration and feature flags for things that do not actually vary.

| Sub-pattern | Signal |
|---|---|
| Never-toggled flag | A boolean with one state everywhere, guarding a branch that is therefore dead |
| Single-value environment variable | An env var read with a default, never set in any environment |
| Always-default options | A constructor or config struct whose options are never passed a non-default |
| Unread configuration | A settings field loaded but never accessed |
| Generic-for-one-caller | A parameterized implementation with exactly one call site |

**Signs of over-configuration:**

- Config values that never change across environments.
- Feature flags with only one state in production.
- Options whose defaults are always used.
- Configuration loaded but never accessed.
- Environment variables with no variation.

**Before flagging:** a flag that is currently single-valued but exists for an in-progress migration, an incident kill-switch, or a deployment-time override is doing its job. Check for the flag name in deployment manifests, CI config, and runbooks before calling it dead.

## Review Questions

1. Does this abstraction have more than one implementation, counting test doubles?
2. Are there three or more similar blocks that could be parameterized without coupling independent modules?
3. Is this configuration actually configured differently anywhere, including deployment config?
4. Would removing this layer break anything meaningful?
5. Is this factory or wrapper adding value, or only indirection?
