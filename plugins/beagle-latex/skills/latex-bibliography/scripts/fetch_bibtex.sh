#!/usr/bin/env bash
# fetch_bibtex.sh — Download BibTeX entries from DOIs or arXiv IDs.
#
# Usage:
#   fetch_bibtex.sh <DOI_or_arXiv_ID> [<DOI_or_arXiv_ID> ...] [OPTIONS]
#
# Options:
#   --output <file>   Output .bib file (default: stdout)
#   --append          Append to existing .bib file instead of overwriting
#   -h, --help        Show this help
#
# Examples:
#   fetch_bibtex.sh 10.1038/nature12373
#   fetch_bibtex.sh 2301.07041 --output references.bib
#   fetch_bibtex.sh 10.1145/3290605.3300608 1906.08237 --append --output refs.bib
#
# DOIs are resolved via doi.org with `Accept: application/x-bibtex`.
# arXiv IDs use arxiv.org/bibtex/<id>. Requires curl.

set -euo pipefail

usage() { sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; }

OUTPUT_FILE=""
APPEND_MODE=false
IDENTIFIERS=()

if [[ $# -eq 0 ]] || [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
  usage; exit 0
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output) OUTPUT_FILE="$2"; shift 2 ;;
    --append) APPEND_MODE=true; shift ;;
    -*) echo "Error: Unknown option: $1" >&2; exit 1 ;;
    *) IDENTIFIERS+=("$1"); shift ;;
  esac
done

if [[ ${#IDENTIFIERS[@]} -eq 0 ]]; then
  echo "Error: No DOI or arXiv ID specified" >&2
  exit 1
fi

if ! command -v curl &>/dev/null; then
  echo "Error: curl not found. Install via your package manager." >&2
  exit 1
fi

detect_type() {
  local id="${1#arXiv:}"
  id="${id#arxiv:}"
  if [[ "$id" =~ ^[0-9]{4}\.[0-9]{4,5}(v[0-9]+)?$ ]]; then
    echo "arxiv"
  elif [[ "$id" =~ ^10\. ]]; then
    echo "doi"
  else
    echo "unknown"
  fi
}

fetch_doi() {
  local doi="$1"
  echo "Fetching DOI: $doi..." >&2
  local bibtex
  bibtex=$(curl -sL -H "Accept: application/x-bibtex" "https://doi.org/$doi" 2>&1) || {
    echo "Error: curl failed for DOI: $doi" >&2; return 1; }
  if [[ -z "$bibtex" ]] || ! echo "$bibtex" | grep -q '@'; then
    echo "Error: invalid BibTeX response for DOI: $doi" >&2
    return 1
  fi
  echo "$bibtex"
}

fetch_arxiv() {
  local id="${1#arXiv:}"
  id="${id#arxiv:}"
  echo "Fetching arXiv: $id..." >&2
  local bibtex
  bibtex=$(curl -sL "https://arxiv.org/bibtex/${id}" 2>&1) || {
    echo "Error: curl failed for arXiv: $id" >&2; return 1; }
  if [[ -z "$bibtex" ]] || ! echo "$bibtex" | grep -q '@'; then
    echo "Error: invalid BibTeX response for arXiv: $id" >&2
    return 1
  fi
  echo "$bibtex"
}

ALL_BIBTEX=""
SUCCESS=0
FAILED=0

for id in "${IDENTIFIERS[@]}"; do
  case "$(detect_type "$id")" in
    doi)
      if entry=$(fetch_doi "$id"); then
        ALL_BIBTEX="${ALL_BIBTEX}${entry}"$'\n\n'
        SUCCESS=$((SUCCESS+1))
      else
        FAILED=$((FAILED+1))
      fi
      ;;
    arxiv)
      if entry=$(fetch_arxiv "$id"); then
        ALL_BIBTEX="${ALL_BIBTEX}${entry}"$'\n\n'
        SUCCESS=$((SUCCESS+1))
      else
        FAILED=$((FAILED+1))
      fi
      ;;
    *)
      echo "Error: unrecognized identifier '$id' (expected DOI '10.xxxx/...' or arXiv 'YYMM.NNNNN')" >&2
      FAILED=$((FAILED+1))
      ;;
  esac
done

if [[ $SUCCESS -eq 0 ]]; then
  echo "Error: no BibTeX entries fetched" >&2
  exit 1
fi

if [[ -z "$OUTPUT_FILE" ]]; then
  printf '%s' "$ALL_BIBTEX"
else
  if [[ "$APPEND_MODE" == true && -f "$OUTPUT_FILE" ]]; then
    printf '\n%s' "$ALL_BIBTEX" >> "$OUTPUT_FILE"
    echo "Appended $SUCCESS BibTeX entry(ies) to: $OUTPUT_FILE" >&2
  else
    printf '%s' "$ALL_BIBTEX" > "$OUTPUT_FILE"
    echo "Wrote $SUCCESS BibTeX entry(ies) to: $OUTPUT_FILE" >&2
  fi
fi

[[ $FAILED -gt 0 ]] && { echo "Failed: $FAILED entry(ies)" >&2; exit 1; }
exit 0
