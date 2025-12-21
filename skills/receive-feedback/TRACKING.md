# Feedback Tracking

## Purpose

Maintain a log of processed feedback for:
- Reference during follow-up discussions
- Pattern recognition (recurring feedback types)
- Accountability (what was decided and why)

## Tracking Prompt

After processing feedback, always ask:

> "Log this feedback session to `.feedback-log.csv`? (y/n)"

Do not assume. Do not auto-track. Always prompt.

## Log Format

Append to `.feedback-log.csv` in project root:

```csv
date,source,item_number,item_summary,disposition,location,evidence
2025-01-15,PR #123 @reviewer,1,Fix null check,implemented,auth.py:42,
2025-01-15,PR #123 @reviewer,2,Remove unused fn,rejected,validate_user,Used in middleware.py:45
2025-01-15,PR #123 @reviewer,3,Add caching,deferred,,Out of scope
```

## CSV Columns

| Column | Description |
|--------|-------------|
| date | ISO date (YYYY-MM-DD) |
| source | Origin of feedback (PR #, reviewer, session) |
| item_number | Feedback item number from source |
| item_summary | Brief description of the item |
| disposition | implemented / rejected / deferred / clarified |
| location | File:line where change was made (if applicable) |
| evidence | Reason for rejection/deferral (if applicable) |

## Log Location

Default: `.feedback-log.csv` in project root (gitignored)
