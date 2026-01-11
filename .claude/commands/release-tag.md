---
description: tag and push a release after the release PR is merged
---

# Release Tag

Create and push a version tag after a release PR has been merged.

**Input**: Version number (e.g., `1.9.0`) - the `v` prefix is optional

```text
$ARGUMENTS
```

---

## Prerequisites

Verify the release PR is merged and we're ready to tag:

```bash
# Ensure we're on main with latest changes
git checkout main
git pull

# Extract version from input (strip 'v' prefix if present)
VERSION="${ARGUMENTS#v}"

# Verify plugin.json version matches
echo "Checking version consistency..."
PLUGIN_VERSION=$(grep '"version"' .claude-plugin/plugin.json | sed 's/.*"\([0-9.]*\)".*/\1/')
if [ "$PLUGIN_VERSION" != "$VERSION" ]; then
  echo "ERROR: plugin.json version ($PLUGIN_VERSION) doesn't match requested version ($VERSION)"
  echo "Ensure the release PR was merged first."
  exit 1
fi
echo "plugin.json version: $PLUGIN_VERSION - matches"
```

If the version doesn't match, the script aborts with an error. The release PR must be merged first.

## Step 1: Verify CHANGELOG Entry

Confirm the version has a changelog entry:

```bash
grep "## \[${VERSION}\]" CHANGELOG.md
```

If no entry exists, abort - the release PR may not have been merged.

## Step 2: Check Tag Doesn't Exist

```bash
git tag -l "v${VERSION}"
```

If the tag already exists, inform the user and ask if they want to view the release instead.

## Step 3: Create Annotated Tag

Generate a brief summary from the CHANGELOG for the tag message:

```bash
# Extract the first category and its first item from this version's section
SUMMARY=$(sed -n "/## \[${VERSION}\]/,/## \[/p" CHANGELOG.md | grep "^- " | head -1 | sed 's/^- //' | cut -c1-60)
echo "Tag summary: ${SUMMARY}"
```

Create the tag:

```bash
git tag -a "v${VERSION}" -m "Release v${VERSION} - ${SUMMARY}"
```

## Step 4: Push Tag

```bash
git push origin "v${VERSION}"
```

## Step 5: Create GitHub Release

Create the GitHub release using the changelog content:

```bash
# Extract changelog section for this version
NOTES=$(sed -n "/## \[${VERSION}\]/,/## \[/p" CHANGELOG.md | sed '$ d')

# Create GitHub release
gh release create "v${VERSION}" --title "v${VERSION}" --notes "$NOTES"
```

## Step 6: Confirm Release

Provide the release URL:

```bash
# Get repo URL
REPO_URL=$(gh repo view --json url --jq '.url')
echo "Release available at: ${REPO_URL}/releases/tag/v${VERSION}"
```

Output:

```text
Tagged and pushed v${VERSION}

Release created at:
  ${REPO_URL}/releases/tag/v${VERSION}

To view the release:
  gh release view v${VERSION}
```

## Error Handling

- If not on main: checkout main first
- If version not in plugin.json: abort, suggest running /release first
- If version not in CHANGELOG: abort, release PR may not be merged
- If tag exists: show existing tag info, don't recreate
- If push fails: provide manual push command
