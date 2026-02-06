---
description: Respond to review comments on a PR after evaluation and fixes
---

# Respond to PR Feedback

Post replies to review comments after you've evaluated the feedback and made fixes. Resolves conversation threads by default.

## Usage

```
/beagle-core:respond-pr-feedback [--pr <number>] [--no-resolve]
```

**Flags:**
- `--pr <number>` - PR number to target (default: current branch's PR)
- `--no-resolve` - Skip thread resolution after posting replies (default: resolve all)

## Prerequisites

Run `/beagle-core:fetch-pr-feedback` first to evaluate the feedback and make any necessary fixes.

## Instructions

### 1. Parse Arguments

Extract flags from `$ARGUMENTS`:
- `--pr <number>` or detect from current branch
- `--no-resolve` flag (boolean, default false)

### 2. Get PR Context

```bash
# Get PR info (if --pr not specified, uses current branch)
gh pr view --json number,author --jq '{number, author: .author.login}'

# Get repo owner/name
gh repo view --json owner,name --jq '{owner: .owner.login, name: .name}'

# Get current authenticated user
gh api user --jq '.login'
```

Store as `$PR_NUMBER`, `$PR_AUTHOR`, `$OWNER`, `$REPO`, `$CURRENT_USER`.

**Note:** `$OWNER`, `$REPO`, etc. are placeholders. Substitute actual values from previous steps.

### 3. Fetch Unreplied Comments and Thread Data

#### 3a. Unreplied Review Comments

Fetch review comments, excluding PR author and current user, filtering to root comments that haven't been replied to:

```bash
gh api --paginate "repos/$OWNER/$REPO/pulls/$PR_NUMBER/comments" | jq -s 'add |
  # Root comments from reviewers (not replies, not PR author, not current user)
  [.[] | select(
    .in_reply_to_id == null and
    .user.login != "$PR_AUTHOR" and
    .user.login != "$CURRENT_USER"
  )] as $roots |
  # IDs that current user has already replied to
  [.[] | select(.user.login == "$CURRENT_USER") | .in_reply_to_id] as $replied |
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
'
```

If no unreplied comments found, output: "All review comments have been addressed." and stop.

#### 3b. Pre-fetch Thread Data

Fetch review thread IDs to enable resolution after posting replies:

```bash
gh api graphql -f query='
  query {
    repository(owner: "$OWNER", name: "$REPO") {
      pullRequest(number: $PR_NUMBER) {
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
gh api graphql -f query='
  mutation {
    resolveReviewThread(input: {threadId: "$THREAD_ID"}) {
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

```
**Threads resolved: 3/3**
```

## Response Guidelines

- `@`-tag bot reviewers to trigger re-processing; do not tag human reviewers
- Keep responses concise and technical
- No performative agreement ("Great point!", "You're right!")
- Reference specific code/design when explaining decisions
- If fixed: state what changed, no gratitude

## Example

```bash
# Respond to all reviewers on current PR (resolves threads)
/beagle-core:respond-pr-feedback

# Respond on a specific PR
/beagle-core:respond-pr-feedback --pr 123

# Respond without resolving threads
/beagle-core:respond-pr-feedback --no-resolve
```
