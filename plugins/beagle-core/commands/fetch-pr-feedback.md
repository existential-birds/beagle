---
description: Fetch review comments from a PR and evaluate with receive-feedback skill
---

# Fetch PR Feedback

Fetch review comments from all reviewers on the current PR, format them, and evaluate using the receive-feedback skill. Excludes the PR author and current user by default.

## Usage

```bash
/beagle-core:fetch-pr-feedback [--pr <number>] [--include-author]
```

**Flags:**
- `--pr <number>` - PR number to target (default: current branch's PR)
- `--include-author` - Include PR author's own comments (default: excluded)

## Instructions

### 1. Parse Arguments

Extract flags from `$ARGUMENTS`:
- `--pr <number>` or detect from current branch
- `--include-author` flag (boolean, default false)

### 2. Get PR Context

```bash
# If --pr was specified, use that number directly
# Otherwise, get PR for current branch:
gh pr view --json number,headRefName,url,author --jq '{number, headRefName, url, author: .author.login}'

# Get repo owner/name
gh repo view --json owner,name --jq '{owner: .owner.login, name: .name}'

# Get current authenticated user
gh api user --jq '.login'
```

Store as `$PR_NUMBER`, `$PR_AUTHOR`, `$OWNER`, `$REPO`, `$CURRENT_USER`.

**Note:** `$OWNER`, `$REPO`, etc. are placeholders. Substitute actual values from previous steps.

If no PR exists for current branch, fail with: "No PR found for current branch. Use `--pr` to specify a PR number."

### 3. Fetch Comments

Fetch both types of comments, excluding `$PR_AUTHOR` and `$CURRENT_USER` (unless `--include-author` is set). Use `--paginate` with `jq -s 'add'` to combine paginated JSON arrays into one.

**Issue comments** (summary/walkthrough posts):
```bash
gh api --paginate "repos/$OWNER/$REPO/issues/$PR_NUMBER/comments" | \
  jq -s --arg pr_author "$PR_AUTHOR" --arg current_user "$CURRENT_USER" '
  def clean_body:
    gsub("(?s)<details>.*?</details>"; "")
    | gsub("(?s)<!--.*?-->"; "")
    | gsub("(?s)\\n?---\\n[\\s\\S]*$"; "")
    | gsub("^\\s+|\\s+$"; "")
    | if length > 4000 then .[:4000] + "\n\n[comment truncated]" else . end
  ;
  add |
  [.[] | select(
    .user.login != $pr_author and
    .user.login != $current_user
  )] |
  map({id, user: .user.login, body: (.body | clean_body), created_at})
'
```

**Review comments** (line-specific):
```bash
gh api --paginate "repos/$OWNER/$REPO/pulls/$PR_NUMBER/comments" | \
  jq -s --arg pr_author "$PR_AUTHOR" --arg current_user "$CURRENT_USER" '
  def clean_body:
    gsub("(?s)<details>.*?</details>"; "")
    | gsub("(?s)<!--.*?-->"; "")
    | gsub("(?s)\\n?---\\n[\\s\\S]*$"; "")
    | gsub("^\\s+|\\s+$"; "")
    | if length > 4000 then .[:4000] + "\n\n[comment truncated]" else . end
  ;
  add |
  [.[] | select(
    .user.login != $pr_author and
    .user.login != $current_user
  )] |
  map({
    id,
    user: .user.login,
    path,
    line_display: (
      .line as $end | .start_line as $start |
      if $start and $start != $end then "\($start)-\($end)"
      else "\($end // .original_line)" end
    ),
    body: (.body | clean_body),
    created_at
  })
'
```

If `--include-author` is set, omit the `--arg pr_author` parameter and the `.user.login != $pr_author` condition from both queries. Keep the `$current_user` exclusion either way.

### 4. Format Feedback Document

**Noise stripping** — handled by the `clean_body` jq function in Step 3. Each comment body is already stripped of `<details>` blocks, HTML comments, and bot footer boilerplate before it reaches this step. Comments exceeding 4000 chars after stripping are truncated with a `[comment truncated]` marker.

**Group by reviewer** — organize the formatted output by reviewer username:

```markdown
# PR #$PR_NUMBER Review Feedback

## Reviewer: coderabbitai[bot]

### Summary Comments
[Issue comments from this reviewer, each separated by ---]

### Line-Specific Comments
[Review comments from this reviewer, each formatted as:]

**File: `path/to/file.ts:42`**
[cleaned comment body]

---

## Reviewer: another-reviewer

### Summary Comments
...

### Line-Specific Comments
...
```

If no comments found from any reviewer, output: "No review comments found on this PR (excluding PR author and current user)."

### 5. Evaluate with receive-feedback

Use the Skill tool to load the receive-feedback skill: `Skill(skill: "beagle-core:receive-feedback")`

Then process the formatted feedback document:

1. Parse each actionable item from the formatted document
2. Process each item through verify → evaluate → execute
3. Produce structured response summary

## Example

```bash
# Fetch all reviewer comments on current branch's PR (default)
/beagle-core:fetch-pr-feedback

# Fetch from a specific PR
/beagle-core:fetch-pr-feedback --pr 123

# Include PR author's own comments
/beagle-core:fetch-pr-feedback --include-author

# Combined
/beagle-core:fetch-pr-feedback --pr 456 --include-author
```
