#!/usr/bin/env bash
# Smoke test for the pr-walkthrough renderer.
#
#   ./run_test.sh
#
# Needs: pandoc. Renders test/fixture.md with render-walkthrough.sh and checks
# the HTML is self-contained and carries the layout features the skill
# promises (contents box, sidenotes from footnotes, numbered sections).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$HERE/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

cp "$HERE/fixture.md" "$TMP/fixture.md"
OUT="$TMP/fixture.html"

# --- 1. renders without error, prints the output path -----------------------
MSG=$("$SKILL/render-walkthrough.sh" "$TMP/fixture.md")
[ "$MSG" = "wrote $OUT" ] || fail "unexpected output: $MSG"
[ -s "$OUT" ] || fail "no HTML written"
echo "ok 1 - renders"

# --- 2. self-contained: inline style + script, no external assets -----------
[ "$(grep -c '<style' "$OUT")" -ge 1 ] || fail "no inline <style>"
grep -q '<script>' "$OUT" || fail "no inline <script>"
! grep -qE '<link[^>]+rel="stylesheet"' "$OUT" || fail "external stylesheet link"
! grep -qE '<script[^>]+src=' "$OUT" || fail "external script"
! grep -qE '(href|src)="https?://[^"]*\.(css|js)"' "$OUT" || fail "remote css/js"
echo "ok 2 - self-contained"

# --- 3. H1 became the page title; sections are numbered ----------------------
grep -q '<title>PR #42 — Replace ad-hoc CSV parser with' "$OUT" || fail "H1 not promoted to <title>"
grep -q 'class="header-section-number">1</span> TL;DR' "$OUT" || fail "sections not numbered"
echo "ok 3 - title + numbered sections"

# --- 4. contents box lists sections and subsections --------------------------
grep -q 'id="TOC"' "$OUT" || fail "no table of contents"
grep -q 'href="#tldr--what-to-know-before-approving"' "$OUT" || fail "TOC missing a section"
grep -q 'href="#quoted-commas-are-now-honoured"' "$OUT" || fail "TOC missing a subsection"
echo "ok 4 - contents box"

# --- 5. footnotes survive gfm and reach the sidenote machinery ---------------
[ "$(grep -o 'class="footnote-ref"' "$OUT" | wc -l | tr -d ' ')" -eq 3 ] || fail "expected 3 footnote refs"
grep -q 'id="footnotes"' "$OUT" || fail "no footnotes section"
grep -q 'id="sidenotes"' "$OUT" || fail "no sidenotes container"
echo "ok 5 - footnotes"

# --- 6. task list, table, code highlighting all present ----------------------
grep -q 'type="checkbox"' "$OUT" || fail "task list not rendered"
grep -q '<table>' "$OUT" || fail "table not rendered"
grep -q 'class="sourceCode julia"' "$OUT" || fail "julia code not highlighted"
grep -q 'class="sourceCode diff"' "$OUT" || fail "diff fence not highlighted"
grep -q '<span class="va">+length(row)' "$OUT" || fail "added diff line not tagged"
echo "ok 6 - task list, table, diff + code highlighting"

# --- 7. a doc without an H1 still renders (title falls back to filename) -----
printf '## Only a section\n\nbody\n' > "$TMP/noh1.md"
"$SKILL/render-walkthrough.sh" "$TMP/noh1.md" >/dev/null
grep -q '<title>noh1</title>' "$TMP/noh1.html" || fail "no-H1 doc lost its <title>"
echo "ok 7 - no-H1 fallback"

# --- 8. a "# comment" inside a code fence is not a heading ------------------
printf '## Section\n\n```bash\n# BEFORE\necho hi\n```\n' > "$TMP/fence.md"
"$SKILL/render-walkthrough.sh" "$TMP/fence.md" >/dev/null
grep -q '<title>fence</title>' "$TMP/fence.html" || fail "fenced # comment was taken for a heading"
echo "ok 8 - fenced comment is not a heading"

echo "all ok"
