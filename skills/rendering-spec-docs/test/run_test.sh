#!/usr/bin/env bash
# Smoke test for the rendering-spec-docs renderer.
#
#   ./run_test.sh
#
# Needs: pandoc. Renders test/fixture.md with render-doc.sh and checks the
# HTML is self-contained and carries the house page shell shared with
# pr-walkthrough (contents box, sidenotes, numbered sections) under the
# rendering-spec-docs label.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$HERE/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

cp "$HERE/fixture.md" "$TMP/fixture.md"
OUT="$TMP/fixture.html"

# --- 1. renders without error, prints the output path -----------------------
MSG=$("$SKILL/render-doc.sh" "$TMP/fixture.md")
[ "$MSG" = "wrote $OUT" ] || fail "unexpected output: $MSG"
[ -s "$OUT" ] || fail "no HTML written"
echo "ok 1 - renders"

# --- 2. self-contained: inline style + script, no external assets -----------
[ "$(grep -c '<style' "$OUT")" -ge 1 ] || fail "no inline <style>"
grep -q '<script>' "$OUT" || fail "no inline <script> (sidenote/contents machinery)"
! grep -qE '<link[^>]+rel="stylesheet"' "$OUT" || fail "external stylesheet link"
! grep -qE '<script[^>]+src=' "$OUT" || fail "external script"
echo "ok 2 - self-contained"

# --- 3. labelled as this renderer, not as a PR walkthrough ------------------
grep -q 'name="generator" content="pandoc [^"]* · rendering-spec-docs"' "$OUT" \
  || fail "generator meta does not name rendering-spec-docs"
grep -q '<span class="kicker">doc</span>' "$OUT" || fail "top bar kicker is not 'doc'"
! grep -q '<span class="kicker">walkthrough</span>' "$OUT" || fail "top bar still says 'walkthrough'"
echo "ok 3 - labelled rendering-spec-docs / doc"

# --- 4. H1 became the page title; sections are numbered ----------------------
grep -q '<title>Design: replace the nightly cron with a Snakemake rule</title>' "$OUT" \
  || fail "H1 not promoted to <title>"
grep -q 'class="header-section-number">1</span> Problem' "$OUT" || fail "sections not numbered"
echo "ok 4 - title + numbered sections"

# --- 5. contents box lists sections and subsections --------------------------
grep -q 'id="TOC"' "$OUT" || fail "no table of contents"
grep -q 'href="#problem"' "$OUT" || fail "TOC missing a section"
grep -q 'href="#what-breaks-today"' "$OUT" || fail "TOC missing a subsection"
echo "ok 5 - contents box"

# --- 6. footnote reaches the sidenote machinery ------------------------------
grep -q 'class="footnote-ref"' "$OUT" || fail "footnote ref missing"
grep -q 'id="sidenotes"' "$OUT" || fail "no sidenotes container"
echo "ok 6 - footnotes"

# --- 7. table, task list, code highlighting ---------------------------------
grep -q '<table>' "$OUT" || fail "table not rendered"
grep -q 'type="checkbox"' "$OUT" || fail "task list not rendered"
grep -q 'class="sourceCode python"' "$OUT" || fail "python code not highlighted"
echo "ok 7 - table, task list, highlighting"

# --- 8. --open is accepted (and stripped) without breaking the render -------
cp "$HERE/fixture.md" "$TMP/openflag.md"
MSG=$(OPEN_CMD=true "$SKILL/render-doc.sh" "$TMP/openflag.md" --open)
[ "$MSG" = "wrote $TMP/openflag.html" ] || fail "--open changed the output message: $MSG"
[ -s "$TMP/openflag.html" ] || fail "--open run wrote no HTML"
echo "ok 8 - --open flag"

echo "all ok"
