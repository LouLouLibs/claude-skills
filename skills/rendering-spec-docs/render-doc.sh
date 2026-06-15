#!/usr/bin/env bash
# render-doc.sh — render a spec / plan / design / notes markdown to a
# self-contained, house-style HTML file. Works in ANY repo; the only external
# dependency is pandoc. Bundled copy of the house renderer for portability.
#
# Source of truth for the CSS: munis_home/utilities/typesetting/css/review.css
# (this skill bundles a copy as review.css next to the script).
#
# Usage: render-doc.sh path/to/doc.md [--open]   ->  writes path/to/doc.html
set -euo pipefail

open_after=0
args=()
for a in "$@"; do
  case "$a" in
    --open) open_after=1 ;;
    *) args+=("$a") ;;
  esac
done
set -- "${args[@]}"

[[ $# -ge 1 ]] || { echo "usage: $0 <markdown-file> [--open]" >&2; exit 1; }
src="$1"
[[ -f "$src" ]] || { echo "not found: $src" >&2; exit 1; }
out="${src%.md}.html"

command -v pandoc >/dev/null 2>&1 || {
  echo "error: pandoc not found. Install it (macOS: brew install pandoc)." >&2; exit 1; }

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
css="${script_dir}/review.css"
[[ -f "$css" ]] || { echo "bundled stylesheet missing: $css" >&2; exit 1; }

pandoc \
  --from gfm \
  --to html5 \
  --standalone \
  --embed-resources \
  --metadata "title=$(basename "$src" .md)" \
  --css "$css" \
  --highlight-style=pygments \
  -o "$out" \
  "$src"

echo "wrote $out"
[[ $open_after -eq 1 ]] && command -v open >/dev/null 2>&1 && open "$out"
exit 0
