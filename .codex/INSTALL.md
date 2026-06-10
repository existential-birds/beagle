# Beagle for Codex

Install Beagle by linking active skill directories into Codex's flat skill path. Codex has no plugin namespace, so duplicated skill names are resolved to one canonical link.

```bash
repo=/path/to/beagle
dest="$HOME/.agents/skills"
mkdir -p "$dest"

for plugin in beagle-analysis beagle-core beagle-docs beagle-elixir beagle-go beagle-ios beagle-python beagle-react beagle-rust beagle-testing; do
  for skill in "$repo/plugins/$plugin/skills"/*; do
    [ -d "$skill" ] || continue
    name="$(basename "$skill")"
    target="$dest/$name"

    # Codex has no plugin namespace. Use the canonical core copy for this
    # shared skill name and leave framework-local copies in the repo.
    if [ "$name" = "review-verification-protocol" ] && [ "$plugin" != "beagle-core" ]; then
      continue
    fi

    if [ -e "$target" ] || [ -L "$target" ]; then
      existing="$(readlink "$target" || true)"
      if [ "$existing" != "$skill" ]; then
        echo "Duplicate skill name: $name" >&2
        echo "Already linked: $existing" >&2
        echo "New source: $skill" >&2
        exit 1
      fi
    fi

    ln -sfn "$skill" "$target"
  done
done
```

Example:

```bash
ln -sfn "/path/to/beagle/plugins/beagle-core/skills/receive-feedback" "$HOME/.agents/skills/receive-feedback"
```

Windows junction example:

```bat
mklink /J "%USERPROFILE%\.agents\skills\receive-feedback" "C:\path\to\beagle\plugins\beagle-core\skills\receive-feedback"
```

Update note: `git pull` in the Beagle checkout updates already-linked skills immediately because the links point into the repo. Re-run the install loop after pulling to link any newly added skills — per-skill links are not created automatically.
