---
description: create a release PR (auto-detects previous tag)
---

# Release Automation

Automate the full release process: generate notes, update files, create branch, and open PR.

No arguments required - automatically detects the previous tag.

---

## Versioning Overview

Beagle has three version locations:
1. **plugin.json version** - Main version, matches repo tags
2. **marketplace.json metadata.version** - Marketplace version (only update when marketplace structure changes)
3. **marketplace.json plugins[].version** - Plugin version in marketplace (only update when marketplace structure changes)

This command updates **plugin.json only**. Marketplace versions are updated manually when the marketplace structure changes.

## Prerequisites

Verify we're on main and it's clean:

```bash
git checkout main
git pull
git status --short
```

If there are uncommitted changes, abort and ask the user to resolve them first.

Detect the previous tag:

```bash
PREV_TAG=$(git describe --tags --abbrev=0 2>/dev/null)
if [ -z "$PREV_TAG" ]; then
  echo "No previous tags found. This appears to be the first release."
  PREV_TAG="HEAD~100"  # Fallback to analyze recent history
fi
echo "Previous tag: $PREV_TAG"
```

## Step 1: Check for CHANGELOG.md

If `CHANGELOG.md` does not exist, create it with the standard header:

```markdown
# Changelog

All notable changes to Beagle are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
```

## Step 2: Verify Documentation Coverage

Before generating release notes, verify all commands and skills are documented in README.md.

**Check commands coverage:**

```bash
# List actual commands (excluding llm-judge which may be experimental)
COMMANDS=$(ls -1 commands/*.md 2>/dev/null | xargs -I {} basename {} .md | sort)
echo "Actual commands:"
echo "$COMMANDS"

# Commands documented in README
echo ""
echo "Commands in README:"
grep -E '^\| `[a-z-]+' README.md | sed 's/| `\([^`]*\)`.*/\1/' | sort
```

**Check skills coverage:**

```bash
# List actual skill directories
SKILLS=$(ls -1d skills/*/SKILL.md 2>/dev/null | xargs -I {} dirname {} | xargs -I {} basename {} | sort)
echo "Actual skills count: $(echo "$SKILLS" | wc -l | tr -d ' ')"

# Skills should be grouped in README by category, verify major categories exist
echo ""
echo "Skills categories in README:"
grep -E '^\| \*\*' README.md | head -10
```

If documentation is missing or significantly out of sync, stop and run `/beagle:ensure-docs` first, then restart the release process.

## Step 3: Generate Release Notes

Run `/beagle:gen-release-notes ${PREV_TAG}` to:
1. Analyze commits since the previous tag
2. Categorize changes (Added, Changed, Fixed, Security, etc.)
3. Determine the next version number based on semantic versioning
4. Update `CHANGELOG.md` with the new version section

**Do not proceed** until CHANGELOG.md is updated with the new version.

## Step 4: Update Plugin Version

After determining the new version from the changelog analysis, update `.claude-plugin/plugin.json`:

```bash
# Extract the new version from CHANGELOG.md (first version entry after Unreleased)
VERSION=$(grep -E '^\#\# \[[0-9]+\.[0-9]+\.[0-9]+\]' CHANGELOG.md | head -1 | sed 's/.*\[\(.*\)\].*/\1/')
echo "New version: $VERSION"

# Update plugin.json version
# Use jq if available, otherwise sed
if command -v jq &> /dev/null; then
  jq --arg v "$VERSION" '.version = $v' .claude-plugin/plugin.json > .claude-plugin/plugin.json.tmp && mv .claude-plugin/plugin.json.tmp .claude-plugin/plugin.json
else
  sed -i '' "s/\"version\": \"[^\"]*\"/\"version\": \"$VERSION\"/" .claude-plugin/plugin.json
fi
```

Verify the update:

```bash
grep '"version"' .claude-plugin/plugin.json
```

## Step 5: Create Release Branch

After the files are updated:

```bash
# Create and checkout release branch
git checkout -b "chore/release-${VERSION}"
```

## Step 6: Commit Changes

Commit all updated version files:

```bash
git add CHANGELOG.md .claude-plugin/plugin.json
git commit -m "chore(release): bump version to ${VERSION}"
```

## Step 7: Push and Create PR

Push the branch and create a pull request:

```bash
git push -u origin "chore/release-${VERSION}"
```

Create the PR with this structure:

```bash
gh pr create --title "chore(release): ${VERSION}" --body "$(cat <<EOF
## Summary

- Bump version to ${VERSION}
- Update CHANGELOG.md with changes since ${PREV_TAG}

## Version Locations Updated

- [x] \`.claude-plugin/plugin.json\` - Plugin version
- [ ] \`.claude-plugin/marketplace.json\` - Not updated (only for marketplace structure changes)

## Post-merge Steps

After merging, run:
\`\`\`
/release-tag ${VERSION}
\`\`\`

---

Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

## Step 8: Output Summary

After creating the PR, provide:

1. The PR URL
2. The version number
3. Post-merge instructions:

```text
Release PR created: <URL>

After the PR is merged, run:
  /release-tag ${VERSION}
```

## Error Handling

- If main has uncommitted changes: abort and notify user
- If no tags exist: treat as first release, analyze recent commits
- If no changes since tag: abort and notify user
- If PR creation fails: provide manual steps
