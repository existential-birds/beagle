---
name: llm-artifacts-detection
description: Detects common LLM coding agent artifacts in codebases. Identifies test quality issues, dead code, over-abstraction, and verbose LLM style patterns. Criteria are language-neutral; per-language examples load only when the detected language matches. Use when cleaning up AI-generated code or reviewing for agent-introduced cruft.
user-invocable: false
---

# LLM Artifacts Detection

Detect and flag common patterns introduced by LLM coding agents that reduce code quality.

## Detection Categories

| Category | Criteria (language-neutral) | Key Issues |
|----------|------------------------------|------------|
| Tests | [references/tests-criteria.md](references/tests-criteria.md) | DRY violations, library testing, mock boundaries |
| Dead Code | [references/dead-code-criteria.md](references/dead-code-criteria.md) | Unused code, TODO/FIXME, backwards compat cruft |
| Abstraction | [references/abstraction-criteria.md](references/abstraction-criteria.md) | Over-abstraction, copy-paste drift, over-configuration |
| Style | [references/style-criteria.md](references/style-criteria.md) | Obvious comments, defensive overkill, unnecessary annotations |

## What to load

Load conditionally. A run that loads all criteria and all examples pulls in reference material for categories it is not scanning and languages the repo does not contain.

**1. Detect the language.** Before loading any reference, determine the primary language of the files under review — from their extensions, plus the project's manifest (`pyproject.toml`, `package.json`, `go.mod`, `Cargo.toml`, `mix.exs`, `Package.swift`, `*.csproj`). A mixed repo may have more than one; scope per file, not per repo.

**2. Load criteria per scanned category.** For each category you are actually scanning, load its criteria file. Do not load criteria for categories outside the run's scope (`--category` narrows this).

**3. Load examples only on a language match.** Each criteria file names a companion examples file under `references/examples/<language>/`. Load it **only** when the detected language matches:

| Language | Examples available |
|----------|--------------------|
| Python | `references/examples/python/{tests,dead-code,abstraction,style}.md` |
| Everything else | None — apply the criteria file directly |

The criteria files are the authority. Examples illustrate them; they never extend them. When no examples file exists for the detected language, the criteria still apply in full — the patterns are structural, so translate the construct (interface ≈ trait ≈ protocol ≈ behaviour; docstring ≈ doc comment ≈ godoc block) rather than skipping the check.

**Do not port a Python example's syntax into a finding about another language.** A `[FILE:LINE]` citing a Python idiom in a Go file is a confabulated finding.

## Agent Prompts

Use these prompts to spawn focused detection agents. Each agent loads only its own category's criteria, plus the examples file for the detected language if one exists.

### Tests Agent

```
Analyze the test files for LLM-introduced test quality issues:

1. **DRY Violations**: Setup or teardown repeated across tests instead of a shared
   fixture, factory, or helper. Flag:
   - The same value constructed identically in three or more tests
   - Repeated test-double configuration
   - Resource setup (database, temp dir, server, client) bootstrapped inline every time

2. **Library Testing**: Tests validating the standard library or a framework rather
   than project code. Signs:
   - No imports from the project under test
   - Assertions restating documented framework behavior
   - No domain logic exercised

3. **Mock Boundaries**: Doubles placed at the wrong level:
   - Too deep: substituting private or internal helpers of the unit under test
   - Too shallow: real network, database, or filesystem calls left in a unit test
   - Wrong level: unit-test substitution inside an integration test, or vice versa

For each issue found, report: [FILE:LINE] ISSUE_TITLE
```

### Dead Code Agent

```
Scan the codebase for dead code and cleanup opportunities:

1. **Unused Code**: Functions, types, and bindings with no references:
   - Functions never called
   - Types never constructed or referenced in a signature
   - Module-level bindings never read
   - Unreachable code after an unconditional return, throw, panic, or exit
   Search the name as a string literal too — reflective and string-keyed
   registration does not appear in an identifier search.

2. **TODO/FIXME Comments**: TODO, FIXME, HACK, XXX markers indicating incomplete work

3. **Backwards Compat Cruft**: Patterns suggesting removed features:
   - Bindings renamed with _unused, _old, _deprecated, _legacy affixes
   - Re-exports existing only to keep an old import path working
   - Commented-out code annotated "removed", "legacy", "deprecated"
   - Empty types or functions kept so old call sites still link

4. **Orphaned Tests**: Tests for code that no longer exists:
   - Test files whose source file was deleted
   - Tests importing deleted modules
   - Skipped tests whose skip reason no longer applies

For each issue found, report: [FILE:LINE] ISSUE_TITLE
```

### Abstraction Agent

```
Review the codebase for over-engineering introduced by LLM agents:

1. **Over-Abstraction**: Layers adding indirection without value:
   - Types whose every method forwards to one held dependency
   - Interfaces, traits, or protocols with exactly one implementer
     (test doubles count as implementers — check before flagging)
   - Constructor functions that always return the same concrete type
   - Three or more layers sharing the same method signatures

2. **Copy-Paste Drift**: Three or more near-identical blocks that should be
   parameterized. Two is below threshold.
   - Same control flow over different type or field names
   - The same error-handling shape repeated across a client's methods
   - Parallel types with identical fields and methods

3. **Over-Configuration**: Configuration for things that do not vary:
   - Flags with one state everywhere (check deployment config and runbooks first)
   - Environment variables never set in any environment
   - Config options whose defaults are always used
   - Settings fields loaded but never read

For each issue found, report: [FILE:LINE] ISSUE_TITLE
```

### Style Agent

```
Check for verbose LLM-style patterns that reduce code clarity. This is the highest
false-positive category — apply each criterion's "before flagging" caveat.

1. **Obvious Comments**: Comments transcribing the line below them into prose.
   NOT obvious: why-comments, legal notices, issue links, spec references,
   warnings about non-obvious ordering.

2. **Over-Documentation**: Documentation weight disproportionate to the code.
   NOT over-documentation: public API surfaces, libraries, or any codebase whose
   docs are generated from source.

3. **Defensive Overkill**: Guards against failures that cannot occur.
   NOT overkill: null checks at a trust boundary receiving external input, in any
   gradually typed language where the annotation is not runtime-enforced.

4. **Unnecessary Annotations**: Type annotations adding no information.
   NOT unnecessary: anything the project's linter or compiler would fail without —
   check the linter configuration before flagging.

For each issue found, report: [FILE:LINE] ISSUE_TITLE
```

## Gates (reporting)

This is the pipeline's first stage, so it owns the single echo required by the `beagle-core:verification-budget` skill's one-echo rule: every `[FILE:LINE]` is anchored to a buffer read in this turn, and downstream stages trust that anchor rather than re-deriving it.

Findings from this stage are `verification-budget` tier **REVERSIBLE** — they authorize a report, not an edit. Anchor them, then move on; the evidence gate belongs to `verify-llm-artifacts` and `fix-llm-artifacts`, where a verdict authorizes a deletion.

1. **Anchor** — Set `FILE` and `LINE` from an opened buffer, `read_file`, or equivalent; never from a stale search snippet, the branch name, or memory. **Pass:** `LINE` is in range for `FILE`, and the described issue is visible on that line or its immediate neighbors.
2. **Title** — `ISSUE_TITLE` states the defect in plain language, about one short sentence, not a proposed fix. **Pass:** someone opening `FILE` at `LINE` can see why the title applies.
3. **Dedup** — Before final output, merge rows sharing the same `FILE:LINE` and root cause. **Pass:** at most one `[FILE:LINE] ISSUE_TITLE` per distinct defect at that anchor.

## Usage

1. Load this skill when reviewing AI-generated code.
2. Detect the language and load only the criteria and examples that apply (see **What to load**).
3. **If the agent supports subagents**, dispatch one per detection category in parallel; **otherwise** work through the categories sequentially yourself, producing the same `[FILE:LINE] ISSUE_TITLE` findings.
4. Apply **Gates (reporting)**, then emit findings as `[FILE:LINE] ISSUE_TITLE`.

## When to Apply

- Cleaning up code written by AI coding agents
- Post-generation code review
- Reducing code bloat from iterative AI generation
- Identifying patterns that reduce maintainability
