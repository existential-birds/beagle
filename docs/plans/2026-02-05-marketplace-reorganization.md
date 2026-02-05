# Marketplace Reorganization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Reorganize beagle from a single monolithic plugin into a marketplace with multiple focused plugins, starting with beagle-elixir.

**Architecture:** Convert the repo structure to a marketplace with `plugins/` subdirectory. Each language/domain becomes its own plugin with skills and commands. Users install only what they need via `/plugin install beagle-elixir@existential-birds`.

**Tech Stack:** Claude Code plugin system, marketplace.json, plugin.json manifests

---

## Task 1: Create Marketplace Structure

**Files:**
- Create: `plugins/` directory
- Create: `.claude-plugin/marketplace.json`
- Modify: `.claude-plugin/plugin.json` (update for marketplace)

**Step 1: Create plugins directory**

```bash
mkdir -p plugins
```

**Step 2: Create marketplace.json**

Create `.claude-plugin/marketplace.json`:

```json
{
  "name": "existential-birds",
  "owner": {
    "name": "Existential Birds, LLC",
    "email": "tech@existentialbirds.com"
  },
  "metadata": {
    "description": "Code review skills and workflows for modern development",
    "pluginRoot": "./plugins"
  },
  "plugins": []
}
```

**Step 3: Verify structure**

```bash
ls -la .claude-plugin/
cat .claude-plugin/marketplace.json | jq .
```

**Step 4: Commit**

```bash
git add .claude-plugin/marketplace.json plugins/
git commit -m "feat(marketplace): initialize marketplace structure"
```

---

## Task 2: Create beagle-elixir Plugin Structure

**Files:**
- Create: `plugins/beagle-elixir/.claude-plugin/plugin.json`
- Create: `plugins/beagle-elixir/skills/` (directory)
- Create: `plugins/beagle-elixir/commands/` (directory)

**Step 1: Create plugin directories**

```bash
mkdir -p plugins/beagle-elixir/.claude-plugin
mkdir -p plugins/beagle-elixir/skills
mkdir -p plugins/beagle-elixir/commands
```

**Step 2: Create plugin.json for beagle-elixir**

Create `plugins/beagle-elixir/.claude-plugin/plugin.json`:

```json
{
  "name": "beagle-elixir",
  "description": "Elixir, Phoenix, and LiveView code review skills",
  "version": "1.0.0",
  "author": {
    "name": "Existential Birds, LLC",
    "email": "tech@existentialbirds.com"
  },
  "repository": "https://github.com/existential-birds/beagle",
  "keywords": [
    "elixir",
    "phoenix",
    "liveview",
    "oban",
    "ecto",
    "exunit",
    "code-review"
  ]
}
```

**Step 3: Verify structure**

```bash
ls -la plugins/beagle-elixir/
cat plugins/beagle-elixir/.claude-plugin/plugin.json | jq .
```

**Step 4: Commit**

```bash
git add plugins/beagle-elixir/
git commit -m "feat(beagle-elixir): create plugin structure"
```

---

## Task 3: Copy Elixir Skills to Plugin

**Files:**
- Copy: `skills/elixir-code-review/` → `plugins/beagle-elixir/skills/elixir-code-review/`
- Copy: `skills/elixir-security-review/` → `plugins/beagle-elixir/skills/elixir-security-review/`
- Copy: `skills/elixir-performance-review/` → `plugins/beagle-elixir/skills/elixir-performance-review/`
- Copy: `skills/phoenix-code-review/` → `plugins/beagle-elixir/skills/phoenix-code-review/`
- Copy: `skills/liveview-code-review/` → `plugins/beagle-elixir/skills/liveview-code-review/`
- Copy: `skills/exunit-code-review/` → `plugins/beagle-elixir/skills/exunit-code-review/`

**Step 1: Copy all Elixir-related skills**

```bash
cp -r skills/elixir-code-review plugins/beagle-elixir/skills/
cp -r skills/elixir-security-review plugins/beagle-elixir/skills/
cp -r skills/elixir-performance-review plugins/beagle-elixir/skills/
cp -r skills/phoenix-code-review plugins/beagle-elixir/skills/
cp -r skills/liveview-code-review plugins/beagle-elixir/skills/
cp -r skills/exunit-code-review plugins/beagle-elixir/skills/
```

**Step 2: Verify all skills copied**

```bash
ls -la plugins/beagle-elixir/skills/
# Should show 6 directories
```

**Step 3: Commit**

```bash
git add plugins/beagle-elixir/skills/
git commit -m "feat(beagle-elixir): copy elixir skills to plugin"
```

---

## Task 4: Copy Elixir Command to Plugin

**Files:**
- Copy: `commands/review-elixir.md` → `plugins/beagle-elixir/commands/review-elixir.md`

**Step 1: Copy command**

```bash
cp commands/review-elixir.md plugins/beagle-elixir/commands/
```

**Step 2: Verify command copied**

```bash
ls -la plugins/beagle-elixir/commands/
cat plugins/beagle-elixir/commands/review-elixir.md | head -5
```

**Step 3: Commit**

```bash
git add plugins/beagle-elixir/commands/
git commit -m "feat(beagle-elixir): copy review-elixir command to plugin"
```

---

## Task 5: Update Skill References in Command

**Files:**
- Modify: `plugins/beagle-elixir/commands/review-elixir.md`

The command references skills with `beagle:` prefix. Since this is now a standalone plugin, we need to update the skill references to use the new plugin name prefix `beagle-elixir:`.

**Step 1: Update skill references**

In `plugins/beagle-elixir/commands/review-elixir.md`, replace:
- `beagle:elixir-code-review` → `beagle-elixir:elixir-code-review`
- `beagle:phoenix-code-review` → `beagle-elixir:phoenix-code-review`
- `beagle:liveview-code-review` → `beagle-elixir:liveview-code-review`
- `beagle:elixir-performance-review` → `beagle-elixir:elixir-performance-review`
- `beagle:elixir-security-review` → `beagle-elixir:elixir-security-review`
- `beagle:exunit-code-review` → `beagle-elixir:exunit-code-review`

Keep `beagle:review-verification-protocol` as-is (from core plugin).

**Step 2: Verify changes**

```bash
grep -n "beagle-elixir:" plugins/beagle-elixir/commands/review-elixir.md
grep -n "beagle:" plugins/beagle-elixir/commands/review-elixir.md
# Should show review-verification-protocol still uses beagle: prefix
```

**Step 3: Commit**

```bash
git add plugins/beagle-elixir/commands/review-elixir.md
git commit -m "fix(beagle-elixir): update skill references to use plugin prefix"
```

---

## Task 6: Register beagle-elixir in Marketplace

**Files:**
- Modify: `.claude-plugin/marketplace.json`

**Step 1: Add beagle-elixir to plugins array**

Update `.claude-plugin/marketplace.json` plugins array:

```json
{
  "name": "existential-birds",
  "owner": {
    "name": "Existential Birds, LLC",
    "email": "tech@existentialbirds.com"
  },
  "metadata": {
    "description": "Code review skills and workflows for modern development",
    "pluginRoot": "./plugins"
  },
  "plugins": [
    {
      "name": "beagle-elixir",
      "source": "beagle-elixir",
      "description": "Elixir, Phoenix, and LiveView code review skills",
      "category": "backend",
      "tags": ["elixir", "phoenix", "liveview", "code-review"]
    }
  ]
}
```

**Step 2: Validate marketplace structure**

```bash
cat .claude-plugin/marketplace.json | jq .
```

**Step 3: Commit**

```bash
git add .claude-plugin/marketplace.json
git commit -m "feat(marketplace): register beagle-elixir plugin"
```

---

## Task 7: Update CHANGELOG and Version

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `.claude-plugin/plugin.json`

**Step 1: Add changelog entry**

Add to `CHANGELOG.md` under a new version section:

```markdown
## [1.14.0] - 2026-02-05

### Added
- Marketplace structure for selective plugin installation
- `beagle-elixir` plugin: standalone Elixir/Phoenix/LiveView code review
  - Skills: elixir-code-review, elixir-security-review, elixir-performance-review
  - Skills: phoenix-code-review, liveview-code-review, exunit-code-review
  - Command: review-elixir

### Changed
- Repository now functions as both a plugin and a marketplace
- Users can install individual plugins via `/plugin install beagle-elixir@existential-birds`
```

**Step 2: Bump version in plugin.json**

Update `.claude-plugin/plugin.json` version from `1.13.0` to `1.14.0`.

**Step 3: Commit**

```bash
git add CHANGELOG.md .claude-plugin/plugin.json
git commit -m "chore(release): v1.14.0 marketplace with beagle-elixir"
```

---

## Task 8: Verify Plugin Works

**Step 1: Validate marketplace**

```bash
# From project root
ls -la .claude-plugin/
cat .claude-plugin/marketplace.json | jq '.plugins | length'
# Should output: 1
```

**Step 2: Validate beagle-elixir plugin structure**

```bash
ls -la plugins/beagle-elixir/.claude-plugin/
ls -la plugins/beagle-elixir/skills/
ls -la plugins/beagle-elixir/commands/
```

**Step 3: Verify skill files exist**

```bash
for skill in elixir-code-review elixir-security-review elixir-performance-review phoenix-code-review liveview-code-review exunit-code-review; do
  if [ -f "plugins/beagle-elixir/skills/$skill/SKILL.md" ]; then
    echo "✓ $skill"
  else
    echo "✗ $skill MISSING"
  fi
done
```

Expected output:
```
✓ elixir-code-review
✓ elixir-security-review
✓ elixir-performance-review
✓ phoenix-code-review
✓ liveview-code-review
✓ exunit-code-review
```

**Step 4: Final commit if any cleanup needed**

No commit if verification passes.

---

## Summary

After completing all tasks:

1. Marketplace structure exists at `.claude-plugin/marketplace.json`
2. `beagle-elixir` plugin is in `plugins/beagle-elixir/`
3. Plugin contains 6 skills and 1 command
4. Skill references updated for standalone use
5. Version bumped and changelog updated

**Installation command for users:**
```
/plugin marketplace add existential-birds/beagle
/plugin install beagle-elixir@existential-birds
```
