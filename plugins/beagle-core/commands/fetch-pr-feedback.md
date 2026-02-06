---
description: Fetch bot review comments from a PR and evaluate with receive-feedback skill
---

# Fetch PR Feedback

Fetch review comments from a bot reviewer on the current PR, format them, and evaluate using the receive-feedback skill.

## Usage

```
/beagle-core:fetch-pr-feedback [--bot <username>] [--pr <number>]
```

**Flags:**
- `--bot <username>` - Bot/reviewer to fetch comments from (default: `coderabbitai[bot]`)
- `--pr <number>` - PR number to target (default: current branch's PR)

## Instructions

### 1. Parse Arguments

Extract flags from `$ARGUMENTS`:
- `--bot <username>` or default to `coderabbitai[bot]`
- `--pr <number>` or detect from current branch

### 2. Get PR Context

```bash
# If --pr was specified, use that number directly
# Otherwise, get PR for current branch:
gh pr view --json number,headRefName,url

# Get repo owner/name:
gh repo view --json nameWithOwner --jq '.nameWithOwner'
```

If no PR exists for current branch, fail with: "No PR found for current branch. Use --pr to specify a PR number."

### 3. Fetch Comments

Fetch both types of comments (use `--paginate` to get all):

**Issue comments** (summary/walkthrough posts):
```bash
gh api --paginate "repos/{owner}/{repo}/issues/{number}/comments" \
  --jq '.[] | select(.user.login == "{bot}") | .body'
```

**Review comments** (line-specific):
```bash
gh api --paginate "repos/{owner}/{repo}/pulls/{number}/comments" \
  --jq '.[] | select(.user.login == "{bot}") | "---\nFile: \(.path):\(.line // .original_line)\n\(.body)\n"'
```

### 4. Format Feedback Document

Strip noise from the content:
- Remove `<details>` blocks containing "Learnings" or AI command hints
- Remove excessive whitespace

Structure the output:

```markdown
# PR Feedback from {bot}

## Summary/Overview
[All issue comments here - there may be multiple]

## Line-Specific Comments
[All review comments here, each prefixed with "File: path:line"]
```

If no comments found, output: "No comments from {bot} found on this PR."

### 5. Evaluate with receive-feedback

Use the Skill tool to load the receive-feedback skill: `Skill(skill: "beagle-core:receive-feedback")`

Then process the formatted feedback document:

1. Parse each actionable item from the formatted document
2. Process each item through verify → evaluate → execute
3. Produce structured response summary

## Example

```bash
# Fetch CodeRabbit comments on current branch's PR (default)
/beagle-core:fetch-pr-feedback

# Fetch from a different bot
/beagle-core:fetch-pr-feedback --bot renovate[bot]

# Fetch from a specific PR
/beagle-core:fetch-pr-feedback --pr 123

# Combined
/beagle-core:fetch-pr-feedback --bot coderabbitai[bot] --pr 456
```
