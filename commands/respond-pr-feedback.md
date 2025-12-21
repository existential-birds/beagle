---
description: Respond to bot review comments on a PR after evaluation and fixes
---

# Respond to PR Feedback

Post replies to bot review comments after you've evaluated the feedback and made fixes.

## Usage

```
/beagle:respond-pr-feedback [--bot <username>] [--pr <number>] [--as <username>]
```

**Flags:**
- `--bot <username>` - Bot whose comments to respond to (default: `coderabbitai[bot]`)
- `--pr <number>` - PR number to target (default: current branch's PR)
- `--as <username>` - Filter already-replied based on this responder (default: current `gh` user)

## Prerequisites

Run `/beagle:fetch-pr-feedback` first to evaluate the feedback and make any necessary fixes.

## Instructions

### 1. Parse Arguments

Extract flags from `$ARGUMENTS`:
- `--bot <username>` or default to `coderabbitai[bot]`
- `--pr <number>` or detect from current branch
- `--as <username>` or detect from `gh api user`

### 2. Get PR Context

```bash
# Get repo info
gh repo view --json nameWithOwner --jq '.nameWithOwner'

# Get PR number (if not specified)
gh pr view --json number --jq '.number'

# Get responder username (if --as not specified)
gh api user --jq '.login'
```

### 3. Fetch Unreplied Comments

This query filters out already-replied comments and deduplicates (CodeRabbit reposts on each iteration):

```bash
gh api --paginate "repos/{owner}/{repo}/pulls/{number}/comments" | jq -s 'add |
  # Get root comments from target bot (not replies to itself)
  [.[] | select(.user.login == "{bot}" and .in_reply_to_id == null)] as $roots |
  # Get IDs that responder has already replied to
  [.[] | select(.user.login == "{responder}") | .in_reply_to_id] as $replied |
  # Filter to unreplied comments only
  $roots | map(select(. as $c | $replied | index($c.id) == null)) |
  # Group by file:line and pick newest comment for each (handles duplicates)
  group_by({p: .path, l: .line}) |
  map(sort_by(.created_at) | last) |
  # Output needed fields
  map({id, path, line, body})
'
```

If no unreplied comments found, output: "All {bot} comments have been addressed."

### 4. Generate and Post Replies

For each unreplied comment, determine the appropriate response based on your evaluation:

| Evaluation Outcome | Response |
|-------------------|----------|
| Feedback was incorrect/unfounded | Explain why the current code is correct |
| Feedback lacked context | Explain the design decision |
| Feedback was valid and fixed | "Fixed in {commit}" or brief description of change |
| Feedback was valid but won't fix | Explain the tradeoff/decision |

Post reply to each comment:

```bash
gh api "repos/{owner}/{repo}/pulls/{number}/comments/{comment_id}/replies" \
  -X POST --raw-field body="@{bot} {response}"
```

### 5. Prompt to Resolve Threads

After posting replies, ask the user:

> Would you like to resolve these conversation threads?
> 1. **Yes, all** - Resolve all threads that were just replied to
> 2. **Select individually** - Choose which threads to resolve
> 3. **No** - Leave threads open for further discussion

To resolve a thread, use the GraphQL API:

```bash
gh api graphql -f query='
  mutation {
    resolveReviewThread(input: {threadId: "{thread_id}"}) {
      thread { isResolved }
    }
  }
'
```

Note: To get the `thread_id`, you need to query review threads:
```bash
gh api graphql -f query='
  query {
    repository(owner: "{owner}", name: "{repo}") {
      pullRequest(number: {number}) {
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

Match `databaseId` to your comment IDs to find the corresponding `thread_id`.

### 6. Output Summary

Display a summary table:

| File:Line | Response Type | Thread Status |
|-----------|---------------|---------------|
| `src/foo.ts:42` | Fixed | Resolved |
| `src/bar.ts:15` | Explained design | Open |

## Response Guidelines

- **Always tag the bot** at the start: `@coderabbitai ...`
- Keep responses concise and technical
- No performative agreement ("Great point!", "You're right!")
- Reference specific code/design when explaining decisions
- If fixed: state what changed, no gratitude

## Example

```bash
# Respond to CodeRabbit on current PR
/beagle:respond-pr-feedback

# Respond on a specific PR
/beagle:respond-pr-feedback --pr 123

# Use different bot/responder
/beagle:respond-pr-feedback --bot renovate[bot] --as my-bot[bot]
```
