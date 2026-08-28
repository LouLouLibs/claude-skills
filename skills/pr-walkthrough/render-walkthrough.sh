#!/usr/bin/env bash
# render-walkthrough.sh — renderer for the pr-walkthrough skill.
# Markdown -> one self-contained HTML file: stylesheet, contents box and
# sidenote script are all inlined, so the page works from file:// and can be
# committed next to the .md. Works in ANY repo; the only dependency is pandoc.
#
# Usage: render-walkthrough.sh path/to/walkthrough.md   ->  writes walkthrough.html
#
# What pandoc is asked to do (walkthrough.html is the page shell):
#   --shift-heading-level-by=-1  the leading "# PR …" H1 becomes the page
#                                title; "##" sections become numbered h1s
#   --toc --toc-depth=2          sections + subsections feed the contents box
#   --number-sections            headings and the contents box share numbering
#   gfm (+footnotes)             [^n] footnotes are lifted into margin sidenotes
set -euo pipefail

[[ $# -ge 1 ]] || { echo "usage: $0 <markdown-file>" >&2; exit 1; }
src="$1"
[[ -f "$src" ]] || { echo "not found: $src" >&2; exit 1; }
out="${src%.md}.html"

command -v pandoc >/dev/null 2>&1 || {
  echo "error: pandoc not found. Install it (macOS: brew install pandoc)." >&2; exit 1; }

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
css="${script_dir}/walkthrough.css"
template="${script_dir}/walkthrough.html"
for f in "$css" "$template"; do
  [[ -f "$f" ]] || { echo "bundled file missing: $f" >&2; exit 1; }
done

# pandoc 3.7+ renamed --highlight-style to --syntax-highlighting and warns on
# the old spelling; older releases only know the old one.
if pandoc --help 2>/dev/null | grep -q -- '--syntax-highlighting'; then
  highlight=(--syntax-highlighting=pygments)
else
  highlight=(--highlight-style=pygments)
fi

# A doc without a leading H1 has no title; fall back to the filename so
# pandoc doesn't warn and the browser tab isn't blank.
meta=()
grep -qE '^# ' "$src" || meta=(--metadata "pagetitle=$(basename "$src" .md)")

pandoc \
  --from gfm \
  --to html5 \
  --standalone \
  --embed-resources \
  --wrap=none \
  --template "$template" \
  --css "$css" \
  --shift-heading-level-by=-1 \
  --toc --toc-depth=2 \
  --number-sections \
  "${highlight[@]}" \
  ${meta[@]+"${meta[@]}"} \
  -o "$out" \
  "$src"

echo "wrote $out"
