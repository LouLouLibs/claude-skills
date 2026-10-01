#!/usr/bin/env bash
# render-doc.sh — render a spec / plan / design / notes markdown to one
# self-contained HTML page in the house style: reading column, sticky
# contents box, footnotes as margin sidenotes, light/dark following the OS.
# Works in ANY repo; the only external dependency is pandoc.
#
# The page shell (walkthrough.css + walkthrough.html) is owned by the sibling
# pr-walkthrough skill; this script is a thin wrapper that relabels the page
# (top-bar kicker "doc", generator "rendering-spec-docs"). install.sh installs
# both skills together.
#
# Usage: render-doc.sh path/to/doc.md [--open] [--math] [--kicker LABEL]
#        ->  writes path/to/doc.html
#   --open    open the result in the browser afterwards ($OPEN_CMD, default `open`)
#   --math    keep TeX math and emit MathML (see below)
#   --kicker  top-bar label (default "doc"; e.g. "pre-review", "plan")
#
# Dollar signs: pandoc's gfm reader enables tex_math_dollars, so a `$` preceded
# by a non-space character closes an inline-math span and "~$28 billion" renders
# as LaTeX markup rather than text. These documents rarely contain math, so the
# extension is OFF by default (a literal `$` is always safe; `\$` still works).
# For a doc that genuinely contains TeX math, pass --math: re-enables the
# extension and emits MathML — native in modern browsers, no CDN, so the page
# stays self-contained. The shared renderer implements the flag.
set -euo pipefail

open_after=0
kicker="doc"
passthrough=()
args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --open) open_after=1 ;;
    --math) passthrough+=(--math) ;;
    --kicker)
      [[ $# -ge 2 ]] || { echo "--kicker needs a value" >&2; exit 1; }
      kicker="$2"; shift ;;
    *) args+=("$1") ;;
  esac
  shift
done
set -- ${args[@]+"${args[@]}"}

[[ $# -ge 1 ]] || { echo "usage: $0 <markdown-file> [--open] [--math] [--kicker LABEL]" >&2; exit 1; }
src="$1"
[[ -f "$src" ]] || { echo "not found: $src" >&2; exit 1; }
out="${src%.md}.html"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
renderer="${script_dir}/../pr-walkthrough/render-walkthrough.sh"
[[ -x "$renderer" ]] || {
  echo "error: shared renderer missing: $renderer" >&2
  echo "rendering-spec-docs needs the pr-walkthrough skill installed beside it" \
       "(run install.sh from the claude-skills repo)." >&2
  exit 1; }

"$renderer" "$src" --kicker "$kicker" --renderer rendering-spec-docs \
  ${passthrough[@]+"${passthrough[@]}"}

[[ $open_after -eq 1 ]] && "${OPEN_CMD:-open}" "$out"
exit 0
