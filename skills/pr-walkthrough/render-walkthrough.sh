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

# Dollar signs vs math: see render-doc.sh in rendering-spec-docs — same rule.
# Default keeps `$` literal (walkthroughs quote dollar amounts); --math turns
# the gfm math extension back on and emits self-contained MathML.
math=0
args=()
for a in "$@"; do
  case "$a" in
    --math) math=1 ;;
    *) args+=("$a") ;;
  esac
done
set -- ${args[@]+"${args[@]}"}

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
# pandoc doesn't warn and the browser tab isn't blank. A "# comment" inside a
# code fence is not a heading, so fenced blocks are skipped.
meta=()
awk '/^```/ { fence = !fence; next }  !fence && /^# / { found = 1 }  END { exit !found }' "$src" \
  || meta=(--metadata "pagetitle=$(basename "$src" .md)")

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
