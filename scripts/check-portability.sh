#!/usr/bin/env bash
#
# check-portability.sh — Portability validator for Beagle skills.
#
# Greps every SKILL.md under plugins/*/skills/ for non-portable patterns that
# tie a skill to a specific agent harness (Claude Code, the Skill/Task tools,
# plugin-namespace invocations) or use non-spec frontmatter keys.
#
# Exits non-zero if ANY hit is found, printing each as path:linenum:matchedline.
# Exits 0 and prints "PORTABILITY OK" only when fully clean.

set -uo pipefail

# Resolve repo root so the script works from anywhere.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

failed=0

# Collect every SKILL.md under plugins/*/skills/ (the 144 skill entrypoints).
# Reference .md files are intentionally NOT scanned — only SKILL.md.
# Built with a portable while-read loop (macOS ships bash 3.2 — no mapfile).
SKILL_FILES=()
while IFS= read -r f; do
  SKILL_FILES+=("$f")
done < <(find plugins/*/skills -type f -name 'SKILL.md' | sort)

if [[ "${#SKILL_FILES[@]}" -eq 0 ]]; then
  echo "ERROR: no SKILL.md files found under plugins/*/skills/" >&2
  exit 2
fi

# run_check LABEL grep-args...
# Runs grep with the given args over every SKILL.md. Prints a labeled header
# and the hits when any are found, and flips the global failure flag.
# Passing /dev/null guarantees grep always prints the filename prefix
# (path:linenum:line), even if only one SKILL.md happened to be collected.
run_check() {
  local label="$1"
  shift
  local hits
  hits="$(grep -nE "$@" "${SKILL_FILES[@]}" /dev/null 2>/dev/null)"
  if [[ -n "${hits}" ]]; then
    echo "### FAIL: ${label}"
    echo "${hits}"
    echo
    failed=1
  fi
}

# 1. Literal Skill-tool invocation: Skill(skill:
run_check "Skill-tool invocation 'Skill(skill:'" 'Skill\(skill:'

# 2. Slash invocation e.g. /beagle-core:foo
run_check "Slash invocation '/beagle-<plugin>:'" '/beagle-[a-z]+:'

# 3. Plugin-namespace tokens e.g. beagle-rust:review-verification-protocol
#    (also catches the slash form from #2 — acceptable per spec)
run_check "Plugin-namespace token 'beagle-<plugin>:<skill>'" 'beagle-[a-z]+:[a-z-]+'

# 4. Named harness tools as instructions (case-SENSITIVE — these are proper
#    nouns for Claude's tools). Case-sensitivity is deliberate: it excludes
#    allow-listed lowercase framework API references such as DeepAgents'
#    "task tool" in beagle-ai, while every real Claude reference is capitalized.
run_check "Named harness tool phrasing ('Task tool' / 'Skill tool')" 'Task tool|Skill tool'

# 5. 'Claude Code' as the executing agent (case-sensitive)
run_check "Literal 'Claude Code'" 'Claude Code'

# 6. Co-Authored-By: Claude
run_check "Co-Authored-By: Claude" 'Co-Authored-By: Claude'

# 7. Generated with [Claude
run_check "Generated with [Claude" 'Generated with \[Claude'

# 8. Non-spec frontmatter keys at line start (allow leading spaces)
run_check "Non-spec frontmatter key (autoContext/dependencies/triggers)" '^[[:space:]]*(autoContext|dependencies|triggers):'

if [[ "${failed}" -ne 0 ]]; then
  echo "PORTABILITY CHECK FAILED"
  exit 1
fi

echo "PORTABILITY OK"
exit 0
