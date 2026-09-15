---
name: refactor-repo
description: Analyze repos and file evidence-backed refactoring issues.
disable-model-invocation: true
---

# Repository Refactoring Proposals

Analyze a large repository and turn verified changeability problems into scoped GitHub issues using Fowler's refactorings and applicable framework-review guidance. This workflow proposes work; it does not edit production code, implement issues, delete artifacts, or start a PR pipeline, and its helper uses Python's standard library plus Git and authenticated GitHub CLI.

## When to Use

- "Analyze this repo and create issues for worthwhile refactors."
- "Find architecture and maintainability hotspots across this monorepo."
- "Build a Fowler-based refactoring backlog."
- "Audit this repository for refactoring opportunities, drafts only."
- "Resume the refactoring survey and publish the accepted proposals."

## Prerequisites

- Python 3.10+, Git, and `gh` on PATH; check through `terminal` with `python --version`, `git --version`, and `gh --version`.
- Authenticate GitHub CLI through its normal setup; use `gh auth status`, never read credential files or print tokens.
- Explicit local repository and GitHub `OWNER/REPO`, verified against the intended remote before publishing.
- Load the `fowler-refactoring` knowledge base from this marketplace (see [Supporting files](#supporting-files)); load relevant Fowler chapters before choosing mechanics.
- Discover framework reference skills from this marketplace's catalog and read their `SKILL.md` when a stack matches. Missing optional framework skills are a recorded limitation, not permission to invent them.
- Use a durable campaign workspace outside the inspected source tree. No additional Python dependencies, environment variables, or original PDF are required.

## How to Run

Examples of user invocation (instructions given to the agent through its own skill invocation mechanism, e.g. a namespaced plugin slash command where the host uses namespaces, or the bare skill name elsewhere):

- `refactor-repo` on `/path/to/repo`, create GitHub issues for `OWNER/REPO`
- `refactor-repo` on `/path/to/repo`, drafts only; focus on services and shared domain code

Tool names in this and related files (`terminal`, `read_file`, `search_files`, `patch`, `write_file`) denote capabilities — shell execution, file reading, content search, scoped edits, and file writing — and map to the host agent's native equivalents; they are not a required product.

Creating this skill is not an instruction to execute a survey or publish issues. A survey request without publication wording defaults to drafts; an explicit request to create/file issues authorizes publication of accepted, in-scope proposals without another blanket confirmation.

Resolve this skill's directory from the loaded skill location; all paths below are relative to it. Invoke `scripts/repo_refactor.py` through `terminal`; paths are placeholders to substitute, not literal repository defaults. Use `write_file` for the campaign's proposals and coverage JSON, and `read_file` to inspect saved artifacts.

## Quick Reference

- `python <skill-dir>/scripts/repo_refactor.py snapshot --repo OWNER/REPO --out <campaign>/github.json`
- `python <skill-dir>/scripts/repo_refactor.py inventory --root <repo> --ref <snapshot-sha> --out <campaign>/inventory.json`
- `python <skill-dir>/scripts/repo_refactor.py prepare --inventory <campaign>/inventory.json --snapshot <campaign>/github.json --proposals <campaign>/proposals.json --coverage <campaign>/coverage.json --out <campaign>/drafts`
- `python <skill-dir>/scripts/repo_refactor.py publish --draft <campaign>/drafts/<id>.json --confirm-repo OWNER/REPO`
- `python <skill-dir>/scripts/test_repo_refactor.py`

## Procedure

1. **Resolve scope and pin the source.** Verify the GitHub target, repository instructions, and requested exclusions. The snapshot defaults to GitHub's current default branch; `snapshot --ref <branch>` is available only for an explicitly chosen branch. Inventory that exact commit with `--ref <snapshot-sha>`. If it is absent locally, arrange an authorized fetch or alternate checkout; do not substitute an unrelated HEAD. Read pinned files via `git show <sha>:<path>` through `terminal` when the working tree differs, otherwise use `read_file`. Never mix dirty worktree lines with commit permalinks.
2. **Inventory before judgment.** The helper enumerates tracked blobs without reading contents, excluding credential-like paths, dependency/build output, common generated files, symlinks, submodules, and large/non-text candidates. Review the exclusion summary and add explicit `--exclude <glob>` arguments when needed. Inventory is metadata, not semantic review. Read manifests, package boundaries, architecture decisions, tests, and canonical generated-code sources. Metrics identify where to look; they never prove a refactoring is justified.
3. **Plan bounded analysis shards.** Partition the included file list by actual package/service ownership, not arbitrary line chunks. Give every primary path one shard owner; keep a separate cross-cutting pass for shared contracts and dependency direction. For a durable large scan, split analysis into shards with one adjudicator and one publisher using the coordination layer's durable task cards and dependency edges when available; otherwise run the same stages sequentially in one session. See [analysis protocol](references/analysis-protocol.md). Never dispatch implementation as a side effect of creating proposals.
4. **Investigate four lenses.** For each shard examine duplicated domain knowledge, responsibility placement/change coupling, state and API boundaries, and unnecessary indirection/speculative structure. Apply the same evidence, risk, reuse, quality, efficiency, and root-cause discipline used by the marketplace review skills, without taking on their edit phases or diff-only scope. Load framework-specific reference skills for the detected stack; do not run a diff-only review workflow and call it a repo-wide scan. Keep bug fixes and unmeasured performance claims outside the refactoring issue batch.
5. **Build evidence, not smell counts.** Read full enclosing symbols, callers, tests, and history for each candidate. Record exact paths/lines at the pinned SHA, the demonstrated maintenance cost, framework conventions, and reasons the current boundary might be intentional. Prefer current change requests, recurring co-changes, duplicated policy, or proven propagation costs over hypothetical future flexibility. Use `git log` and `git blame` through `terminal` with scoped paths; do not publish personal author information.
6. **Adjudicate independently.** Re-read the candidate id and evidence from disk before deciding. Require a specific problem, useful changeability benefit, named Fowler moves, small behavior-preserving steps, explicit invariants, tests, alternatives (including doing nothing), acceptance criteria, and non-goals. Check compatibility, identity, ordering, concurrency, persistence, and generated-source boundaries. A large function, loop, data record, or switch by itself is not an issue. Only high-confidence accepted candidates advance; others retain reasons as rejected, duplicate, or needs-evidence.
7. **Deduplicate and package.** Snapshot all issues in all states using full pagination; this endpoint also supplies PR records. Compare proposals semantically with open work and relevant closed decisions, fetching linked issue/PR details when needed. Group one root cause and coherent implementation scope per issue, not one ticket per occurrence. The stable key must identify the root cause and ownership scope, never line numbers, scan dates, or base SHA. Reuse an existing issue without silently editing, commenting, reopening, or closing it. Closed duplicates require an explicit new rationale and decision before new work is filed.
8. **Write the campaign artifacts.** Persist proposals using [the contract](references/artifact-contract.md) and coverage with separate triaged, deeply read, and skipped paths. Every included path must be accounted for before preparation; missing coverage blocks publishing rather than being called exhaustive. Record cross-shard analysis and exclusions honestly. Discover existing Priority/Effort/Type labels, choose only actual applicable names, and assign a requested owner only when assignable and not overridden; otherwise explicitly leave unassigned.
9. **Prepare and inspect.** Run `prepare`, read each generated issue body, and inspect evidence permalinks at the exact commit. The helper validates structure, source paths, coverage, decisions, labels, and test-status metadata; it cannot establish semantic truth. Priority is justified by recurring change cost and exposure, not smell counts. Effort is a scope estimate, not invented hours. See [publication protocol](references/publication-protocol.md).
10. **Publish only when authorized.** One publisher owns the repository campaign. Refresh GitHub state and semantic duplicate checks before each issue. Run `publish` for each accepted draft; it rechecks remote SHA, live labels/assignees, existing stable markers/titles, and writes a journal before POST. It reads the exact created issue back and verifies title, body, state, labels, and assignees. Stop on stale evidence, API/rate-limit errors, mismatches, or ambiguous creation outcomes. Do not blindly retry POSTs or bypass an uncertain journal.
11. **Close the survey, not the proposed work.** Read campaign manifests and journal results programmatically; report included/triaged/deeply-read/skipped counts, accepted/rejected/duplicate/uncertain proposals, verified issue URLs, and gaps. Draft-only completion reports artifact paths and creates nothing on GitHub. A zero-issue outcome is valid. Never promise full-repo coverage after inspecting only ranked hotspots.

### Fowler decision rules worth keeping loaded

- Refactoring preserves behavior and improves the economics of change; feature additions and bug fixes wear a different hat.
- Divergent change means split unrelated responsibilities; shotgun surgery means collect scattered related responsibility.
- Extract for clearer intent, inline when indirection stops paying. Class versus transform depends on mutation and snapshot lifetime.
- Repeated classifications may warrant polymorphism; an isolated switch often does not.
- Eliminate stale derived state where a query can safely replace synchronization; preserve intentional snapshots and caches.
- Data with identity differs from interchangeable values. Do not merge identifiers or silently change aliasing.
- Published contracts need staged migration, not a search-and-replace proposal.
- Missing protection tests can be the first prerequisite in a proposal, but do not claim they already exist or pass.

### Supporting files

Load references on demand by reading the relative paths below.

- [Fowler Refactoring knowledge](../fowler-refactoring/SKILL.md) — decision rules and chapter mechanics behind the proposed moves.
- [Analysis protocol](references/analysis-protocol.md) — shard ownership, framework checks, evidence gates, and issue sizing.
- [Artifact contract](references/artifact-contract.md) — exact JSON fields, coverage semantics, and helper limits.
- [Publication protocol](references/publication-protocol.md) — authorization, deduplication, retry safety, labels, and readback.
- [Issue template](templates/refactoring-issue.md) — human review checklist for the generated issue body.
- `scripts/repo_refactor.py` — deterministic inventory, GitHub snapshot, draft preparation, guarded publication.
- `scripts/test_repo_refactor.py` — hermetic helper tests; no live GitHub writes.

## Pitfalls

- High churn, LOC, and coupling proxies are leads, not evidence of bad design or numeric priority scores.
- Excluding generated output does not exclude its generator/spec from investigation; propose source-side changes only.
- Full API pagination is not a transaction; refresh immediately before writes and serialize publishers across campaigns.
- Fingerprints prevent exact repeat publication, not semantic duplicates with different keys; human/agent adjudication remains mandatory.
- An unresolved pending journal is a deliberate safety stop. Recover by reading GitHub and the journal, not deleting evidence to force a retry.
- Inventory exclusions are heuristic. Record excluded submodules, generated areas, and large files as coverage limits, not reviewed code.
- Do not install or run repository scripts blindly; inspect tooling and use hermetic checks only when justified by a candidate.
- No artificial issue quota, arbitrary iteration cap, or cleanup sweep. Stop when the scoped analysis is accounted for, not when a target number of issues is filled.

## Verification

Run `python <skill-dir>/scripts/test_repo_refactor.py` through `terminal` for helper integrity; a completed survey additionally requires accounted-for coverage and exact-target readback receipts for every claimed published issue, with pending/unverified outcomes reported as such.
