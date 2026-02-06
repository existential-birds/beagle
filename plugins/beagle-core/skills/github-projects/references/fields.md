# GitHub Project Fields Reference

Detailed reference for managing project fields via `gh project field-*` commands.

## Built-in Fields

Every project includes these system fields:
- **Title** - Item name (from issue/PR title or draft title)
- **Assignees** - Assigned users
- **Status** - Single select workflow status
- **Labels** - Issue/PR labels (read-only in project)
- **Milestone** - Issue/PR milestone (read-only)
- **Repository** - Source repository
- **Reviewers** - PR reviewers

## Custom Field Types

| Type | Flag Value | Description |
|------|------------|-------------|
| Text | `TEXT` | Free-form text |
| Number | `NUMBER` | Numeric values |
| Date | `DATE` | Date picker (YYYY-MM-DD) |
| Single Select | `SINGLE_SELECT` | Dropdown with predefined options |
| Iteration | `ITERATION` | Sprint/iteration cycles |

## Listing Fields

```bash
gh project field-list PROJECT_NUM --owner OWNER
```

Options:
| Flag | Default | Description |
|------|---------|-------------|
| `-L, --limit` | 30 | Max fields to fetch |
| `--format json` | - | JSON output |
| `-q, --jq` | - | jq filter expression |

### JSON Structure

```json
{
  "fields": [
    {
      "id": "PVTF_xxx",
      "name": "Status",
      "type": "SINGLE_SELECT",
      "options": [
        {"id": "opt1", "name": "Todo"},
        {"id": "opt2", "name": "In Progress"},
        {"id": "opt3", "name": "Done"}
      ]
    },
    {
      "id": "PVTF_yyy",
      "name": "Points",
      "type": "NUMBER"
    }
  ]
}
```

### Useful jq Filters

```bash
# List all field names and types
gh project field-list 1 --owner "@me" --format json | \
  jq '.fields[] | {name, type}'

# Get specific field ID
gh project field-list 1 --owner "@me" --format json | \
  jq -r '.fields[] | select(.name == "Status") | .id'

# Get single select options
gh project field-list 1 --owner "@me" --format json | \
  jq '.fields[] | select(.type == "SINGLE_SELECT") | {name, options}'

# Get option ID by name
gh project field-list 1 --owner "@me" --format json | \
  jq -r '.fields[] | select(.name == "Priority") | .options[] | select(.name == "High") | .id'
```

## Creating Fields

### Text Field
```bash
gh project field-create PROJECT_NUM --owner OWNER \
  --name "Notes" \
  --data-type TEXT
```

### Number Field
```bash
gh project field-create PROJECT_NUM --owner OWNER \
  --name "Story Points" \
  --data-type NUMBER
```

### Date Field
```bash
gh project field-create PROJECT_NUM --owner OWNER \
  --name "Due Date" \
  --data-type DATE
```

### Single Select Field

```bash
gh project field-create PROJECT_NUM --owner OWNER \
  --name "Priority" \
  --data-type SINGLE_SELECT \
  --single-select-options "Low,Medium,High,Critical"
```

Options are comma-separated. Field is created with all options.

## Deleting Fields

```bash
gh project field-delete --id FIELD_ID
```

Get field ID from `field-list --format json`. Deleting removes the field and all its values from items.

## Working with Single Select Options

### Get Option IDs

```bash
# Get all options for a field
gh project field-list 1 --owner "@me" --format json | \
  jq '.fields[] | select(.name == "Status") | .options[] | {id, name}'
```

### Set Item to Specific Option

```bash
# Get IDs
PROJECT_ID=$(gh project list --format json | jq -r '.projects[0].id')
FIELD_ID=$(gh project field-list 1 --owner "@me" --format json | \
  jq -r '.fields[] | select(.name == "Status") | .id')
OPTION_ID=$(gh project field-list 1 --owner "@me" --format json | \
  jq -r '.fields[] | select(.name == "Status") | .options[] | select(.name == "Done") | .id')

# Update item
gh project item-edit --id ITEM_ID \
  --project-id "$PROJECT_ID" \
  --field-id "$FIELD_ID" \
  --single-select-option-id "$OPTION_ID"
```

## Working with Iterations

Iterations are managed via the web UI. The CLI can:
- List iteration field IDs
- Set items to specific iterations

```bash
# Get iteration field
gh project field-list 1 --owner "@me" --format json | \
  jq '.fields[] | select(.type == "ITERATION")'

# Set item to iteration
gh project item-edit --id ITEM_ID \
  --project-id PROJECT_ID \
  --field-id ITERATION_FIELD_ID \
  --iteration-id ITERATION_ID
```

## Field Patterns

### Priority Field
```bash
gh project field-create 1 --owner "@me" \
  --name "Priority" \
  --data-type SINGLE_SELECT \
  --single-select-options "P0 - Critical,P1 - High,P2 - Medium,P3 - Low"
```

### Effort/Points Field
```bash
gh project field-create 1 --owner "@me" \
  --name "Points" \
  --data-type NUMBER
```

### Due Date Field
```bash
gh project field-create 1 --owner "@me" \
  --name "Due Date" \
  --data-type DATE
```

### Team Field
```bash
gh project field-create 1 --owner "@me" \
  --name "Team" \
  --data-type SINGLE_SELECT \
  --single-select-options "Frontend,Backend,DevOps,Design"
```

## Complete Setup Example

```bash
#!/bin/bash
# Set up a new project with common fields

PROJECT_NUM=1
OWNER="@me"

# Create Status field (usually exists by default)
# gh project field-create $PROJECT_NUM --owner "$OWNER" \
#   --name "Status" --data-type SINGLE_SELECT \
#   --single-select-options "Backlog,Todo,In Progress,In Review,Done"

# Priority
gh project field-create $PROJECT_NUM --owner "$OWNER" \
  --name "Priority" --data-type SINGLE_SELECT \
  --single-select-options "P0,P1,P2,P3"

# Story Points
gh project field-create $PROJECT_NUM --owner "$OWNER" \
  --name "Points" --data-type NUMBER

# Due Date
gh project field-create $PROJECT_NUM --owner "$OWNER" \
  --name "Due Date" --data-type DATE

# Team
gh project field-create $PROJECT_NUM --owner "$OWNER" \
  --name "Team" --data-type SINGLE_SELECT \
  --single-select-options "Engineering,Product,Design"

# Notes
gh project field-create $PROJECT_NUM --owner "$OWNER" \
  --name "Notes" --data-type TEXT

echo "Project fields configured"
gh project field-list $PROJECT_NUM --owner "$OWNER"
```

## Limitations

- Cannot modify single select options after creation (must delete and recreate field)
- Cannot create iteration fields via CLI (use web UI)
- Some built-in fields are read-only (Labels, Milestone, Repository)
- Field names must be unique within a project
