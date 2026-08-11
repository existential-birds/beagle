# Dead Code Criteria (language-neutral)

Detection criteria for dead code and cleanup opportunities commonly left by LLM coding agents. Everything here applies in any language.

Worked BAD/GOOD examples live in a separate per-language file. Load [examples/python/dead-code.md](examples/python/dead-code.md) **only** when the code under review is Python. For any other language, apply the criteria below directly — the patterns are structural, not syntactic.

## 1. Unused Code

**What to look for:** functions, types, and variables with no references anywhere in the codebase.

| Sub-pattern | Signal |
|---|---|
| Unused function | Defined, exported or not, with zero call sites |
| Unused type | Class/struct/interface/enum never constructed or referenced in a signature |
| Unused module-level binding | Constant or global assigned and never read |
| Unused local | Assigned inside a function, then never used before return |
| Unreachable code | Statements after an unconditional return, throw, panic, or exit |

**How to find:**

1. "Find usages" / go-to-references in an editor or language server.
2. The language's own dead-code tooling — an unused-symbol linter, an unused-import check, or the compiler's own dead-code warnings where the language has them.
3. Direct search for the symbol name across the repo.
4. Unused-import detection, which is usually the cheapest true positive in this category.

**Before flagging:** a symbol reachable only through reflection, dynamic dispatch by name, serialization, DI registration, or a framework's string-keyed routing is **not** dead. Search for the name as a string literal, not just as an identifier.

## 2. TODO/FIXME Comments

**What to look for:** comments marking incomplete work, technical debt, or known issues. The marker set is near-universal across languages; only the comment syntax changes.

| Marker | Meaning | Action |
|--------|---------|--------|
| TODO | Planned work | Complete or create a ticket |
| FIXME | Known bug | Fix, or document as a known issue |
| HACK | Workaround | Refactor, or document why it is needed |
| XXX | Needs attention | Review and address |
| NOTE | Information | Review whether still relevant |

An LLM-authored TODO is frequently a placeholder for work the agent chose not to do, not a considered deferral. Age and specificity separate the two: a TODO naming a ticket is a deferral, a TODO naming an aspiration is a gap.

## 3. Backwards Compatibility Cruft

**What to look for:** code kept "just in case" for a compatibility requirement that no longer exists.

| Sub-pattern | Signal |
|---|---|
| Unused renames | Bindings renamed with `_unused`, `_old`, `_deprecated`, `_legacy` prefixes or suffixes |
| Legacy-suffixed functions | `process_old`, `validateLegacy`, `handlerV1` with no remaining callers |
| Compatibility re-exports | An export whose only purpose is to keep an old import path working |
| Removal comments | Commented-out code annotated "removed", "legacy", "deprecated" |
| Empty compatibility stubs | A type or function retained with an empty body so old call sites still link |

**How to evaluate:**

1. Does the "legacy" code have any callers?
2. Is the deprecated name still imported anywhere?
3. Are deprecation warnings ever actually triggered?
4. How long has it been deprecated? Check git history — an item deprecated across several releases with no removal is cruft, not a migration in progress.

## 4. Orphaned Tests

**What to look for:** tests referencing code that no longer exists.

| Sub-pattern | Signal |
|---|---|
| Test file without source | A test file whose corresponding source file was deleted |
| Test importing deleted code | An import that fails, or resolves somewhere unintended |
| Test for moved code | A test importing from a path the symbol has since left |
| Stale skip | A skipped or ignored test whose skip reason no longer applies |

**How to find:**

1. Run the suite — import and link errors surface orphans immediately.
2. Compare test file names against source file names.
3. Review test imports for deleted modules.
4. List skipped/ignored tests and read their reasons.

## Review Questions

1. Are there functions with zero call sites, including string-keyed and reflective ones?
2. How old are the TODO/FIXME comments, and do they name concrete work?
3. Is "deprecated" code actually on a deprecation timeline, or just abandoned?
4. Do all test files have corresponding source files?
5. Are there bindings assigned but never read?
