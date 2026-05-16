---
description: create a release PR (auto-detects previous tag)
---

# Release Automation

Automate the full release process: generate notes, update files, create branch, and open PR.

No arguments required - automatically detects the previous tag.

---

## Versioning Overview

Beagle has two version locations:
1. **marketplace.json metadata.version** (`.claude-plugin/marketplace.json`) - Main release version, matches repo tags
2. **Per-plugin plugin.json version** (`plugins/<name>/.claude-plugin/plugin.json`) - Individual plugin versions, bumped when that plugin's files change

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

### Step 3.5: Verify CHANGELOG footer compare links (HARD GATE)

This is the enforcement gate for footer compare links. `beagle-core:gen-release-notes` Step 6 is the source-of-truth gate; this step re-runs it here so the release flow fails even if `gen-release-notes` was bypassed, skipped, or its gate was ignored. Both `grep -q` checks below must exit 0 or the release flow stops. This step is **not** advisory — do not paraphrase, do not summarize, do not skip.

Run this block exactly:

```bash
# Extract NEW and PREV versions from the staged CHANGELOG.md.
# We only match numeric `## [X.Y.Z]` headings so `## [Unreleased]` is skipped.
NEW_VERSION=$(grep -m1 -E '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' CHANGELOG.md | sed -E 's/^## \[([0-9]+\.[0-9]+\.[0-9]+)\].*/\1/')
PREV_VERSION=$(grep -m2 -E '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' CHANGELOG.md | sed -n '2p' | sed -E 's/^## \[([0-9]+\.[0-9]+\.[0-9]+)\].*/\1/')

if [ -z "$NEW_VERSION" ] || [ -z "$PREV_VERSION" ]; then
  echo "GATE FAIL: could not extract NEW_VERSION ($NEW_VERSION) or PREV_VERSION ($PREV_VERSION) from CHANGELOG.md"
  exit 1
fi

echo "Gating footer compare links: NEW=v${NEW_VERSION}, PREV=v${PREV_VERSION}"

# Escape dots so they match literally inside the regex.
NEW_RE=${NEW_VERSION//./\\.}
PREV_RE=${PREV_VERSION//./\\.}

# Check 1: the new [NEW_VERSION] footer line exists and points PREV->NEW.
grep -qE "^\[${NEW_RE}\]: .*compare/v${PREV_RE}\.\.\.v${NEW_RE}\$" CHANGELOG.md \
  || { echo "GATE FAIL: missing footer line: [${NEW_VERSION}]: .../compare/v${PREV_VERSION}...v${NEW_VERSION}"; exit 1; }

# Check 2: the [Unreleased] footer line is advanced to compare from the new tag.
grep -qE "^\[Unreleased\]: .*compare/v${NEW_RE}\.\.\.HEAD\$" CHANGELOG.md \
  || { echo "GATE FAIL: [Unreleased] is not advanced; expected: [Unreleased]: .../compare/v${NEW_VERSION}...HEAD"; exit 1; }

echo "Footer compare links verified: [${NEW_VERSION}] and [Unreleased] both present and correct."
```

**Pass condition (objective):** both `grep -q` invocations above exit 0 against the staged `CHANGELOG.md`. The block must print `Footer compare links verified: ...` and exit 0.

**On fail:** the gate names the missing or wrong line. Edit `CHANGELOG.md` to add the missing lines using the diff format documented in `beagle-core:gen-release-notes` Step 5 item 3 (advance `[Unreleased]` to compare from the new tag, insert a new `[NEW_VERSION]` line comparing PREV to NEW). Re-run the block above. **Do not proceed to Step 4 until the block exits 0.**

## Step 4: Update Versions

After determining the new version from the changelog analysis:

### 4a. Update marketplace.json metadata.version

```bash
# Extract the new version from CHANGELOG.md (first version entry after Unreleased)
VERSION=$(grep -E '^\#\# \[[0-9]+\.[0-9]+\.[0-9]+\]' CHANGELOG.md | head -1 | sed 's/.*\[\(.*\)\].*/\1/')
echo "New version: $VERSION"

# Update marketplace.json metadata.version
jq --arg v "$VERSION" '.metadata.version = $v' .claude-plugin/marketplace.json > .claude-plugin/marketplace.json.tmp && mv .claude-plugin/marketplace.json.tmp .claude-plugin/marketplace.json
```

### 4b. Bump affected plugin versions

Identify which plugins had files changed since the previous tag:

```bash
git diff ${PREV_TAG}..HEAD --name-only | grep '^plugins/' | sed 's|plugins/\([^/]*\)/.*|\1|' | sort -u
```

For each affected plugin, bump the minor version in `plugins/<name>/.claude-plugin/plugin.json` (minor for features, patch for fixes). Read each plugin.json, determine the appropriate bump, and update.

Present the version changes to the user for confirmation before proceeding:

| Location | Old Version | New Version |
|----------|-------------|-------------|
| `.claude-plugin/marketplace.json` metadata.version | X.Y.Z | A.B.C |
| `plugins/<name>/.claude-plugin/plugin.json` | X.Y.Z | A.B.C |
| ... | ... | ... |

## Step 5: Create Release Branch

After the files are updated:

```bash
# Create and checkout release branch
git checkout -b "chore/release-${VERSION}"
```

## Step 6: Commit Changes

Commit all updated version files:

```bash
git add CHANGELOG.md .claude-plugin/marketplace.json
# Also stage all affected plugin.json files
git add plugins/*/.claude-plugin/plugin.json
git commit -m "chore(release): ${VERSION}"
```

## Step 7: Push and Create PR

Push the branch and create a pull request:

```bash
git push -u origin "chore/release-${VERSION}"
```

Create the PR with this structure (include all version locations that were updated):

```bash
gh pr create --title "chore(release): ${VERSION}" --body "$(cat <<'EOF'
## Summary

- Bump version to ${VERSION}
- Update CHANGELOG.md with changes since ${PREV_TAG}

## Version Locations Updated

- [x] `.claude-plugin/marketplace.json` metadata.version → ${VERSION}
- [x] `plugins/<name>/.claude-plugin/plugin.json` → X.Y.Z (list each affected plugin)

## Post-merge Steps

After merging, run:
```
/release-tag ${VERSION}
```

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
