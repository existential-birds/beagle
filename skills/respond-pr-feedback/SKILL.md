---
name: respond-pr-feedback
description: Posts concise, technical replies to unreplied PR review comments and resolves conversation threads via GitHub REST and GraphQL APIs. Use after evaluating feedback with fetch-pr-feedback and applying fixes.
---

# Respond to PR Feedback

Post replies to review comments after you've evaluated the feedback and made fixes. Resolves conversation threads by default.

## Usage

Invoke the **respond-pr-feedback** skill, optionally passing these flags:

```text
respond-pr-feedback [--pr <number>] [--no-resolve]
```

**Flags:**
- `--pr <number>` - PR number to target (default: current branch's PR)
- `--no-resolve` - Skip thread resolution after posting replies (default: resolve all)

## Prerequisites

Run the [fetch-pr-feedback](../fetch-pr-feedback/SKILL.md) skill first to evaluate the feedback and make any necessary fixes.

## Hard gates (sequenced)

Advance only after each pass condition is met (objective checks—not assumed completion).

1. **Prerequisite satisfied:** You have already run the [fetch-pr-feedback](../fetch-pr-feedback/SKILL.md) skill, evaluated each thread, and applied fixes or chosen an explicit response strategy per thread (no posting blind).
2. **Context loaded:** Step 2 commands exit `0`; values parsed from `gh pr view`, `gh repo view`, and `gh api user` are non-empty and assigned to `$PR_NUMBER`, `$PR_AUTHOR`, `$OWNER`, `$REPO`, `$CURRENT_USER`—never invent owner, repo, or PR number.
3. **Queue decided:** Step 3a `jq` exits `0`. If the filtered list is empty, output exactly `All review comments have been addressed.` and **stop** (do not call reply or GraphQL resolve APIs).
4. **Reply before resolve:** For each target comment, Step 4 `gh api .../replies` exits `0` before Step 5 attempts resolution for that item (unless `--no-resolve`).
5. **Resolve with mapping:** Step 5 calls `resolveReviewThread` only when Step 3b provides a `threadId` for that comment's id; if there is no mapping, skip resolution for that item without treating it as failure.

## Instructions

### 1. Parse Arguments

Accept optional flags (`--pr <number>`, `--no-resolve`):
- `--pr <number>` or detect from current branch
- `--no-resolve` flag (boolean, default false)

### 2. Get PR Context

```bash
# If --pr <number> was specified, set PR_NUMBER=<number> so gh pr view targets that PR;
# otherwise omit it to use the current branch's PR:
gh pr view ${PR_NUMBER:+"$PR_NUMBER"} --json number,author --jq '{number, author: .author.login}'

# Get repo owner/name
gh repo view --json owner,name --jq '{owner: .owner.login, name: .name}'

# Get current authenticated user
gh api user --jq '.login'
```

Store as `$PR_NUMBER`, `$PR_AUTHOR`, `$OWNER`, `$REPO`, `$CURRENT_USER`.

**Note:** `$OWNER`, `$REPO`, etc. are placeholders. Substitute actual values from previous steps.

### 3. Fetch Unreplied Comments and Thread Data

#### 3a. Unreplied Review Comments

Fetch review comments, excluding PR author and current user, filtering to root comments that haven't been replied to.

Write the jq filter to a temporary file using `mktemp` and a heredoc with single-quoted delimiter (prevents shell escaping issues with `!=`, regex patterns, and angle brackets), then clean it up after running:

```bash
UNREPLIED_JQ=$(mktemp)
cat > "$UNREPLIED_JQ" << 'JQEOF'
add // [] |
# Root comments from reviewers (not replies, not PR author, not current user)
[.[] | select(
  .in_reply_to_id == null and
  .user.login != $pr_author and
  .user.login != $current_user
)] as $roots |
# IDs that current user has already replied to
[.[] | select(.user.login == $current_user) | .in_reply_to_id] as $replied |
# Filter to unreplied only
$roots | map(select(. as $c | $replied | index($c.id) == null)) |
# Dedup: group by path + line + reviewer, pick newest per group
group_by({
  p: .path,
  l: (.line // .original_line),
  u: .user.login
}) |
map(sort_by(.created_at) | last) |
# Output needed fields
map({
  id,
  user: .user.login,
  path,
  line_display: (
    .line as $end | .start_line as $start |
    if $start and $start != $end then "\($start)-\($end)"
    else "\($end // .original_line)" end
  ),
  body
})
JQEOF

gh api --paginate "repos/$OWNER/$REPO/pulls/$PR_NUMBER/comments" | \
  jq -s --arg pr_author "$PR_AUTHOR" --arg current_user "$CURRENT_USER" \
  -f "$UNREPLIED_JQ"
rm -f "$UNREPLIED_JQ"
```

If no unreplied comments found, output: "All review comments have been addressed." and stop.

#### 3b. Pre-fetch Thread Data

Fetch review thread IDs to enable resolution after posting replies:

```bash
gh api graphql \
  -f owner="$OWNER" -f repo="$REPO" -F pr="$PR_NUMBER" \
  -f query='
    query($owner: String!, $repo: String!, $pr: Int!) {
      repository(owner: $owner, name: $repo) {
        pullRequest(number: $pr) {
          reviewThreads(first: 100) {
            nodes {
              id
              isResolved
              comments(first: 1) {
                nodes { databaseId }
              }
            }
          }
        }
      }
    }
  '
```

Build a lookup map: comment `databaseId` → thread `id` (unresolved threads only). This enables immediate resolution after posting each reply.

### 4. Generate and Post Replies

For each unreplied comment, determine the appropriate response based on your evaluation:

| Evaluation Outcome | Response |
|--------------------|----------|
| Feedback was incorrect/unfounded | Explain why the current code is correct |
| Feedback lacked context | Explain the design decision |
| Feedback was valid and fixed | "Fixed in `$COMMIT_SHA`" or brief description of change |
| Feedback was valid but won't fix | Explain the tradeoff/decision |

**Tagging guideline:** `@`-tag bot reviewers (e.g., `@coderabbitai`) to trigger their processing. Do not `@`-tag human reviewers.

Post reply to each comment:

```bash
gh api "repos/$OWNER/$REPO/pulls/$PR_NUMBER/comments/$COMMENT_ID/replies" \
  -X POST --raw-field body="$RESPONSE"
```

### 5. Resolve Threads

**This step runs by default.** Skip only if `--no-resolve` was passed.

After posting each reply, look up the `$THREAD_ID` from the step 3b mapping using the comment's `$COMMENT_ID`:

```bash
gh api graphql \
  -f threadId="$THREAD_ID" \
  -f query='
    mutation($threadId: ID!) {
      resolveReviewThread(input: {threadId: $threadId}) {
        thread { isResolved }
      }
    }
  '
```

- If a comment's `$COMMENT_ID` has a matching thread ID in the lookup, resolve it
- If no thread ID found (e.g., issue comment rather than review thread), skip resolution for that comment

### 6. Output Summary

Group by reviewer:

```markdown
### Reviewer: coderabbitai[bot]

| File:Line | Response Type | Thread |
|-----------|---------------|--------|
| `src/foo.ts:42` | Fixed in `abc1234` | Resolved |
| `src/bar.ts:15` | Explained design | Resolved |

### Reviewer: octocat

| File:Line | Response Type | Thread |
|-----------|---------------|--------|
| `src/baz.ts:7` | Won't fix | Resolved |
```

Footer:

```markdown
**Threads resolved: 3/3**
```

## Response Guidelines

- `@`-tag bot reviewers to trigger re-processing; do not tag human reviewers
- Keep responses concise and technical
- No performative agreement ("Great point!", "You're right!")
- Reference specific code/design when explaining decisions
- If fixed: state what changed, no gratitude

## Example

```text
# Respond to all reviewers on current PR (resolves threads)
respond-pr-feedback

# Respond on a specific PR
respond-pr-feedback --pr 123

# Respond without resolving threads
respond-pr-feedback --no-resolve
```
