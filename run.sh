#!/usr/bin/env bash
set -euo pipefail

OUT_HTML="lang_bars.html"
CSS_FILE="lang_bars.css"
AWK_SCRIPT="build_lang_bars.awk"
EXC_DIRS="venv,target,imputatio,producit,build"

# Where to run cloc (default: current directory)
TARGET="${1:-.}"

# Ensure cloc exists
command -v cloc >/dev/null 2>&1 || {
  echo "error: cloc not found in PATH" >&2
  exit 1
}

# Ensure awk script exists
[[ -f "$AWK_SCRIPT" ]] || {
  echo "error: missing $AWK_SCRIPT" >&2
  exit 1
}

# Generate HTML table
cloc "$TARGET" --csv --quiet --exclude-dir="$EXC_DIRS" \
  | awk -F',' -v CSS_HREF="$CSS_FILE" -f "$AWK_SCRIPT" \
  > "$OUT_HTML"

echo "Wrote: $OUT_HTML"
echo "Open:  xdg-open test_wrapper.html"

mkdir -p assets

cloc "$TARGET" --csv --quiet --exclude-dir="$EXC_DIRS" \
  | gawk -F',' -f build_lang_bars_svg.awk \
  > assets/lang_bars.svg
