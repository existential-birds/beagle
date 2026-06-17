# Daydream review bot — workflow templates

Three GitHub Actions workflows that turn daydream into a self-hosted PR review
bot: a PR gets reviewed automatically on open (or on demand via
`@<bot> review`) and the findings are posted as inline comments by your own
GitHub App identity — no maintainer server, no third-party service.

| File | Workflow | Role |
|---|---|---|
| `daydream-review.yml` | Daydream Review | Phase A — runs the reviewer over the PR head (unprivileged), uploads a `daydream-findings` artifact |
| `daydream-command.yml` | Daydream Command | Gatekeeper — listens for `@<bot> review` PR comments and dispatches Daydream Review |
| `daydream-post.yml` | Daydream Post | Phase B — fires when Daydream Review completes, validates the artifact, posts findings as your App bot |

## Install

1. **Register a GitHub App** (or reuse the one from your daydream App setup)
   and install it on the target repository. The App must request these
   repository permissions:
   - **Pull requests: read & write** — posting and minimizing review comments
   - **Contents: read** — required by the posting token's least-privilege trio
   - **Metadata: read** — implicit baseline
   - **Actions: read & write** — the command workflow mints a dispatch token
     with `actions: write`, because a `workflow_dispatch` made with the
     built-in `GITHUB_TOKEN` never fires the downstream `workflow_run`
     trigger, so the post workflow would never run on the `@<bot> review`
     path. (Chain verified PAT-vs-`GITHUB_TOKEN`; final live confirmation of
     the App-token dispatch is tracked for the sandbox acceptance run.)
2. **Copy the three workflow files** into the target repository's
   `.github/workflows/` directory.
3. **Add three repository secrets** (Settings → Secrets and variables →
   Actions → Secrets):
   - `DAYDREAM_APP_ID` — the App's numeric ID
   - `DAYDREAM_APP_PRIVATE_KEY` — the App's PEM private key, pasted verbatim
   - `OPENAI_API_KEY` — used only by the unprivileged review job (the Codex
     backend authenticates the Codex CLI with this key)
4. **Add one repository variable** (Settings → Secrets and variables →
   Actions → Variables):
   - `DAYDREAM_BOT_HANDLE` — the mention handle the command workflow matches,
     without the `@` (e.g. `daydream-review` for `@daydream-review review`)
   - Optional: `DAYDREAM_AUTO_REVIEW` — set to `false` to disable auto-review
     on PR open; the `@<bot> review` command keeps working.

## Trigger matrix

| Trigger | Path | Notes |
|---|---|---|
| PR `opened` / `ready_for_review` | auto: Review → Post | Same-repo PRs only; disabled when `DAYDREAM_AUTO_REVIEW` is `false` |
| `@<bot> review` PR comment | on demand: Command → Review → Post | Comment author must be OWNER / MEMBER / COLLABORATOR; bot comments are ignored |
| Fork PRs | `@<bot> review` only by default | Auto-review is gated to same-repo PRs (fork runs get no secrets, so the reviewer cannot run) |

**Private-repo limitation:** on private repositories GitHub runs **no
workflows at all** for fork PRs (the "run workflows from fork pull requests"
policy is off by default), so fork PRs there get no auto-review of any kind —
only the `@<bot> review` command path can serve them.

## Security model — the privilege split

No single job ever holds both PR code and the App private key:

- **Phase A (Daydream Review)** checks out and analyzes untrusted PR code,
  so it is unprivileged: `contents: read` GITHUB_TOKEN, `OPENAI_API_KEY`
  as its only secret, no App material anywhere. Its output is a passive data
  artifact (`findings.json`), never code.
- **Daydream Command** never checks out code, so it may hold App credentials:
  it mints a short-lived App token with exactly `actions: write` to dispatch
  the review (see Install step 1).
- **Phase B (Daydream Post)** holds the App key but only ever checks out the
  base repo's default branch (trusted code). It mints a token with exactly
  `pull-requests: write, contents: read, metadata: read`, downloads the
  artifact, validates it against a strict schema and against the live PR
  (declared head SHA must match — a forged artifact cannot redirect the post),
  and posts. Untrusted values reach shells via `env:` only, never `${{ }}`
  interpolation.

The binding security spec is the daydream repo's
`.beagle/concepts/self-hosted-review-bot/roadmap.md` §"Sub-project #2
security design — the privilege split"; these templates implement it.

## Dedup limitations (v1)

Re-reviews deduplicate against the bot's own prior comments via hidden
fingerprint markers in each comment body:

- **Exact fingerprint match only.** Identity is file + normalized title +
  anchors + normalized description. A finding whose message drifts between
  runs reads as one stale finding plus one new finding — expect an occasional
  duplicate with rephrased wording.
- **Matched findings are left untouched** — no comment editing.
- **Stale findings are minimized as OUTDATED**, not thread-resolved: GitHub
  App installation tokens cannot call `resolveReviewThread` at this permission
  scope, so the prior comment is collapsed via `minimizeComment(classifier:
  OUTDATED)` instead. The thread itself stays unresolved.
- **A finding that reappears after a human minimized/dismissed it is treated
  as matched** — the bot respects the dismissal and does not re-post.
- **Body-only (non-inline) findings have no thread**; when stale they simply
  stop appearing in the next run's review body.

Comment format is unchanged from `daydream --comment` — these workflows add
triggers and posting identity, not a new output format.
