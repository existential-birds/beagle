# Default Skip Patterns

The subagent's default denylist. Applied without the caller re-specifying. Every skipped path is recorded under the `paths_skipped` frontmatter field so the audit trail shows exactly what was excluded.

Three groups: sensitive, binary/media, vendor/build.

## Sensitive

Secrets, credentials, and user-level config. Never scanned.

- `.env`, `.env.*`
- `*.pem`, `*.key`, `*.p12`, `*.pfx`, `*.crt`, `*.cer`
- `.aws/`, `.ssh/`, `.gnupg/`
- `credentials.*`, `secrets.*`
- `*.htpasswd`, `*.netrc`

## Binary / media

Formats the first version does not parse. Passed over without an error. `beagle-core:docling` is the future path for richer parsing (PDF / DOCX / PPTX) when a caller needs it.

- Images: `*.png`, `*.jpg`, `*.jpeg`, `*.gif`, `*.webp`, `*.ico`, `*.svg`, `*.bmp`, `*.tiff`
- Documents: `*.pdf`, `*.docx`, `*.doc`, `*.pptx`, `*.ppt`, `*.xlsx`, `*.xls`
- Archives: `*.zip`, `*.tar`, `*.tar.gz`, `*.tgz`, `*.gz`, `*.bz2`, `*.xz`, `*.7z`, `*.rar`
- Audio/video: `*.mp3`, `*.wav`, `*.flac`, `*.ogg`, `*.mp4`, `*.mov`, `*.mkv`, `*.avi`, `*.webm`
- Databases: `*.sqlite`, `*.sqlite3`, `*.db`
- Binaries: `*.exe`, `*.dll`, `*.so`, `*.dylib`, `*.a`, `*.o`, `*.class`, `*.jar`

## Vendor / build

Generated output and vendored dependencies. Noise, not signal.

- `.git/`
- `node_modules/`
- `.venv/`, `venv/`, `env/`
- `__pycache__/`, `*.pyc`
- `dist/`, `build/`, `out/`, `target/`
- `coverage/`, `.coverage`
- `.next/`, `.nuxt/`, `.svelte-kit/`
- `.cache/`, `.parcel-cache/`
- `vendor/`, `Pods/`
- `.DS_Store`, `Thumbs.db`

## Rules

- **Silent skip, audited record.** Subagents do not stop to explain why a path was skipped. Every skipped path lands in `paths_skipped`.
- **Case-insensitive extension matching.** `.ENV` is skipped just like `.env`.
- **Directory patterns match as prefixes.** `node_modules/` skips everything under it.
- **No runtime extension.** The denylist is read-only during a run. A caller that wants to scan a normally-skipped path passes it explicitly in `paths` — the brief records it, and the subagent reads it. (Explicit caller intent overrides the default.)
- **Sensitive list is non-overridable.** `.env`, `*.pem`, `*.key`, and credential files are always skipped even when explicitly passed. If a caller needs those contents, they paste them in directly rather than routing through this skill.
