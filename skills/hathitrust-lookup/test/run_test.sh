#!/usr/bin/env bash
# Smoke test for ht-lookup against a local stub of the HathiTrust bib API.
#
#   ./run_test.sh path/to/ht-lookup
#
# Needs: python3, curl. Network-free — the binary is pointed at the stub via
# HT_API_BASE.
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
  curl -s -o /dev/null "http://127.0.0.1:$PORT/brief/json/oclc:1" && break
  sleep 0.1
done
export HT_API_BASE="http://127.0.0.1:$PORT"

# --- 1. single lookup renders title, htid, and access status ------------------
OUT=$("$BIN" oclc 12345)
echo "$OUT" | grep -q "Stub Title (1999)" || fail "missing title: $OUT"
echo "$OUT" | grep -q "stub.0001" || fail "missing htid: $OUT"
echo "$OUT" | grep -q "\[Full view\]" || fail "missing access status: $OUT"
echo "$OUT" | grep -q "\[v.2 1999\]" || fail "missing enumcron: $OUT"
echo "ok 1 - single lookup renders record and items"

# --- 2. batch lookup returns one block per identifier -------------------------
OUT=$("$BIN" oclc 12345 isbn 9780000000001)
[ "$(echo "$OUT" | grep -c "Stub Title")" -eq 2 ] || fail "batch did not return 2 records: $OUT"
echo "ok 2 - batch lookup returns a block per id"

# --- 3. not-found reports cleanly, exit 0 -------------------------------------
OUT=$("$BIN" oclc 404)
echo "$OUT" | grep -q "no record found" || fail "expected not-found message: $OUT"
echo "ok 3 - not-found handled"

# --- 4. --full surfaces the MARC note; --json --full carries marc-xml ---------
"$BIN" --full oclc 12345 | grep -q "marc-xml: present" || fail "no marc note in --full"
"$BIN" --json --full oclc 12345 | grep -q '"marc-xml"' || fail "no marc-xml in --json --full"
echo "ok 4 - --full / --json modes"

# --- 5. --json emits valid JSON keyed by query -------------------------------
"$BIN" --json oclc 12345 | python3 -c 'import json,sys; assert "oclc:12345" in json.load(sys.stdin)' \
  || fail "--json output not valid/keyed"
echo "ok 5 - --json is valid and keyed by query"

# --- 6. argument errors are clean and non-zero --------------------------------
for bad in "" "bogus 1" "oclc"; do
  if OUT=$("$BIN" $bad 2>&1); then fail "expected failure for args '$bad': $OUT"; fi
done
"$BIN" --help >/dev/null || fail "--help should exit 0"
echo "ok 6 - argument validation"

# --- 7. too many identifiers is rejected --------------------------------------
ARGS=""; for i in $(seq 21); do ARGS="$ARGS oclc $i"; done
if OUT=$("$BIN" $ARGS 2>&1); then fail "expected failure for >20 ids"; fi
echo "$OUT" | grep -q "at most 20" || fail "unhelpful over-limit error: $OUT"
echo "ok 7 - over-limit rejected"

echo "all tests passed"
