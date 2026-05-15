# Beagle for Codex

Install Beagle by linking each plugin's `skills/` directory into Codex's skill path.

```bash
repo=/path/to/beagle
dest="$HOME/.agents/skills"
mkdir -p "$dest"

for plugin in beagle-ai beagle-analysis beagle-core beagle-docs beagle-elixir beagle-go beagle-ios beagle-python beagle-react beagle-remix-v2 beagle-rust beagle-testing; do
  ln -sfn "$repo/plugins/$plugin/skills" "$dest/$plugin"
done
```

Example:

```bash
ln -sfn "/path/to/beagle/plugins/beagle-core/skills" "$HOME/.agents/skills/beagle-core"
```

Windows junction example:

```bat
mklink /J "%USERPROFILE%\.agents\skills\beagle-core" "C:\path\to\beagle\plugins\beagle-core\skills"
```

Update note: `git pull` in the Beagle checkout updates installed skills immediately because the links point into the repo.
