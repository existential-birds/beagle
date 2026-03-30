---
name: ensure-docs
description: Verify documentation coverage and generate missing docs interactively
disable-model-invocation: true
---

# Ensure Documentation Coverage

Verify documentation coverage across a codebase, report gaps, and generate missing docs with parallel language-specific agents.

## Workflow

1. Detect languages present in the target codebase.
2. Review the detailed workflow and standards in [`references/workflow.md`](references/workflow.md).
3. Spawn parallel verification agents for each detected language.
4. Consolidate findings into a single report.
5. Offer interactive generation for any gaps the user wants to fix.
6. Verify generated docs with the appropriate linters.

## Notes

- Use `--report-only` to skip generation.
- Avoid test files unless they are test helpers.
- Keep report output aligned with the language-specific standards in the reference file.
