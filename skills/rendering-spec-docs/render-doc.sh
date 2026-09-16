#!/usr/bin/env bash
# render-doc.sh — render a spec / plan / design / notes markdown to a
# self-contained, house-style HTML file. Works in ANY repo; the only external
# dependency is pandoc. Bundled copy of the house renderer for portability.
#
# Source of truth for the CSS: munis_home/utilities/typesetting/css/review.css
# (this skill bundles a copy as review.css next to the script).
#
# Usage: render-doc.sh path/to/doc.md [--open] [--math]   ->  writes path/to/doc.html
#
# Dollar signs: pandoc's gfm reader enables tex_math_dollars, so a `$` preceded
# by a non-space character closes an inline-math span and "~$28 billion" renders
# as LaTeX markup rather than text. These documents rarely contain math, so the
# extension is OFF by default (a literal `$` is always safe; `\$` still works).
# For a doc that genuinely contains TeX math, pass --math: re-enables the
# extension and emits MathML (--mathml) — native in modern browsers, no CDN, so
# the page stays self-contained.
set -euo pipefail

open_after=0
math=0
args=()
for a in "$@"; do
  case "$a" in
    --open) open_after=1 ;;
    --math) math=1 ;;
    *) args+=("$a") ;;
  esac
done
set -- ${args[@]+"${args[@]}"}

[[ $# -ge 1 ]] || { echo "usage: $0 <markdown-file> [--open] [--math]" >&2; exit 1; }
src="$1"
[[ -f "$src" ]] || { echo "not found: $src" >&2; exit 1; }
out="${src%.md}.html"

command -v pandoc >/dev/null 2>&1 || {
  echo "error: pandoc not found. Install it (macOS: brew install pandoc)." >&2; exit 1; }

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
css="${script_dir}/review.css"
[[ -f "$css" ]] || { echo "bundled stylesheet missing: $css" >&2; exit 1; }

from="gfm-tex_math_dollars"
mathflags=()
if [[ $math -eq 1 ]]; then
  from="gfm"
  mathflags=(--mathml)
fi

pandoc \
  --from "$from" \
  ${mathflags[@]+"${mathflags[@]}"} \
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
