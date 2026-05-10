#!/usr/bin/env bash
# compile_latex.sh — Compile .tex to .pdf with auto-detected engine and bibliography passes.
#
# Usage:
#   compile_latex.sh <input.tex> [OPTIONS]
#
# Options:
#   --engine <name>    pdflatex (default) | xelatex | lualatex. Auto-detected if omitted.
#   --use-latexmk      Delegate to latexmk for dependency-driven multi-pass.
#   --preview          Generate PNG previews of each page (requires poppler-utils).
#   --preview-dir DIR  Output directory for PNGs (default: alongside .tex).
#   --scale N          Max PNG dimension in pixels (default: 1200).
#   --auto-fix         Apply float [htbp] and microtype fixes to a temp copy before compiling.
#   --pdfa             Inject pdfx for PDF/A-2b compliant output.
#   --clean            Remove auxiliary files and exit (no compile).
#   --verbose          Show full LaTeX log.
#   --quiet            Suppress all output except errors and final paths.
#
# This script does NOT install dependencies. It checks for required binaries
# and prints install instructions if anything is missing. See the plugin
# README for one-liner install commands.

set -euo pipefail

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

usage() { sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'; }

INPUT_TEX=""
PREVIEW=false
PREVIEW_DIR=""
SCALE=1200
ENGINE=""
AUTO_FIX=false
USE_LATEXMK=false
VERBOSE=false
QUIET=false
CLEAN_ONLY=false
PDFA=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --preview) PREVIEW=true; shift ;;
    --preview-dir) PREVIEW_DIR="$2"; shift 2 ;;
    --scale) SCALE="$2"; shift 2 ;;
    --engine) ENGINE="$2"; shift 2 ;;
    --auto-fix) AUTO_FIX=true; shift ;;
    --use-latexmk) USE_LATEXMK=true; shift ;;
    --verbose) VERBOSE=true; shift ;;
    --quiet) QUIET=true; shift ;;
    --clean) CLEAN_ONLY=true; shift ;;
    --pdfa) PDFA=true; shift ;;
    -*) echo "Error: Unknown option $1" >&2; exit 1 ;;
    *) INPUT_TEX="$1"; shift ;;
  esac
done

if [[ -z "$INPUT_TEX" ]]; then
  echo "Error: No input .tex file specified" >&2
  usage
  exit 1
fi

if [[ ! -f "$INPUT_TEX" ]]; then
  echo "Error: File not found: $INPUT_TEX" >&2
  exit 1
fi

INPUT_TEX="$(realpath "$INPUT_TEX")"
INPUT_DIR="$(dirname "$INPUT_TEX")"
INPUT_BASE="$(basename "$INPUT_TEX" .tex)"
PDF_FILE="${INPUT_DIR}/${INPUT_BASE}.pdf"

if [[ -z "$PREVIEW_DIR" ]]; then
  PREVIEW_DIR="$INPUT_DIR"
fi

log_info()   { [[ "$QUIET" == true ]] || echo ":: $*" >&2; }
log_detail() { [[ "$VERBOSE" == true ]] && echo "   $*" >&2 || true; }

# ---------------------------------------------------------------------------
# Dependency checks (advise, do not install)
# ---------------------------------------------------------------------------

require_bin() {
  local bin="$1" hint="$2"
  if ! command -v "$bin" &>/dev/null; then
    echo "Error: '$bin' not found." >&2
    echo "  Install: $hint" >&2
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Aux file cleanup (used by --clean and at end of normal compile)
# ---------------------------------------------------------------------------

AUX_EXTS=(
  aux log out toc lof lot nav snm vrb bbl blg
  idx ilg ind bcf run.xml glo gls glg ist acn acr alg
  fls fdb_latexmk synctex.gz xdv pytxcode
)

clean_aux() {
  local dir="$1" base="$2"
  for ext in "${AUX_EXTS[@]}"; do
    rm -f "${dir}/${base}.${ext}" 2>/dev/null || true
  done
}

if [[ "$CLEAN_ONLY" == true ]]; then
  log_info "Cleaning auxiliary files for ${INPUT_BASE}..."
  clean_aux "$INPUT_DIR" "$INPUT_BASE"
  log_info "Done."
  exit 0
fi

# ---------------------------------------------------------------------------
# Engine and tooling auto-detection (filter out commented lines first)
# ---------------------------------------------------------------------------

detect_engine() {
  if [[ -n "$ENGINE" ]]; then echo "$ENGINE"; return; fi
  local body
  body=$(sed 's/%.*//;/^[[:space:]]*$/d' "$INPUT_TEX" 2>/dev/null)
  if echo "$body" | grep -qE '\\usepackage\{fontspec\}|\\usepackage\{xeCJK\}|\\usepackage\{polyglossia\}'; then
    echo "xelatex"
  elif echo "$body" | grep -qE '\\usepackage\{luacode\}|\\usepackage\{luatextra\}|\\directlua'; then
    echo "lualatex"
  else
    echo "pdflatex"
  fi
}

detect_bibliography() {
  local body
  body=$(sed 's/%.*//;/^[[:space:]]*$/d' "$INPUT_TEX" 2>/dev/null)
  if echo "$body" | grep -qE '\\bibliography\{'; then
    echo "bibtex"
  elif echo "$body" | grep -qE '\\addbibresource\{'; then
    echo "biber"
  else
    echo "none"
  fi
}

detect_makeindex() {
  local body
  body=$(sed 's/%.*//;/^[[:space:]]*$/d' "$INPUT_TEX" 2>/dev/null)
  echo "$body" | grep -qE '\\makeindex|\\printindex'
}

detect_glossary() {
  local body
  body=$(sed 's/%.*//;/^[[:space:]]*$/d' "$INPUT_TEX" 2>/dev/null)
  echo "$body" | grep -qE '\\makeglossaries|\\printglossary|\\printglossaries|\\newacronym'
}

# ---------------------------------------------------------------------------
# Log parser — translates common errors into actionable hints
# ---------------------------------------------------------------------------

parse_errors() {
  local log_file="$1"
  [[ -f "$log_file" ]] || return

  echo "" >&2
  echo "=== LaTeX log analysis ===" >&2

  if grep -q "File \`.*\.sty' not found" "$log_file"; then
    grep "File \`.*\.sty' not found" "$log_file" | sed -E 's/.*File `(.*)\.sty.*/Missing package: \1/' | while read -r line; do
      pkg=$(echo "$line" | sed 's/Missing package: //')
      echo "  ! $line" >&2
      echo "    Try: tlmgr install $pkg  (or apt: texlive-latex-extra)" >&2
    done
  fi

  if grep -q "Missing \$ inserted" "$log_file"; then
    echo "  ! Math mode error: math symbol used outside \$...\$ delimiters" >&2
    grep -n "Missing \$ inserted" "$log_file" | head -5 | sed 's/^/    Line /' >&2
  fi

  if grep -q "Undefined control sequence" "$log_file"; then
    echo "  ! Undefined control sequence(s) detected" >&2
    grep -A1 "Undefined control sequence" "$log_file" | grep "^l\.[0-9]" | head -5 | while read -r line; do
      linenum=$(echo "$line" | sed -E 's/^l\.([0-9]+).*/\1/')
      cmd=$(echo "$line" | sed -E 's/.*\\([a-zA-Z]+).*/\\\1/')
      echo "    Line $linenum: unknown command '$cmd'" >&2
    done
    echo "    Fix: check spelling or add the missing \\usepackage" >&2
  fi

  if grep -q "Missing .begin.document." "$log_file"; then
    echo "  ! Missing \\begin{document} after preamble" >&2
  fi

  if grep -q "Too many }'s" "$log_file"; then
    echo "  ! Unbalanced braces detected" >&2
    grep -n "Too many }'s" "$log_file" | head -3 | sed 's/^/    /' >&2
  fi

  if grep -q "LaTeX Error: Environment .* undefined" "$log_file"; then
    grep "LaTeX Error: Environment .* undefined" "$log_file" \
      | sed -E 's/.*Environment (.*) undefined.*/  ! Environment "\1" not defined - load the providing package/' \
      | head -3 >&2
  fi

  local overfull
  overfull=$(grep -c "Overfull \\\\hbox" "$log_file" 2>/dev/null || true)
  overfull=${overfull:-0}
  if [[ "$overfull" -gt 0 ]]; then
    echo "  ! $overfull overfull hbox warning(s) — text overflows margins" >&2
    if [[ "$AUTO_FIX" != true ]]; then
      echo "    Fix: \\usepackage{microtype} (or rerun with --auto-fix)" >&2
    fi
  fi

  if grep -q "Citation .* undefined" "$log_file"; then
    echo "  ! Undefined citation(s):" >&2
    grep "Citation .* undefined" "$log_file" \
      | sed -E "s/.*Citation \`(.*)' .*/    '\1'/" | sort -u | head -5 >&2
    echo "    Fix: check key spelling and ensure bibtex/biber ran" >&2
  fi

  echo "" >&2
}

# ---------------------------------------------------------------------------
# Auto-fix helpers
# ---------------------------------------------------------------------------

auto_fix_floats() {
  local in="$1" out="$2"
  cp "$in" "$out"
  # End-of-line case: \begin{figure}\n
  sed -i.bak -E 's/\\begin\{(figure|table)\}[[:space:]]*$/\\begin{\1}[htbp]/g' "$out"
  rm -f "${out}.bak"
  # Mid-line case: \begin{figure}<non-[ char>
  sed -i.bak -E 's/\\begin\{(figure|table)\}([^[[])/\\begin{\1}[htbp]\2/g' "$out"
  rm -f "${out}.bak"
  local fixed
  fixed=$(grep -o '\\begin{figure}\[htbp\]\|\\begin{table}\[htbp\]' "$out" 2>/dev/null | wc -l)
  [[ $fixed -gt 0 ]] && echo "   Added [htbp] to $fixed naked float(s)" >&2
}

auto_inject_microtype() {
  local in="$1" out="$2"
  if grep -q '\\usepackage.*{microtype}' "$in"; then
    cp "$in" "$out"; return
  fi
  if grep -q '\\usepackage' "$in"; then
    local last; last=$(grep -n '\\usepackage' "$in" | tail -1 | cut -d: -f1)
    awk -v line="$last" 'NR==line {print; print "\\usepackage{microtype} % auto-injected"; next} {print}' "$in" > "$out"
    log_detail "Injected \\usepackage{microtype} after line $last"
  elif grep -q '\\documentclass' "$in"; then
    local doc; doc=$(grep -n '\\documentclass' "$in" | head -1 | cut -d: -f1)
    awk -v line="$doc" 'NR==line {print; print "\\usepackage{microtype} % auto-injected"; next} {print}' "$in" > "$out"
  else
    cp "$in" "$out"
  fi
}

pdfa_inject() {
  local in="$1" out="$2"
  if grep -qE '\\usepackage(\[.*\])?\{pdfx\}|\\usepackage(\[.*\])?\{pdfmanagement-testphase\}' "$in"; then
    cp "$in" "$out"; return
  fi
  if grep -q '\\documentclass' "$in"; then
    local doc; doc=$(grep -n '\\documentclass' "$in" | head -1 | cut -d: -f1)
    awk -v line="$doc" 'NR==line {print; print "\\usepackage[a-2b]{pdfx} % auto-injected for PDF/A"; next} {print}' "$in" > "$out"
    log_info "Injected \\usepackage[a-2b]{pdfx} for PDF/A output"
  else
    cp "$in" "$out"
  fi
}

# ---------------------------------------------------------------------------
# Engine runner — uses texfot for clean output when available
# ---------------------------------------------------------------------------

run_engine() {
  local engine="$1"; shift
  local texfile="$1"; shift
  if [[ "$VERBOSE" == true ]]; then
    "$engine" -interaction=nonstopmode "$@" "$texfile" >&2
  elif [[ "$QUIET" == true ]]; then
    "$engine" -interaction=nonstopmode "$@" "$texfile" >/dev/null 2>&1
  elif command -v texfot &>/dev/null; then
    texfot "$engine" -interaction=nonstopmode "$@" "$texfile" >&2 2>/dev/null
  else
    "$engine" -interaction=nonstopmode "$@" "$texfile" >/dev/null 2>&1
  fi
}

compile_with_latexmk() {
  local engine="$1" texfile="$2"
  local flag
  case "$engine" in
    pdflatex) flag="-pdf" ;;
    xelatex)  flag="-xelatex" ;;
    lualatex) flag="-lualatex" ;;
    *)        flag="-pdf" ;;
  esac
  log_info "Using latexmk (${engine}) for dependency-driven multi-pass..."
  if [[ "$VERBOSE" == true ]]; then
    latexmk "$flag" -interaction=nonstopmode "$texfile" >&2
  elif [[ "$QUIET" == true ]]; then
    latexmk "$flag" -interaction=nonstopmode -quiet "$texfile" >/dev/null 2>&1
  elif command -v texfot &>/dev/null; then
    texfot latexmk "$flag" -interaction=nonstopmode "$texfile" >&2 2>/dev/null
  else
    latexmk "$flag" -interaction=nonstopmode -quiet "$texfile" >/dev/null 2>&1
  fi
}

# ---------------------------------------------------------------------------
# Main compile
# ---------------------------------------------------------------------------

require_bin pdflatex "macOS: brew install --cask mactex   |   Debian: sudo apt-get install texlive-full"

LATEX_ENGINE=$(detect_engine)
log_info "Compiling ${INPUT_TEX} with ${LATEX_ENGINE}..."
cd "$INPUT_DIR"

# If --auto-fix or --pdfa, work on a temp copy
WORKING_TEX="$INPUT_TEX"
TEMP_DIR=""
if [[ "$AUTO_FIX" == true || "$PDFA" == true ]]; then
  TEMP_DIR=$(mktemp -d)
  TEMP_TEX="${TEMP_DIR}/${INPUT_BASE}.tex"
  cp -a "${INPUT_DIR}/"* "$TEMP_DIR/" 2>/dev/null || true
  if [[ "$AUTO_FIX" == true ]]; then
    auto_fix_floats "$INPUT_TEX" "$TEMP_TEX"
  else
    cp "$INPUT_TEX" "$TEMP_TEX"
  fi
  if [[ "$PDFA" == true ]]; then
    PDFA_TMP="${TEMP_DIR}/${INPUT_BASE}_pdfa.tex"
    pdfa_inject "$TEMP_TEX" "$PDFA_TMP"
    mv "$PDFA_TMP" "$TEMP_TEX"
  fi
  WORKING_TEX="$TEMP_TEX"
  cd "$TEMP_DIR"
fi

BIB_ENGINE=$(detect_bibliography)
NEEDS_INDEX=false
NEEDS_GLOSSARY=false
detect_makeindex && NEEDS_INDEX=true
detect_glossary  && NEEDS_GLOSSARY=true

[[ "$LATEX_ENGINE" != "pdflatex" ]] && log_info "Engine: $LATEX_ENGINE"
[[ "$BIB_ENGINE" != "none" ]]      && log_info "Detected bibliography ($BIB_ENGINE)"
[[ "$NEEDS_INDEX" == true ]]       && log_info "Detected index"
[[ "$NEEDS_GLOSSARY" == true ]]    && log_info "Detected glossary"

if [[ -n "$TEMP_DIR" ]]; then
  LOG_FILE="${TEMP_DIR}/${INPUT_BASE}.log"
  ACTUAL_PDF="${TEMP_DIR}/${INPUT_BASE}.pdf"
else
  LOG_FILE="${INPUT_DIR}/${INPUT_BASE}.log"
  ACTUAL_PDF="$PDF_FILE"
fi

if [[ "$USE_LATEXMK" == true ]]; then
  require_bin latexmk "macOS: brew install latexmk   |   Debian: sudo apt-get install latexmk"
  LATEXMK_EXIT=0
  compile_with_latexmk "$LATEX_ENGINE" "$WORKING_TEX" || LATEXMK_EXIT=$?
  if [[ $LATEXMK_EXIT -ne 0 && ! -f "$ACTUAL_PDF" ]]; then
    echo "Error: latexmk produced no PDF" >&2
    parse_errors "$LOG_FILE"
    [[ -n "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
    exit 1
  fi
  [[ $LATEXMK_EXIT -ne 0 ]] && log_info "latexmk had warnings (PDF still produced)"
else
  # Manual multi-pass
  FIRST_PASS_EXIT=0
  run_engine "$LATEX_ENGINE" "$WORKING_TEX" || FIRST_PASS_EXIT=$?
  if [[ $FIRST_PASS_EXIT -ne 0 && ! -f "$ACTUAL_PDF" ]]; then
    echo "Error: compilation failed - no PDF produced" >&2
    parse_errors "$LOG_FILE"
    [[ -n "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
    exit 1
  fi

  # Auto-fix Stage 2: microtype if overfull hbox warnings
  if [[ "$AUTO_FIX" == true && -f "$LOG_FILE" ]]; then
    OVERFULL=$(grep -c "Overfull \\\\hbox" "$LOG_FILE" 2>/dev/null || true)
    OVERFULL=${OVERFULL:-0}
    if [[ "$OVERFULL" -gt 0 ]]; then
      log_info "Detected $OVERFULL overfull hbox warnings — recompiling with microtype"
      MT_TEX="${TEMP_DIR}/${INPUT_BASE}_mt.tex"
      auto_inject_microtype "$WORKING_TEX" "$MT_TEX"
      WORKING_TEX="$MT_TEX"
      run_engine "$LATEX_ENGINE" "$WORKING_TEX" || true
    fi
  fi

  # Bibliography pass
  if [[ "$BIB_ENGINE" == "bibtex" ]]; then
    require_bin bibtex "Included with TeX Live"
    log_info "Running bibtex..."
    bibtex "$INPUT_BASE" >/dev/null 2>&1 || log_info "bibtex had warnings"
  elif [[ "$BIB_ENGINE" == "biber" ]]; then
    require_bin biber "macOS: brew install biber   |   Debian: sudo apt-get install biber"
    log_info "Running biber..."
    biber "$INPUT_BASE" >/dev/null 2>&1 || log_info "biber had warnings"
  fi

  if [[ "$NEEDS_INDEX" == true ]]; then
    log_info "Running makeindex..."
    makeindex "$INPUT_BASE" >/dev/null 2>&1 || log_info "makeindex had warnings"
  fi
  if [[ "$NEEDS_GLOSSARY" == true ]]; then
    log_info "Running makeglossaries..."
    makeglossaries "$INPUT_BASE" >/dev/null 2>&1 || log_info "makeglossaries had warnings"
  fi

  # Second pass (resolves cross-refs)
  run_engine "$LATEX_ENGINE" "$WORKING_TEX" || true

  # Third pass if external indexes/bibs were generated
  if [[ "$BIB_ENGINE" != "none" || "$NEEDS_INDEX" == true || "$NEEDS_GLOSSARY" == true ]]; then
    log_info "Running final pass for cross-references..."
    run_engine "$LATEX_ENGINE" "$WORKING_TEX" || true
  fi
fi

# Materialize PDF in original location if we worked from temp
if [[ -n "$TEMP_DIR" ]]; then
  if [[ ! -f "$ACTUAL_PDF" ]]; then
    echo "Error: PDF not produced" >&2
    parse_errors "$LOG_FILE"
    rm -rf "$TEMP_DIR"
    exit 1
  fi
  cp "$ACTUAL_PDF" "$PDF_FILE"
  log_info "PDF created: ${PDF_FILE}"
  [[ "$AUTO_FIX" == true ]] && log_detail "(compiled from auto-fixed temp copy)"
  [[ "$PDFA" == true ]] && log_detail "(PDF/A-2b compliant)"
else
  if [[ ! -f "$PDF_FILE" ]]; then
    echo "Error: PDF not produced" >&2
    parse_errors "$LOG_FILE"
    exit 1
  fi
  log_info "PDF created: ${PDF_FILE}"
fi

# Surface log warnings even on success
[[ -f "$LOG_FILE" && "$QUIET" != true ]] && parse_errors "$LOG_FILE"

# PNG previews
if [[ "$PREVIEW" == true ]]; then
  require_bin pdftoppm "macOS: brew install poppler   |   Debian: sudo apt-get install poppler-utils"
  mkdir -p "$PREVIEW_DIR"
  PREVIEW_BASE="${PREVIEW_DIR}/${INPUT_BASE}"
  pdftoppm "$PDF_FILE" "$PREVIEW_BASE" -png -scale-to "$SCALE"
  COUNT=$(ls "${PREVIEW_BASE}"*.png 2>/dev/null | wc -l)
  log_info "Generated ${COUNT} PNG preview(s) in ${PREVIEW_DIR}/"
  [[ "$QUIET" != true ]] && ls "${PREVIEW_BASE}"*.png 2>/dev/null
fi

# Cleanup
cd "$INPUT_DIR"
clean_aux "$INPUT_DIR" "$INPUT_BASE"
[[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"

log_info "Done."
