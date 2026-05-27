#!/usr/bin/env bash
# render-walkthrough.sh — portable renderer for the pr-walkthrough skill.
# Markdown -> self-contained HTML (house CSS inlined). Works in ANY repo;
# the only external dependency is pandoc. Mirrors munis_home's render_spec.sh
# but uses the CSS bundled next to this script.
#
# Usage: render-walkthrough.sh path/to/walkthrough.md   ->  writes walkthrough.html
set -euo pipefail

[[ $# -ge 1 ]] || { echo "usage: $0 <markdown-file>" >&2; exit 1; }
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
  --syntax-highlighting=pygments \
  -o "$out" \
  "$src"

echo "wrote $out"
