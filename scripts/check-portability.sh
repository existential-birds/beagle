#!/usr/bin/env bash
#
# check-portability.sh — Portability, frontmatter, layout, and link validator for Beagle skills.
#
# Enforces 5 validation gates across skills/ and active repository docs/templates:
#   Gate 1: Vanilla Agent Skills layout preconditions (no plugins/, no junk caches, clean skill dirs)
#   Gate 2: Harness-portability regex checks over skills/**/*.md
#   Gate 3: Legacy install/marketplace pattern checks over skills/**/*.md, root docs, and .github/ templates
#   Gate 4: agentskills.io YAML frontmatter & <500-line checks over skills/*/SKILL.md
#   Gate 5: Relative markdown link & GitHub #anchor heading validation over skills/**/*.md and active docs
#
# Compatible with macOS bash 3.2 and zsh.
# Exits 2 on structural precondition errors, 1 on validation failures, 0 ("PORTABILITY OK") when clean.

set -uo pipefail

# Resolve repo root so the script works from anywhere (bash 3.2 + zsh compatible).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

failed=0

# ---------------------------------------------------------------------------
# Gate 1: Layout Preconditions
# ---------------------------------------------------------------------------
if [[ -e plugins ]]; then
  echo "### FAIL: Legacy 'plugins/' directory still exists"
  failed=1
fi

SKILL_MD_FILES=()
while IFS= read -r f; do
  [[ -n "${f}" ]] && SKILL_MD_FILES+=("$f")
done < <(find skills -maxdepth 2 -mindepth 2 -type f -name 'SKILL.md' 2>/dev/null | sort)

SKILL_FILES=()
while IFS= read -r f; do
  [[ -n "${f}" ]] && SKILL_FILES+=("$f")
done < <(find skills -type f -name '*.md' 2>/dev/null | sort)

if [[ "${#SKILL_MD_FILES[@]}" -eq 0 ]] || [[ "${#SKILL_FILES[@]}" -eq 0 ]]; then
  echo "ERROR: no SKILL.md files found under skills/" >&2
  exit 2
fi

STRAY_DIRS=()
for d in skills scripts .github assets; do
  if [[ -d "${d}" ]]; then
    STRAY_DIRS+=("${d}")
  fi
done
STRAY_SUBTREE_JUNK=""
if [[ "${#STRAY_DIRS[@]}" -gt 0 ]]; then
  STRAY_SUBTREE_JUNK="$(find "${STRAY_DIRS[@]}" \( -name '__pycache__' -o -name '*.pyc' -o -name '*.pyo' -o -name '.DS_Store' -o -name '.pytest_cache' \) 2>/dev/null || true)"
fi
STRAY_TOP_JUNK="$(find . -maxdepth 1 -mindepth 1 \( -name '__pycache__' -o -name '*.pyc' -o -name '*.pyo' -o -name '.DS_Store' -o -name '.pytest_cache' \) 2>/dev/null | sed 's|^\./||' || true)"
STRAY_JUNK="$(printf '%s\n%s\n' "${STRAY_TOP_JUNK}" "${STRAY_SUBTREE_JUNK}" | grep -v '^$' | sort || true)"
if [[ -n "${STRAY_JUNK}" ]]; then
  echo "### FAIL: Stray cache/system files in repository"
  echo "${STRAY_JUNK}"
  echo
  failed=1
fi

STRAY_ROOT_FILES="$(find skills -maxdepth 1 -mindepth 1 -type f 2>/dev/null | sort)"
if [[ -n "${STRAY_ROOT_FILES}" ]]; then
  echo "### FAIL: Unexpected files directly under skills/"
  echo "${STRAY_ROOT_FILES}"
  echo
  failed=1
fi

EXTRA_ROOT_FILES="$(find skills -maxdepth 2 -mindepth 2 -type f ! -name 'SKILL.md' 2>/dev/null | sort)"
if [[ -n "${EXTRA_ROOT_FILES}" ]]; then
  echo "### FAIL: Unexpected files beside SKILL.md (use references/, scripts/, or assets/)"
  echo "${EXTRA_ROOT_FILES}"
  echo
  failed=1
fi

UNEXPECTED_SUBDIRS="$(find skills -maxdepth 2 -mindepth 2 -type d ! -name 'references' ! -name 'scripts' ! -name 'assets' 2>/dev/null | sort)"
if [[ -n "${UNEXPECTED_SUBDIRS}" ]]; then
  echo "### FAIL: Unexpected subdirectories under skills/<name>/ (expected references, scripts, assets)"
  echo "${UNEXPECTED_SUBDIRS}"
  echo
  failed=1
fi

# Collect active root docs & .github/ templates (excluding historical CHANGELOG.md)
DOC_FILES=()
for doc in README.md SKILLS.md AGENTS.md llms.txt CONTRIBUTING.md PRIVACY.md .github/PULL_REQUEST_TEMPLATE.md; do
  if [[ -f "${doc}" ]]; then
    DOC_FILES+=("${doc}")
  fi
done
while IFS= read -r f; do
  [[ -n "${f}" ]] && DOC_FILES+=("$f")
done < <(find .github/ISSUE_TEMPLATE -type f \( -name '*.md' -o -name '*.yml' -o -name '*.yaml' \) 2>/dev/null | sort)

run_grep_check() {
  local label="$1"
  local mode="$2"
  local pattern="$3"
  shift 3
  if [[ "$#" -eq 0 ]]; then
    return 0
  fi
  local hits=""
  if [[ "${mode}" == "ci" ]]; then
    hits="$(grep -niE "${pattern}" "$@" /dev/null 2>/dev/null || true)"
  else
    hits="$(grep -nE "${pattern}" "$@" /dev/null 2>/dev/null || true)"
  fi
  if [[ -n "${hits}" ]]; then
    echo "### FAIL: ${label}"
    echo "${hits}"
    echo
    failed=1
  fi
}

# ---------------------------------------------------------------------------
# Gate 2: Existing Harness-Portability Checks over skills/**/*.md
# ---------------------------------------------------------------------------
run_grep_check "Skill-tool invocation 'Skill(skill:'" cs 'Skill\(skill:' ${SKILL_FILES[@]+"${SKILL_FILES[@]}"}
run_grep_check "Slash invocation '/beagle-<plugin>:'" cs '/beagle-[a-z]+:' ${SKILL_FILES[@]+"${SKILL_FILES[@]}"}
run_grep_check "Plugin-namespace token 'beagle-<plugin>:<skill>'" cs 'beagle-[a-z]+:[a-z-]+' ${SKILL_FILES[@]+"${SKILL_FILES[@]}"}
run_grep_check "Named harness tool phrasing ('<Tool> tool' / AskUserQuestion)" cs \
  '(Task|Skill|Edit|Write|Read|Grep|Glob|MultiEdit|NotebookEdit|WebSearch|WebFetch|Agent|Bash) tool|AskUserQuestion' \
  ${SKILL_FILES[@]+"${SKILL_FILES[@]}"}
run_grep_check "Literal 'Claude Code'" cs 'Claude Code' ${SKILL_FILES[@]+"${SKILL_FILES[@]}"}
run_grep_check "Co-Authored-By: Claude" cs 'Co-Authored-By: Claude' ${SKILL_FILES[@]+"${SKILL_FILES[@]}"}
run_grep_check "Generated with [Claude" cs 'Generated with \[Claude' ${SKILL_FILES[@]+"${SKILL_FILES[@]}"}
run_grep_check "Non-spec frontmatter key (autoContext/dependencies/triggers)" cs \
  '^[[:space:]]*(autoContext|dependencies|triggers):' ${SKILL_FILES[@]+"${SKILL_FILES[@]}"}

# ---------------------------------------------------------------------------
# Gate 3: Legacy Install & Marketplace Pattern Checks
# ---------------------------------------------------------------------------
ALL_CHECKED_FILES=(${SKILL_FILES[@]+"${SKILL_FILES[@]}"} ${DOC_FILES[@]+"${DOC_FILES[@]}"})

run_grep_check "Legacy 'claude plugin' command" ci 'claude[[:space:]]+plugin' ${ALL_CHECKED_FILES[@]+"${ALL_CHECKED_FILES[@]}"}
run_grep_check "Legacy '.codex/INSTALL.md' reference" cs '\.codex/INSTALL\.md' ${ALL_CHECKED_FILES[@]+"${ALL_CHECKED_FILES[@]}"}
run_grep_check "Legacy 'README.codex.md' reference" cs 'README\.codex\.md' ${ALL_CHECKED_FILES[@]+"${ALL_CHECKED_FILES[@]}"}
run_grep_check "Legacy '.claude-plugin' reference" cs '\.claude-plugin' ${ALL_CHECKED_FILES[@]+"${ALL_CHECKED_FILES[@]}"}
run_grep_check "Legacy 'plugins/' path reference" cs '(^|[^A-Za-z0-9_./-])plugins/|(^|[^A-Za-z0-9_.-])(\./|(\.\./)+)plugins/' ${ALL_CHECKED_FILES[@]+"${ALL_CHECKED_FILES[@]}"}
run_grep_check "Deprecated 'beagle-ai' reference" cs 'beagle-ai' ${ALL_CHECKED_FILES[@]+"${ALL_CHECKED_FILES[@]}"}
run_grep_check "Legacy '/beagle-' slash command reference" cs '/beagle-' ${ALL_CHECKED_FILES[@]+"${ALL_CHECKED_FILES[@]}"}
run_grep_check "Non-spec frontmatter key in skills (disable-model-invocation/user-invocable)" cs \
  '^[[:space:]]*(disable-model-invocation|user-invocable):' ${SKILL_FILES[@]+"${SKILL_FILES[@]}"}

if [[ "${#DOC_FILES[@]}" -gt 0 ]]; then
  run_grep_check "Legacy frontmatter extension key in active docs (disable-model-invocation/user-invocable)" cs \
    'disable-model-invocation|user-invocable' ${DOC_FILES[@]+"${DOC_FILES[@]}"}
  run_grep_check "Legacy 'CLAUDE.md' reference in active docs/templates" cs 'CLAUDE\.md' ${DOC_FILES[@]+"${DOC_FILES[@]}"}
  run_grep_check "Legacy 'Claude Code' reference in active docs/templates" cs 'Claude Code' ${DOC_FILES[@]+"${DOC_FILES[@]}"}
fi

# ---------------------------------------------------------------------------
# Gate 4 & Gate 5: agentskills.io Frontmatter, <500 Lines, Links & Anchors
# ---------------------------------------------------------------------------
if ! PYTHONDONTWRITEBYTECODE=1 python3 - <<'PY'
import re
import sys
import urllib.parse
from pathlib import Path

try:
    import yaml  # type: ignore
except ImportError:
    yaml = None

REPO_ROOT = Path.cwd().resolve()
ALLOWED_KEYS = {"name", "description", "license", "compatibility", "metadata", "allowed-tools"}
FORBIDDEN_KEYS = {"disable-model-invocation", "user-invocable", "autoContext", "dependencies", "triggers"}
NAME_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")

errors = []

if yaml is not None:
    class UniqueKeySafeLoader(yaml.SafeLoader):
        """YAML SafeLoader that rejects duplicate mapping keys."""

    def _construct_unique_mapping(loader, node, deep=False):
        mapping = {}
        for key_node, value_node in node.value:
            key = loader.construct_object(key_node, deep=deep)
            if key in mapping:
                raise ValueError(f"Duplicate YAML key: {key!r}")
            mapping[key] = loader.construct_object(value_node, deep=deep)
        return mapping

    UniqueKeySafeLoader.add_constructor(
        yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, _construct_unique_mapping
    )


def _scan_quoted_closes(text: str, quote_char: str, skip_opening: bool = False) -> bool:
    """Return True if a single- or double-quoted YAML scalar closes on `text`."""
    i = 1 if skip_opening else 0
    n = len(text)
    if quote_char == '"':
        while i < n:
            if text[i] == "\\" and i + 1 < n:
                i += 2
                continue
            if text[i] == '"':
                return True
            i += 1
        return False
    while i < n:
        if text[i] == "'":
            if i + 1 < n and text[i + 1] == "'":
                i += 2
                continue
            return True
        i += 1
    return False


def _has_unquoted_hash_truncation(fm_lines):
    """Detect unquoted `#` comment truncation inside single-line & multiline plain scalar YAML values."""
    errs = []
    in_block_scalar = False
    block_indent = -1
    in_quote = None
    after_empty_key = False
    empty_key_indent = -1
    empty_key_name = ""
    in_plain_multiline = False
    plain_indent = -1
    plain_key = ""

    for lineno_offset, line in enumerate(fm_lines, start=2):
        if in_quote is not None:
            if _scan_quoted_closes(line, in_quote, skip_opening=False):
                in_quote = None
            continue

        stripped = line.lstrip(" \t")
        indent = len(line) - len(stripped)

        if in_block_scalar:
            if stripped == "" or indent > block_indent:
                continue
            in_block_scalar = False
            block_indent = -1

        if after_empty_key:
            if not stripped or stripped.startswith("#"):
                continue
            if indent > empty_key_indent:
                if stripped[0] in ("|", ">"):
                    in_block_scalar = True
                    block_indent = empty_key_indent
                    after_empty_key = False
                    continue
                if stripped[0] in ('"', "'"):
                    if not _scan_quoted_closes(stripped, stripped[0], skip_opening=True):
                        in_quote = stripped[0]
                    after_empty_key = False
                    continue
                if stripped[0] in ("[", "{"):
                    after_empty_key = False
                    continue
                if re.match(r"^(?:[A-Za-z0-9_-]+\s*:(?:\s|$)|-(?:\s|$))", stripped):
                    after_empty_key = False
                else:
                    in_plain_multiline = True
                    plain_indent = empty_key_indent
                    plain_key = empty_key_name
                    after_empty_key = False
                    if re.search(r"(?:^|\s)#", stripped):
                        errs.append(
                            f"line {lineno_offset}: unquoted '#' in multiline plain scalar for '{plain_key}' truncates value"
                        )
                    continue
            else:
                after_empty_key = False

        if in_plain_multiline:
            if stripped == "":
                continue
            if indent > plain_indent and not re.match(r"^[A-Za-z0-9_-]+\s*:(?:\s|$)", stripped):
                if re.search(r"(?:^|\s)#", stripped):
                    errs.append(
                        f"line {lineno_offset}: unquoted '#' in multiline plain scalar for '{plain_key}' truncates value"
                    )
                continue
            in_plain_multiline = False
            plain_indent = -1
            plain_key = ""

        if not stripped or stripped.startswith("#"):
            continue

        m = re.match(r"^([A-Za-z0-9_-]+)\s*:(.*)$", stripped)
        if not m:
            continue
        key, rest = m.group(1), m.group(2).lstrip()
        if not rest:
            after_empty_key = True
            empty_key_indent = indent
            empty_key_name = key
            continue
        if rest[0] in ("|", ">"):
            in_block_scalar = True
            block_indent = indent
            continue
        if rest[0] in ('"', "'"):
            if not _scan_quoted_closes(rest, rest[0], skip_opening=True):
                in_quote = rest[0]
            continue
        if rest[0] in ("[", "{"):
            continue
        if re.search(r"(?:^|\s)#", rest):
            errs.append(
                f"line {lineno_offset}: unquoted '#' in plain YAML scalar for '{key}' truncates value"
            )
        else:
            in_plain_multiline = True
            plain_indent = indent
            plain_key = key

    return errs


_DOUBLE_ESCAPES = {
    "0": "\x00",
    "a": "\a",
    "b": "\b",
    "t": "\t",
    "\t": "\t",
    "n": "\n",
    "v": "\v",
    "f": "\f",
    "r": "\r",
    "e": "\x1b",
    " ": " ",
    '"': '"',
    "/": "/",
    "\\": "\\",
    "N": "\x85",
    "_": "\xa0",
    "L": "\u2028",
    "P": "\u2029",
}


def _unescape_double_quoted(raw: str) -> str:
    out = []
    i = 0
    n = len(raw)
    while i < n:
        ch = raw[i]
        if ch != "\\":
            out.append(ch)
            i += 1
            continue
        if i + 1 >= n:
            raise ValueError("dangling backslash in double-quoted YAML scalar")
        esc = raw[i + 1]
        if esc in _DOUBLE_ESCAPES:
            out.append(_DOUBLE_ESCAPES[esc])
            i += 2
        elif esc == "x":
            if i + 4 > n:
                raise ValueError("incomplete \\x escape in double-quoted YAML scalar")
            out.append(chr(int(raw[i + 2 : i + 4], 16)))
            i += 4
        elif esc == "u":
            if i + 6 > n:
                raise ValueError("incomplete \\u escape in double-quoted YAML scalar")
            out.append(chr(int(raw[i + 2 : i + 6], 16)))
            i += 6
        elif esc == "U":
            if i + 10 > n:
                raise ValueError("incomplete \\U escape in double-quoted YAML scalar")
            out.append(chr(int(raw[i + 2 : i + 10], 16)))
            i += 10
        else:
            raise ValueError(f"unknown escape sequence '\\{esc}' in double-quoted YAML scalar")
    return "".join(out)


def _fold_quoted_segments(segments) -> str:
    """Fold YAML quoted scalar lines: (text, cont_escaped, trailing_blank_count)."""
    if not segments:
        return ""
    out = []
    for idx, (txt, line_cont, blank_after) in enumerate(segments):
        if idx == 0:
            out.append(txt)
            continue
        prev_txt, prev_cont, prev_blanks = segments[idx - 1]
        if prev_cont:
            out.append(txt)
        elif prev_blanks > 0:
            out.append("\n" * prev_blanks + txt)
        else:
            out.append((" " if out and out[-1] != "" else "") + txt)
    return "".join(out)


def _scan_quoted_block(lines, start_idx: int, first_rest: str, quote_char: str):
    """Parse a single- or double-quoted YAML scalar spanning 1 or more lines."""
    segments = []
    idx = start_idx
    cur = first_rest
    pos = 1

    while True:
        buf = []
        closed = False
        line_cont = False
        n = len(cur)

        if quote_char == '"':
            while pos < n:
                ch = cur[pos]
                if ch == '"':
                    trailing = cur[pos + 1 :].strip()
                    if trailing and not trailing.startswith("#"):
                        raise ValueError(f"unexpected trailing content after closing quote: {trailing!r}")
                    closed = True
                    break
                if ch == "\\":
                    if pos + 1 < n:
                        buf.append(cur[pos : pos + 2])
                        pos += 2
                        continue
                    # Trailing backslash escapes newline (line continuation)
                    line_cont = True
                    pos += 1
                    break
                buf.append(ch)
                pos += 1
        else:
            while pos < n:
                ch = cur[pos]
                if ch == "'":
                    if pos + 1 < n and cur[pos + 1] == "'":
                        buf.append("'")
                        pos += 2
                        continue
                    trailing = cur[pos + 1 :].strip()
                    if trailing and not trailing.startswith("#"):
                        raise ValueError(f"unexpected trailing content after closing quote: {trailing!r}")
                    closed = True
                    break
                buf.append(ch)
                pos += 1

        seg_text = "".join(buf)
        if not closed and not line_cont:
            # Trim unescaped trailing spaces on folded break
            seg_text = seg_text.rstrip(" ")

        if closed:
            segments.append((seg_text, False, 0))
            next_idx = idx + 1
            break

        # Advance to next line, counting blank lines
        idx += 1
        blanks = 0
        while idx < len(lines) and not lines[idx].strip():
            blanks += 1
            idx += 1
        if idx >= len(lines):
            raise ValueError(f"unclosed {quote_char}-quoted YAML scalar")
        segments.append((seg_text, line_cont, blanks))
        cur = lines[idx].lstrip(" ")
        pos = 0

    joined = _fold_quoted_segments(segments)
    if quote_char == '"':
        joined = _unescape_double_quoted(joined)
    return joined, next_idx


def _split_mapping_kv(line_content: str):
    """Split 'key: rest' respecting quoted keys and URLs (colon must be followed by space or EOL)."""
    n = len(line_content)
    if n == 0:
        return None
    if line_content[0] in ('"', "'"):
        q = line_content[0]
        i = 1
        while i < n:
            if q == '"' and line_content[i] == "\\" and i + 1 < n:
                i += 2
                continue
            if line_content[i] == q:
                if q == "'" and i + 1 < n and line_content[i + 1] == "'":
                    i += 2
                    continue
                break
            i += 1
        if i >= n:
            return None
        key_raw = line_content[: i + 1]
        after = line_content[i + 1 :].lstrip(" ")
        if not after.startswith(":"):
            return None
        rest_raw = after[1:]
        if rest_raw and rest_raw[0] == "\t":
            raise ValueError("tab character after ':' is forbidden in YAML")
        if rest_raw and rest_raw[0] != " ":
            return None
        key = _unescape_double_quoted(key_raw[1:-1]) if q == '"' else key_raw[1:-1].replace("''", "'")
        return key, rest_raw.lstrip(" ")

    if line_content[0] in ("[", "{"):
        return None
    i = 0
    while i < n:
        if line_content[i] == ":":
            if i + 1 == n or line_content[i + 1] in (" ", "\t"):
                if i + 1 < n and line_content[i + 1] == "\t":
                    raise ValueError("tab character after ':' is forbidden in YAML")
                key = line_content[:i].strip()
                if not key:
                    return None
                rest_raw = line_content[i + 1 :]
                return key, rest_raw.lstrip(" ")
        i += 1
    return None


def _coerce_plain_scalar(text: str):
    if text == "" or text in ("~", "null", "Null", "NULL"):
        return None
    if text in ("true", "True", "TRUE"):
        return True
    if text in ("false", "False", "FALSE"):
        return False
    if re.fullmatch(r"-?[0-9]+", text):
        try:
            return int(text)
        except ValueError:
            pass
    return text


def _strip_plain_comment(text: str) -> str:
    m = re.search(r"(?:^|\s)#", text)
    if m:
        return text[: m.start()].rstrip()
    return text.rstrip()


def _parse_plain_multiline(lines, start_idx: int, initial, min_indent: int):
    """Parse a single-line or multiline plain scalar."""
    pieces = []
    i = start_idx

    if initial is not None:
        if "\t" in initial:
            raise ValueError("tab character in plain YAML scalar")
        m = re.search(r"(?:^|\s)#", initial)
        if m:
            head = initial[: m.start()].rstrip()
            return _coerce_plain_scalar(head), start_idx
        pieces.append((0, initial.rstrip()))

    while i < len(lines):
        blanks = 0
        j = i
        while j < len(lines) and not lines[j].strip():
            blanks += 1
            j += 1
        if j >= len(lines):
            break
        nxt = lines[j]
        nxt_stripped = nxt.lstrip(" ")
        nxt_indent = len(nxt) - len(nxt_stripped)
        if nxt_stripped.startswith("#") or nxt_indent < min_indent:
            break
        if "\t" in nxt_stripped:
            raise ValueError(f"tab character in plain YAML scalar at line: {nxt!r}")
        if _split_mapping_kv(nxt_stripped) is not None:
            raise ValueError(f"mapping values are not allowed in plain scalar at line: {nxt!r}")

        m = re.search(r"(?:^|\s)#", nxt_stripped)
        if m:
            piece = nxt_stripped[: m.start()].rstrip()
            if piece:
                pieces.append((blanks, piece))
            i = j + 1
            break
        pieces.append((blanks, nxt_stripped.rstrip()))
        i = j + 1

    if not pieces:
        return None, i
    if len(pieces) == 1 and initial is not None:
        return _coerce_plain_scalar(pieces[0][1]), i

    out = [pieces[0][1]]
    for blanks, txt in pieces[1:]:
        if blanks == 0:
            out.append(" " + txt)
        else:
            out.append("\n" * blanks + txt)
    joined = "".join(out)
    if len(pieces) == 1:
        return _coerce_plain_scalar(joined), i
    return joined, i


def _parse_block_scalar(lines, start_idx: int, header: str, parent_indent: int):
    header_clean = _strip_plain_comment(header).strip()
    m = re.match(r"^([|>])([+-][1-9]?|[1-9][+-]?)?$", header_clean)
    if not m:
        raise ValueError(f"invalid block scalar header: {header!r}")
    fold = m.group(1) == ">"
    mod = m.group(2) or ""
    chomp = "-" if "-" in mod else ("+" if "+" in mod else "")
    digits = [c for c in mod if c.isdigit()]
    explicit_indent = int(digits[0]) if digits else None

    i = start_idx + 1
    raw_lines = []
    block_indent = (parent_indent + explicit_indent) if explicit_indent is not None else None

    if block_indent is None:
        while i < len(lines) and not lines[i].strip():
            raw_lines.append("")
            i += 1
        if i < len(lines):
            cur_indent = len(lines[i]) - len(lines[i].lstrip(" "))
            if cur_indent > parent_indent:
                block_indent = cur_indent

    if block_indent is not None:
        while i < len(lines):
            nxt = lines[i]
            if not nxt.strip():
                raw_lines.append("")
                i += 1
                continue
            cur_indent = len(nxt) - len(nxt.lstrip(" "))
            if cur_indent < block_indent:
                break
            raw_lines.append(nxt[block_indent:])
            i += 1

    trailing_blanks = 0
    while raw_lines and raw_lines[-1] == "":
        raw_lines.pop()
        trailing_blanks += 1

    if not raw_lines:
        return ("\n" * trailing_blanks if chomp == "+" else ""), i

    if not fold:
        body = "\n".join(raw_lines)
    else:
        parts = []
        idx = 0
        while idx < len(raw_lines):
            cur_line = raw_lines[idx]
            if cur_line == "":
                blanks = 0
                while idx < len(raw_lines) and raw_lines[idx] == "":
                    blanks += 1
                    idx += 1
                parts.append("\n" * blanks)
                continue
            is_indented = cur_line[0] in (" ", "\t")
            if parts and not parts[-1].endswith("\n"):
                prev_indented = idx > 0 and raw_lines[idx - 1] != "" and raw_lines[idx - 1][0] in (" ", "\t")
                if is_indented or prev_indented:
                    parts.append("\n" + cur_line)
                else:
                    parts.append(" " + cur_line)
            else:
                parts.append(cur_line)
            idx += 1
        body = "".join(parts)

    if chomp == "-":
        return body, i
    if chomp == "+":
        return body + "\n" * (1 + trailing_blanks), i
    return body + "\n", i


def _collect_flow_block(lines, start_idx: int, initial_rest: str):
    """Collect a single-line or multiline YAML flow collection [...] or {...}."""
    stack = []
    in_quote = None
    chunks = []
    idx = start_idx

    while idx < len(lines):
        line = initial_rest if idx == start_idx else lines[idx]
        pos = 0
        n = len(line)
        closed_at = -1

        while pos < n:
            ch = line[pos]
            if in_quote == '"':
                if ch == "\\":
                    if pos + 1 < n:
                        pos += 2
                        continue
                    pos += 1
                    break
                if ch == '"':
                    in_quote = None
                pos += 1
            elif in_quote == "'":
                if ch == "'":
                    if pos + 1 < n and line[pos + 1] == "'":
                        pos += 2
                        continue
                    in_quote = None
                pos += 1
            else:
                if ch == "#" and (
                    (idx > start_idx and pos == 0) or (pos > 0 and line[pos - 1] in (" ", "\t"))
                ):
                    break
                if ch == "[":
                    stack.append("]")
                elif ch == "{":
                    stack.append("}")
                elif ch in ("]", "}"):
                    if not stack or stack[-1] != ch:
                        raise ValueError(f"mismatched {ch!r} in flow collection")
                    stack.pop()
                    if not stack:
                        closed_at = pos
                        break
                elif ch in ('"', "'"):
                    in_quote = ch
                pos += 1

        if closed_at != -1:
            trailing = line[closed_at + 1 :].strip()
            if trailing and not trailing.startswith("#"):
                raise ValueError(f"unexpected trailing content after flow collection: {trailing!r}")
            chunks.append(line[: closed_at + 1])
            return "\n".join(chunks), idx + 1

        chunks.append(line)
        idx += 1

    if in_quote is not None:
        raise ValueError(f"unclosed string in flow collection: {initial_rest!r}")
    raise ValueError(f"unclosed flow collection: {initial_rest!r}")


def _parse_flow_quoted(s: str, start_pos: int, quote_char: str):
    """Parse a single- or double-quoted scalar inside a flow collection."""
    n = len(s)
    pos = start_pos + 1
    segments = []
    buf = []
    line_cont = False

    while pos < n:
        c = s[pos]
        if c in ("\r", "\n"):
            if c == "\r" and pos + 1 < n and s[pos + 1] == "\n":
                pos += 1
            seg = "".join(buf) if line_cont else "".join(buf).rstrip(" \t")
            buf = []
            pos += 1
            blanks = 0
            while pos < n:
                k = pos
                while k < n and s[k] in (" ", "\t"):
                    k += 1
                if k < n and s[k] in ("\r", "\n"):
                    blanks += 1
                    pos = k + 2 if (s[k] == "\r" and k + 1 < n and s[k + 1] == "\n") else k + 1
                else:
                    pos = k
                    break
            segments.append((seg, line_cont, blanks))
            line_cont = False
            continue

        if quote_char == '"':
            if c == "\\":
                if pos + 1 < n and s[pos + 1] == "\n":
                    line_cont = True
                    pos += 1
                    continue
                if pos + 2 < n and s[pos + 1] == "\r" and s[pos + 2] == "\n":
                    line_cont = True
                    pos += 1
                    continue
                if pos + 1 < n:
                    buf.append(s[pos : pos + 2])
                    pos += 2
                    continue
                raise ValueError("dangling backslash in double-quoted YAML scalar")
            if c == '"':
                segments.append(("".join(buf), False, 0))
                pos += 1
                joined = _fold_quoted_segments(segments)
                return _unescape_double_quoted(joined), pos
            buf.append(c)
            pos += 1
        else:
            if c == "'":
                if pos + 1 < n and s[pos + 1] == "'":
                    buf.append("'")
                    pos += 2
                    continue
                segments.append(("".join(buf), False, 0))
                pos += 1
                return _fold_quoted_segments(segments), pos
            buf.append(c)
            pos += 1

    raise ValueError(f"unclosed string in flow collection: {s!r}")


def _parse_flow_inline(raw: str):
    """Parse single-line or multiline YAML flow list [...] or mapping {...}."""
    s = raw.strip()
    pos = [0]
    n = len(s)

    def skip_ws():
        while pos[0] < n:
            ch = s[pos[0]]
            if ch in " \t\r\n":
                pos[0] += 1
            elif ch == "#" and (pos[0] == 0 or s[pos[0] - 1] in " \t\r\n"):
                while pos[0] < n and s[pos[0]] != "\n":
                    pos[0] += 1
            else:
                break

    def parse_val():
        skip_ws()
        if pos[0] >= n:
            return None
        ch = s[pos[0]]
        if ch == "[":
            pos[0] += 1
            arr = []
            skip_ws()
            if pos[0] < n and s[pos[0]] == "]":
                pos[0] += 1
                return arr
            while pos[0] < n:
                arr.append(parse_val())
                skip_ws()
                if pos[0] < n and s[pos[0]] == ",":
                    pos[0] += 1
                    skip_ws()
                    if pos[0] < n and s[pos[0]] == "]":
                        pos[0] += 1
                        return arr
                elif pos[0] < n and s[pos[0]] == "]":
                    pos[0] += 1
                    return arr
                else:
                    raise ValueError(f"malformed flow sequence: {s!r}")
            raise ValueError(f"unclosed flow sequence: {s!r}")
        if ch == "{":
            pos[0] += 1
            obj = {}
            skip_ws()
            if pos[0] < n and s[pos[0]] == "}":
                pos[0] += 1
                return obj
            while pos[0] < n:
                k = parse_val()
                skip_ws()
                if pos[0] >= n or s[pos[0]] != ":":
                    raise ValueError(f"expected ':' in flow mapping: {s!r}")
                pos[0] += 1
                v = parse_val()
                if k in obj:
                    raise ValueError(f"Duplicate YAML key: {k!r}")
                obj[k] = v
                skip_ws()
                if pos[0] < n and s[pos[0]] == ",":
                    pos[0] += 1
                    skip_ws()
                    if pos[0] < n and s[pos[0]] == "}":
                        pos[0] += 1
                        return obj
                elif pos[0] < n and s[pos[0]] == "}":
                    pos[0] += 1
                    return obj
                else:
                    raise ValueError(f"malformed flow mapping: {s!r}")
            raise ValueError(f"unclosed flow mapping: {s!r}")
        if ch in ('"', "'"):
            val_q, next_pos = _parse_flow_quoted(s, pos[0], ch)
            pos[0] = next_pos
            return val_q
        start = pos[0]
        while pos[0] < n:
            c = s[pos[0]]
            if c in (",", "]", "}", ":"):
                break
            if c == "#" and pos[0] > 0 and s[pos[0] - 1] in " \t\r\n":
                break
            pos[0] += 1
        plain = re.sub(r"[ \t]*\r?\n[ \t]*", " ", s[start : pos[0]]).strip()
        return _coerce_plain_scalar(plain)

    val = parse_val()
    skip_ws()
    if pos[0] < n and s[pos[0]] == "#":
        while pos[0] < n and s[pos[0]] != "\n":
            pos[0] += 1
        skip_ws()
    if pos[0] != n:
        raise ValueError(f"unexpected trailing characters in flow collection: {s[pos[0]:]!r}")
    return val


def _parse_block(lines, start_idx: int, min_indent: int):
    i = start_idx
    while i < len(lines) and (not lines[i].strip() or lines[i].lstrip(" ").startswith("#")):
        i += 1
    if i >= len(lines):
        return None, i

    indent = len(lines[i]) - len(lines[i].lstrip(" "))
    if indent < min_indent:
        return None, i
    stripped = lines[i][indent:]

    # Sequence block
    if stripped == "-" or stripped.startswith("- "):
        seq_indent = indent
        items = []
        while i < len(lines):
            while i < len(lines) and (not lines[i].strip() or lines[i].lstrip(" ").startswith("#")):
                i += 1
            if i >= len(lines):
                break
            cur_indent = len(lines[i]) - len(lines[i].lstrip(" "))
            if cur_indent < seq_indent:
                break
            if cur_indent > seq_indent:
                raise ValueError(f"unexpected indentation at line: {lines[i]!r}")
            cur_stripped = lines[i][cur_indent:]
            if not (cur_stripped == "-" or cur_stripped.startswith("- ")):
                break

            item_rest = cur_stripped[1:].lstrip(" ")
            if item_rest == "" or item_rest.startswith("#"):
                i += 1
                val, i = _parse_block(lines, i, seq_indent + 1)
                items.append(val)
            elif item_rest[0] in ("|", ">"):
                val, i = _parse_block_scalar(lines, i, item_rest, seq_indent)
                items.append(val)
            elif item_rest[0] in ('"', "'"):
                val, i = _scan_quoted_block(lines, i, item_rest, item_rest[0])
                items.append(val)
            elif item_rest[0] in ("[", "{"):
                raw_flow, i = _collect_flow_block(lines, i, item_rest)
                items.append(_parse_flow_inline(raw_flow))
            elif _split_mapping_kv(item_rest) is not None:
                # Inline mapping starting on '-' line
                sub_lines = [" " * (seq_indent + 2) + item_rest]
                j = i + 1
                while j < len(lines):
                    if not lines[j].strip() or lines[j].lstrip(" ").startswith("#"):
                        sub_lines.append(lines[j])
                        j += 1
                        continue
                    j_ind = len(lines[j]) - len(lines[j].lstrip(" "))
                    if j_ind <= seq_indent:
                        break
                    sub_lines.append(lines[j])
                    j += 1
                val, _ = _parse_block(sub_lines, 0, seq_indent + 2)
                items.append(val)
                i = j
            else:
                val, i = _parse_plain_multiline(lines, i + 1, initial=item_rest, min_indent=seq_indent + 2)
                items.append(val)
        return items, i

    # Mapping block
    kv0 = _split_mapping_kv(stripped)
    if kv0 is None:
        raise ValueError(f"expected 'key: value' at line: {lines[i]!r}")

    map_indent = indent
    mapping = {}
    while i < len(lines):
        while i < len(lines) and (not lines[i].strip() or lines[i].lstrip(" ").startswith("#")):
            i += 1
        if i >= len(lines):
            break
        cur_indent = len(lines[i]) - len(lines[i].lstrip(" "))
        if cur_indent < map_indent:
            break
        if cur_indent > map_indent:
            raise ValueError(f"unexpected indentation at line: {lines[i]!r}")
        cur_stripped = lines[i][cur_indent:]
        if cur_stripped == "-" or cur_stripped.startswith("- "):
            break

        kv = _split_mapping_kv(cur_stripped)
        if kv is None:
            raise ValueError(f"expected 'key: value' at line: {lines[i]!r}")
        key, rest = kv
        if key in mapping:
            raise ValueError(f"Duplicate YAML key: {key!r}")

        if rest == "" or rest.startswith("#"):
            i += 1
            j = i
            while j < len(lines) and (not lines[j].strip() or lines[j].lstrip(" ").startswith("#")):
                j += 1
            if j >= len(lines):
                mapping[key] = None
                i = j
                continue
            nxt_indent = len(lines[j]) - len(lines[j].lstrip(" "))
            nxt_stripped = lines[j][nxt_indent:]
            if nxt_indent == map_indent and (nxt_stripped == "-" or nxt_stripped.startswith("- ")):
                val, i = _parse_block(lines, j, map_indent)
                mapping[key] = val
            elif nxt_indent <= map_indent:
                mapping[key] = None
                i = j
            elif nxt_stripped[0] in ("[", "{"):
                raw_flow, i = _collect_flow_block(lines, j, nxt_stripped)
                mapping[key] = _parse_flow_inline(raw_flow)
            elif nxt_stripped == "-" or nxt_stripped.startswith("- ") or _split_mapping_kv(nxt_stripped) is not None:
                val, i = _parse_block(lines, j, nxt_indent)
                mapping[key] = val
            elif nxt_stripped[0] in ("|", ">"):
                val, i = _parse_block_scalar(lines, j, nxt_stripped, map_indent)
                mapping[key] = val
            elif nxt_stripped[0] in ('"', "'"):
                val, i = _scan_quoted_block(lines, j, nxt_stripped, nxt_stripped[0])
                mapping[key] = val
            else:
                val, i = _parse_plain_multiline(lines, j, initial=None, min_indent=map_indent + 1)
                mapping[key] = val
        elif rest[0] in ("|", ">"):
            val, i = _parse_block_scalar(lines, i, rest, map_indent)
            mapping[key] = val
        elif rest[0] in ('"', "'"):
            val, i = _scan_quoted_block(lines, i, rest, rest[0])
            mapping[key] = val
        elif rest[0] in ("[", "{"):
            raw_flow, i = _collect_flow_block(lines, i, rest)
            mapping[key] = _parse_flow_inline(raw_flow)
        else:
            val, i = _parse_plain_multiline(lines, i + 1, initial=rest, min_indent=map_indent + 1)
            mapping[key] = val

    return mapping, i


def parse_yaml_fallback(fm_text: str):
    """Pure-stdlib YAML subset parser for SKILL.md frontmatter."""
    lines = fm_text.splitlines()
    for idx, line in enumerate(lines, start=2):
        leading = line[: len(line) - len(line.lstrip(" \t"))]
        if "\t" in leading:
            raise ValueError(f"line {idx}: tab indentation is forbidden in YAML")
    val, next_idx = _parse_block(lines, 0, 0)
    while next_idx < len(lines) and (not lines[next_idx].strip() or lines[next_idx].lstrip(" ").startswith("#")):
        next_idx += 1
    if next_idx < len(lines):
        raise ValueError(f"unexpected indentation at line: {lines[next_idx]!r}")
    return val if val is not None else {}


def load_frontmatter(fm_text: str):
    if yaml is not None:
        return yaml.load(fm_text, Loader=UniqueKeySafeLoader)
    return parse_yaml_fallback(fm_text)


# --- Gate 4: Validate skills/*/SKILL.md ---
seen_names = {}
skill_dirs = sorted(p for p in (REPO_ROOT / "skills").iterdir() if p.is_dir())
for sdir in skill_dirs:
    skill_md = sdir / "SKILL.md"
    rel = skill_md.relative_to(REPO_ROOT)
    if not skill_md.is_file():
        errors.append(f"Gate 4: {sdir.relative_to(REPO_ROOT)}: missing SKILL.md")
        continue

    text = skill_md.read_text(encoding="utf-8")
    line_count = len(text.splitlines())
    if line_count >= 500:
        errors.append(f"Gate 4: {rel}: {line_count} lines (must be < 500)")

    fm_match = re.match(r"^---\r?\n(.*?)\r?\n---(?:\r?\n|$)", text, re.DOTALL)
    if not fm_match:
        errors.append(f"Gate 4: {rel}: missing or unclosed YAML frontmatter")
        continue

    fm_text = fm_match.group(1)
    fm_lines = fm_text.splitlines()

    for idx, fline in enumerate(fm_lines, start=2):
        if "\t" in fline:
            errors.append(f"Gate 4: {rel}:{idx}: tab character in YAML frontmatter")

    for hash_err in _has_unquoted_hash_truncation(fm_lines):
        errors.append(f"Gate 4: {rel}: {hash_err}")

    try:
        data = load_frontmatter(fm_text)
    except Exception as exc:
        errors.append(f"Gate 4: {rel}: invalid YAML frontmatter ({exc})")
        continue

    if not isinstance(data, dict):
        errors.append(f"Gate 4: {rel}: frontmatter must be a YAML mapping")
        continue

    keys = set(data.keys())
    forbidden_hit = sorted(keys & FORBIDDEN_KEYS)
    if forbidden_hit:
        errors.append(f"Gate 4: {rel}: forbidden frontmatter key(s): {', '.join(forbidden_hit)}")

    unknown = sorted(keys - ALLOWED_KEYS - FORBIDDEN_KEYS)
    if unknown:
        errors.append(f"Gate 4: {rel}: unexpected frontmatter key(s): {', '.join(unknown)}")

    name = data.get("name")
    if not isinstance(name, str) or not name:
        errors.append(f"Gate 4: {rel}: missing or non-string 'name'")
    else:
        if len(name) > 64:
            errors.append(f"Gate 4: {rel}: 'name' exceeds 64 chars ({len(name)})")
        if not NAME_RE.fullmatch(name):
            errors.append(f"Gate 4: {rel}: 'name' {name!r} violates ^[a-z0-9]+(-[a-z0-9]+)*$")
        if name != sdir.name:
            errors.append(f"Gate 4: {rel}: 'name' {name!r} does not match directory {sdir.name!r}")
        if name in seen_names:
            errors.append(f"Gate 4: {rel}: duplicate 'name' {name!r} (already in {seen_names[name]})")
        else:
            seen_names[name] = str(rel)

    desc = data.get("description")
    if not isinstance(desc, str) or not desc.strip():
        errors.append(f"Gate 4: {rel}: missing or empty 'description'")
    elif len(desc) > 1024:
        errors.append(f"Gate 4: {rel}: 'description' exceeds 1024 chars ({len(desc)})")

    if "compatibility" in data and data["compatibility"] is not None:
        compat = data["compatibility"]
        if not isinstance(compat, str) or len(compat) > 500:
            errors.append(f"Gate 4: {rel}: 'compatibility' must be a string <= 500 chars")

    if "metadata" in data and data["metadata"] is not None:
        meta = data["metadata"]
        if not isinstance(meta, dict):
            errors.append(f"Gate 4: {rel}: 'metadata' must be a mapping")
        elif meta.get("internal") in (True, "true", "True", 1, "1"):
            errors.append(f"Gate 4: {rel}: metadata.internal must not be true")


# --- Gate 5: Relative Markdown Links & GitHub Heading Anchors ---
OPEN_FENCE_RE = re.compile(r"^[ \t]*(`{3,}|~{3,})(.*)$")
CLOSE_FENCE_RE = re.compile(r"^[ \t]*(`{3,}|~{3,})\s*$")
HEADING_RE = re.compile(r"^\s{0,3}#{1,6}\s+(.*?)(?:\s+#+\s*)?$")
URI_SCHEME_RE = re.compile(r"^[a-zA-Z][a-zA-Z0-9+.-]*:")
ANGLE_AUTOLINK_RE = re.compile(
    r"<((?:[a-zA-Z][a-zA-Z0-9+.-]*://|mailto:|\.\.?/)[^>\s]+|/(?:[^/>\s]+/)+[^>\s]*|(?:[^/>\s]+/)+[^/>\s]+\.(?:md|txt|py|sh|yml|yaml|json|png|jpg|jpeg|svg|html)(?:[?#][^>\s]*)?)>"
)

heading_cache = {}


def strip_fences_preserving_lines(text: str, strip_frontmatter: bool = False):
    lines = text.splitlines()
    start_idx = 0
    out = []
    if strip_frontmatter and lines and lines[0].rstrip("\r") == "---":
        for idx in range(1, len(lines)):
            if lines[idx].rstrip("\r") == "---":
                start_idx = idx + 1
                break
        if start_idx > 0:
            out.extend([""] * start_idx)

    in_fence = False
    fence_char = ""
    fence_len = 0
    for line in lines[start_idx:]:
        if not in_fence:
            m = OPEN_FENCE_RE.match(line)
            if m:
                marker, info = m.group(1), m.group(2)
                if not (marker[0] == "`" and "`" in info):
                    in_fence = True
                    fence_char = marker[0]
                    fence_len = len(marker)
                    out.append("")
                    continue
            out.append(line)
        else:
            m = CLOSE_FENCE_RE.match(line)
            if m and m.group(1)[0] == fence_char and len(m.group(1)) >= fence_len:
                in_fence = False
                fence_char = ""
                fence_len = 0
            out.append("")
    return out


def mask_inline_code(line: str) -> str:
    """Mask CommonMark inline code spans (`...`, ``...``) with spaces, honoring \\-escapes outside spans."""
    chars = list(line)
    n = len(chars)
    i = 0
    while i < n:
        if chars[i] == "\\" and i + 1 < n:
            i += 2
            continue
        if chars[i] != "`":
            i += 1
            continue
        k = 0
        while i + k < n and chars[i + k] == "`":
            k += 1
        j = i + k
        close_idx = -1
        while j < n:
            if chars[j] == "`":
                m = 0
                while j + m < n and chars[j + m] == "`":
                    m += 1
                if m == k:
                    close_idx = j
                    break
                j += m
            else:
                j += 1
        if close_idx != -1:
            for pos in range(i, close_idx + k):
                chars[pos] = " "
            i = close_idx + k
        else:
            i += k
    return "".join(chars)


def _clean_link_target(raw_target: str) -> str:
    target = raw_target.strip()
    if target.startswith("<") and ">" in target:
        end = target.find(">")
        return target[1:end].strip()
    m = re.match(r'^(\S+)\s+(?:"[^"]*"|\'[^\']*\'|\([^)]*\))\s*$', target)
    if m:
        return m.group(1).strip()
    return target.split()[0] if target else ""


def extract_link_targets(line: str):
    """Extract inline, reference-definition, and angle-autolink targets from a non-fenced line."""
    masked = mask_inline_code(line)
    targets = []

    idx = 0
    while idx < len(masked):
        m = re.search(r"!?\[(?:[^\[\]]|\[[^\]]*\])*\]\(", masked[idx:])
        if not m:
            break
        start_paren = idx + m.end()
        depth = 1
        pos = start_paren
        while pos < len(masked) and depth > 0:
            if masked[pos] == "(":
                depth += 1
            elif masked[pos] == ")":
                depth -= 1
            pos += 1
        if depth == 0:
            raw_inner = masked[start_paren : pos - 1]
            cleaned = _clean_link_target(raw_inner)
            if cleaned:
                targets.append(cleaned)
            idx = pos
        else:
            idx = start_paren

    ref_m = re.match(r"^\s{0,3}\[[^\]]+\]:\s*(<[^>]+>|\S+)", masked)
    if ref_m:
        cleaned = _clean_link_target(ref_m.group(1))
        if cleaned:
            targets.append(cleaned)

    for ang_m in ANGLE_AUTOLINK_RE.finditer(masked):
        targets.append(ang_m.group(1))

    return targets


def github_slug(heading_text: str) -> str:
    # Unwrap markdown links [label](url) -> label, strip backticks
    cleaned = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", heading_text)
    cleaned = cleaned.replace("`", "")
    slug = re.sub(r"[^\w -]", "", cleaned.lower()).replace(" ", "-")
    return slug


def get_heading_slugs(md_path: Path):
    if md_path in heading_cache:
        return heading_cache[md_path]
    slugs = set()
    counts = {}
    raw_txt = md_path.read_text(encoding="utf-8")
    has_fm = raw_txt.startswith("---\n") or raw_txt.startswith("---\r\n")
    for line in strip_fences_preserving_lines(raw_txt, strip_frontmatter=has_fm):
        m = HEADING_RE.match(line)
        if not m:
            continue
        base = github_slug(m.group(1).strip())
        if base in counts:
            counts[base] += 1
            slug = f"{base}-{counts[base]}"
        else:
            counts[base] = 0
            slug = base
        slugs.add(slug)
    heading_cache[md_path] = slugs
    return slugs


md_targets = sorted((REPO_ROOT / "skills").rglob("*.md"))
for doc_name in ("README.md", "SKILLS.md", "AGENTS.md", "llms.txt", "CONTRIBUTING.md", "PRIVACY.md", ".github/PULL_REQUEST_TEMPLATE.md"):
    p = REPO_ROOT / doc_name
    if p.is_file():
        md_targets.append(p)
issue_dir = REPO_ROOT / ".github" / "ISSUE_TEMPLATE"
if issue_dir.is_dir():
    md_targets.extend(sorted(issue_dir.glob("*.md")))

for src in md_targets:
    rel_src = src.relative_to(REPO_ROOT)
    raw_src = src.read_text(encoding="utf-8")
    has_fm = raw_src.startswith("---\n") or raw_src.startswith("---\r\n")
    lines = strip_fences_preserving_lines(raw_src, strip_frontmatter=has_fm)
    for lineno, line in enumerate(lines, start=1):
        for raw_target in extract_link_targets(line):
            if URI_SCHEME_RE.match(raw_target):
                continue
            if raw_target.startswith("/"):
                errors.append(f"Gate 5: {rel_src}:{lineno}: root-relative link outside fenced block: {raw_target}")
                continue
            if any(ch in raw_target for ch in ("<", ">", "{", "}")):
                continue

            path_and_query, has_hash, frag = raw_target.partition("#")
            raw_path_part = path_and_query.split("?", 1)[0]
            path_part = urllib.parse.unquote(raw_path_part)
            if path_part == "":
                target_path = src
            else:
                target_path = (src.parent / path_part).resolve()
                try:
                    target_path.relative_to(REPO_ROOT)
                except ValueError:
                    errors.append(f"Gate 5: {rel_src}:{lineno}: link escapes repo root: {raw_target}")
                    continue

            if not target_path.exists():
                errors.append(f"Gate 5: {rel_src}:{lineno}: broken link target: {raw_target}")
                continue
            if not target_path.is_file():
                errors.append(f"Gate 5: {rel_src}:{lineno}: bare directory link (must point to a file): {raw_target}")
                continue

            if has_hash and frag and target_path.suffix == ".md":
                slugs = get_heading_slugs(target_path)
                if urllib.parse.unquote(frag).lower() not in slugs and frag.lower() not in slugs:
                    errors.append(f"Gate 5: {rel_src}:{lineno}: broken anchor '#{frag}' in {target_path.relative_to(REPO_ROOT)}")

if errors:
    print("### FAIL: Gate 4/5 Frontmatter & Link Validation")
    for e in errors:
        print(e)
    sys.exit(1)
PY
then
  failed=1
fi

if [[ "${failed}" -ne 0 ]]; then
  echo "PORTABILITY CHECK FAILED"
  exit 1
fi

echo "PORTABILITY OK"
exit 0
