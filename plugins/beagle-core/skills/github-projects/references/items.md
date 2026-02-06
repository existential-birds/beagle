# GitHub Project Items Reference

Detailed reference for managing project items via `gh project item-*` commands.

## Item Types

Projects can contain:
- **Issues** - Added via URL
- **Pull Requests** - Added via URL
- **Draft Issues** - Created directly in project

## Adding Items

### Add Issue or PR

```bash
gh project item-add PROJECT_NUM --owner OWNER --url ISSUE_OR_PR_URL
```

Options:
| Flag | Description |
|------|-------------|
| `--url` | URL of issue/PR to add |
| `--owner` | Project owner (`@me` for current user) |
| `--format json` | JSON output with item ID |

Example:
```bash
# Add and capture item ID
ITEM=$(gh project item-add 1 --owner "@me" \
  --url https://github.com/org/repo/issues/42 \
  --format json | jq -r '.id')
echo "Added item: $ITEM"
```

### Create Draft Item

```bash
gh project item-create PROJECT_NUM --owner OWNER --title "Title" --body "Description"
```

Draft items exist only within the project (not linked to any issue).

## Listing Items

```bash
gh project item-list PROJECT_NUM --owner OWNER [flags]
```

| Flag | Default | Description |
|------|---------|-------------|
| `-L, --limit` | 30 | Max items to fetch |
| `--format json` | - | JSON output |
| `-q, --jq` | - | jq filter expression |

### JSON Structure

```json
{
  "items": [
    {
      "id": "PVTI_xxx",
      "title": "Issue title",
      "number": 42,
      "type": "ISSUE",
      "url": "https://github.com/...",
      "status": "In Progress",
      "repository": "owner/repo"
    }
  ]
}
```

### Useful jq Filters

```bash
# Get all item IDs
gh project item-list 1 --owner "@me" --format json | jq -r '.items[].id'

# Filter by status
gh project item-list 1 --owner "@me" --format json | \
  jq '.items[] | select(.status == "Todo")'

# Get items with specific label (requires API query for labels)
gh project item-list 1 --owner "@me" --format json | \
  jq '.items[] | select(.type == "ISSUE")'
```

## Editing Items

Items are edited using their ID (from `item-list --format json`).

### Edit Draft Issue Content

```bash
gh project item-edit --id ITEM_ID --title "New title"
gh project item-edit --id ITEM_ID --body "New description"
gh project item-edit --id ITEM_ID --title "Title" --body "Body"
```

### Edit Field Values

Requires `--project-id` and `--field-id`. Get these from:
```bash
# Get project ID
gh project list --format json | jq '.projects[] | {number, id}'

# Get field IDs
gh project field-list PROJECT_NUM --owner OWNER --format json | jq '.fields[] | {id, name}'
```

#### Text Fields
```bash
gh project item-edit --id ITEM_ID \
  --project-id PROJECT_ID \
  --field-id FIELD_ID \
  --text "Field value"
```

#### Number Fields
```bash
gh project item-edit --id ITEM_ID \
  --project-id PROJECT_ID \
  --field-id FIELD_ID \
  --number 42
```

#### Date Fields
```bash
gh project item-edit --id ITEM_ID \
  --project-id PROJECT_ID \
  --field-id FIELD_ID \
  --date "2024-12-31"
```

#### Single Select Fields

Get option IDs first:
```bash
gh project field-list PROJECT_NUM --owner OWNER --format json | \
  jq '.fields[] | select(.name == "Status") | .options'
```

Then set:
```bash
gh project item-edit --id ITEM_ID \
  --project-id PROJECT_ID \
  --field-id FIELD_ID \
  --single-select-option-id OPTION_ID
```

#### Iteration Fields
```bash
gh project item-edit --id ITEM_ID \
  --project-id PROJECT_ID \
  --field-id FIELD_ID \
  --iteration-id ITERATION_ID
```

#### Clear Field Value
```bash
gh project item-edit --id ITEM_ID \
  --project-id PROJECT_ID \
  --field-id FIELD_ID \
  --clear
```

## Archive & Delete

### Archive (Hide)
```bash
gh project item-archive PROJECT_NUM --owner OWNER --id ITEM_ID
```

Archived items can be restored via the web UI.

### Delete (Permanent)
```bash
gh project item-delete PROJECT_NUM --owner OWNER --id ITEM_ID
```

Removes item from project. For issues/PRs, the underlying item still exists.

## Bulk Operations

### Add All Open Issues
```bash
gh issue list --repo owner/repo --state open --json url -q '.[].url' | \
  while read url; do
    gh project item-add PROJECT_NUM --owner OWNER --url "$url"
  done
```

### Add Issues with Label
```bash
gh issue list --repo owner/repo --label "project-x" --json url -q '.[].url' | \
  xargs -I {} gh project item-add PROJECT_NUM --owner OWNER --url {}
```

### Update Multiple Items
```bash
# Get item IDs and update each
gh project item-list PROJECT_NUM --owner OWNER --format json | \
  jq -r '.items[] | select(.status == "Todo") | .id' | \
  while read id; do
    gh project item-edit --id "$id" \
      --project-id PROJECT_ID \
      --field-id FIELD_ID \
      --single-select-option-id NEW_STATUS_ID
  done
```

## Complete Workflow Example

```bash
#!/bin/bash
# Add issue to project and set initial status

PROJECT_NUM=1
OWNER="@me"
ISSUE_URL="https://github.com/org/repo/issues/42"

# 1. Get project ID
PROJECT_ID=$(gh project list --format json | \
  jq -r --arg num "$PROJECT_NUM" '.projects[] | select(.number == ($num | tonumber)) | .id')

# 2. Get Status field ID and "In Progress" option ID
FIELD_DATA=$(gh project field-list $PROJECT_NUM --owner "$OWNER" --format json)
STATUS_FIELD=$(echo "$FIELD_DATA" | jq -r '.fields[] | select(.name == "Status") | .id')
IN_PROGRESS_ID=$(echo "$FIELD_DATA" | jq -r '.fields[] | select(.name == "Status") | .options[] | select(.name == "In Progress") | .id')

# 3. Add issue to project
ITEM_ID=$(gh project item-add $PROJECT_NUM --owner "$OWNER" --url "$ISSUE_URL" --format json | jq -r '.id')

# 4. Set status to "In Progress"
gh project item-edit --id "$ITEM_ID" \
  --project-id "$PROJECT_ID" \
  --field-id "$STATUS_FIELD" \
  --single-select-option-id "$IN_PROGRESS_ID"

echo "Added item $ITEM_ID with status 'In Progress'"
```
