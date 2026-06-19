#!/usr/bin/env bash
# Smoke test for hathifiles against a local stub of the HathiFiles host.
#
#   ./run_test.sh path/to/hathifiles
#
# Needs: python3, curl. Network-free — the binary is pointed at the stub via
# HATHIFILES_BASE.
set -euo pipefail

BIN="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
HERE="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"
trap 'kill "$STUB_PID" 2>/dev/null || true; rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

PORT=$(( (RANDOM % 10000) + 20000 ))
python3 "$HERE/stub_server.py" "$PORT" &
STUB_PID=$!
for _ in $(seq 50); do
  curl -s -o /dev/null "http://127.0.0.1:$PORT/hathi_file_list.json" && break
  sleep 0.1
done
export HATHIFILES_BASE="http://127.0.0.1:$PORT"

# --- 1. list: newest first, both kinds shown ---------------------------------
OUT=$("$BIN" list)
echo "$OUT" | sed -n '2p' | grep -q "hathi_upd_20260618" || fail "list not newest-first: $OUT"
echo "$OUT" | grep -q "hathi_full_20260601" || fail "list missing full file: $OUT"
echo "ok 1 - list shows files newest-first"

# --- 2. list --json passes the raw array through -----------------------------
"$BIN" list --json | python3 -c 'import json,sys; assert len(json.load(sys.stdin))==4' \
  || fail "list --json not valid/complete"
echo "ok 2 - list --json"

# --- 3. header is 26 tab-separated columns -----------------------------------
N=$("$BIN" header | awk -F'\t' '{print NF}')
[ "$N" -eq 26 ] || fail "expected 26 columns, got $N"
"$BIN" header | grep -q $'^htid\t' || fail "header should start with htid"
[ "$("$BIN" header --describe | wc -l)" -eq 26 ] || fail "--describe should list 26 columns"
echo "ok 3 - header schema (26 columns)"

# --- 4. fetch latest full resolves newest full from the listing --------------
OUT=$("$BIN" fetch -o "$TMP/full.gz" 2>/dev/null)
[ "$OUT" = "$TMP/full.gz" ] || fail "fetch should print dest path, got: $OUT"
grep -q "hathi_full_20260601" "$TMP/full.gz" || fail "fetch did not get newest full"
echo "ok 4 - fetch latest full"

# --- 5. fetch a specific update by date --------------------------------------
"$BIN" fetch --update --date 20260617 -o "$TMP/upd.gz" >/dev/null 2>&1
grep -q "hathi_upd_20260617" "$TMP/upd.gz" || fail "fetch --update --date wrong file"
echo "ok 5 - fetch --update --date"

# --- 6. to-ndjson: named string fields, embedded quote/tab survive -----------
printf 'a.1\tdeny\tic\t000\t\tMIU\t9\t12345\t0814 "x\t\t77\tA "quoted" title\timprint\tbib\tts\t0\t1978\tmiu\teng\tBK\tc\tp\tr\td\tap\tAuthor, A.\n' \
  | "$BIN" to-ndjson > "$TMP/row.ndjson"
python3 - "$TMP/row.ndjson" <<'PY' || fail "to-ndjson produced bad JSON"
import json, sys
o = json.loads(open(sys.argv[1]).read().splitlines()[0])
assert o["htid"] == "a.1", o
assert o["title"] == 'A "quoted" title', o
assert o["isbn"] == '0814 "x', o          # raw quote preserved, not parsed
assert o["author"] == "Author, A.", o
assert isinstance(o["us_gov_doc_flag"], str), "fields must be strings"
PY
echo "ok 6 - to-ndjson emits valid all-string JSON"

# --- 7. argument errors are clean and non-zero -------------------------------
for bad in "" "bogus" "fetch --date 2026" "fetch --full --update"; do
  if OUT=$("$BIN" $bad 2>&1); then fail "expected failure for args '$bad': $OUT"; fi
done
"$BIN" --help >/dev/null || fail "--help should exit 0"
echo "ok 7 - argument validation"

echo "all tests passed"
