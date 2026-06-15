#!/usr/bin/env bash
# Smoke test for mint-gh-token against a local stub of the GitHub API.
#
#   ./run_test.sh path/to/mint-gh-token
#
# Needs: python3, openssl, curl.
set -euo pipefail

BIN="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
HERE="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"
trap 'kill "$STUB_PID" 2>/dev/null || true; rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

# --- setup: throwaway RSA key + stub API server ------------------------------
openssl genrsa -out "$TMP/key.pem" 2048 2>/dev/null
openssl rsa -in "$TMP/key.pem" -pubout -out "$TMP/pub.pem" 2>/dev/null

PORT=$(( (RANDOM % 10000) + 20000 ))
python3 "$HERE/stub_server.py" "$PORT" "$TMP" &
STUB_PID=$!
for _ in $(seq 50); do
  curl -s -o /dev/null "http://127.0.0.1:$PORT/" && break
  sleep 0.1
done

export GH_APP_KEY_FILE="$TMP/key.pem"
export GH_APP_ID="12345"
export GH_APP_OWNER="test-owner"
export GH_APP_REPO="test-repo"
export GH_API_URL="http://127.0.0.1:$PORT"
export GH_TOKEN_CACHE="$TMP/cache.json"

# --- 1. mint a fresh token ----------------------------------------------------
TOK=$("$BIN")
[ "$TOK" = "ghs_stubtoken1234567890" ] || fail "expected stub token, got: $TOK"
echo "ok 1 - mints token"

# --- 2. the app JWT signature verifies against the public key -----------------
JWT=$(cat "$TMP/jwt.txt")
SIGNING_INPUT="${JWT%.*}"
SIG_B64URL="${JWT##*.}"
printf '%s' "$SIGNING_INPUT" > "$TMP/signing_input.txt"
# base64url -> base64: swap alphabet, restore padding
printf '%s' "$SIG_B64URL" | tr '_-' '/+' | awk '{ n=length($0)%4; if(n) $0=$0 substr("==",1,4-n); print }' \
  | openssl base64 -d -A > "$TMP/sig.bin"
openssl dgst -sha256 -verify "$TMP/pub.pem" -signature "$TMP/sig.bin" "$TMP/signing_input.txt" >/dev/null \
  || fail "RS256 signature does not verify"
CLAIMS=$(printf '%s' "$SIGNING_INPUT" | cut -d. -f2 | tr '_-' '/+' | awk '{ n=length($0)%4; if(n) $0=$0 substr("==",1,4-n); print }' | openssl base64 -d -A)
echo "$CLAIMS" | grep -q '"iss":"12345"' || fail "JWT claims missing iss: $CLAIMS"
echo "ok 2 - app JWT is valid RS256 with expected claims"

# --- 3. second call reuses the cache ------------------------------------------
ERR=$("$BIN" 2>&1 >/dev/null)
echo "$ERR" | grep -q "cached token reused" || fail "expected cache reuse, got: $ERR"
echo "ok 3 - cache reused"

# --- 4. --no-cache forces a fresh mint -----------------------------------------
ERR=$("$BIN" --no-cache 2>&1 >/dev/null)
echo "$ERR" | grep -q "new token" || fail "expected fresh mint with --no-cache, got: $ERR"
echo "ok 4 - --no-cache mints fresh"

# --- 5. unwritable cache path must not lose the token (vm RO-/tmp regression) --
TOK=$(GH_TOKEN_CACHE="/nonexistent-dir/cache.json" "$BIN" 2>"$TMP/stderr.log")
[ "$TOK" = "ghs_stubtoken1234567890" ] || fail "token lost when cache unwritable"
grep -q "cache write" "$TMP/stderr.log" || fail "expected cache-write warning"
echo "ok 5 - token survives unwritable cache"

# --- 6. missing env produces a clean error -------------------------------------
if OUT=$(env -u GH_APP_KEY_FILE GH_TOKEN_CACHE=/nonexistent "$BIN" 2>&1); then
  fail "expected failure without key, got success: $OUT"
fi
echo "$OUT" | grep -q "GH_APP_KEY" || fail "unhelpful error: $OUT"
echo "ok 6 - clean error when key missing"

# --- 7. a poisoned cache silently re-mints, never crashes (issue #1) -----------
# Each variant is a cache file the reader must treat as "no cache, re-mint":
#   int-typed   - the legacy Python minter wrote token/expires_at as ints
#   missing     - a field absent entirely
#   garbage     - not even JSON
for variant in \
  'int-typed:{"token": 12345, "expires_at": 1800000000}' \
  'missing-field:{"token": "x"}' \
  'garbage:not json at all'; do
  name="${variant%%:*}"
  body="${variant#*:}"
  printf '%s' "$body" > "$GH_TOKEN_CACHE"
  if ! TOK=$("$BIN" 2>"$TMP/stderr.log"); then
    fail "poisoned cache ($name) crashed instead of re-minting: $(cat "$TMP/stderr.log")"
  fi
  [ "$TOK" = "ghs_stubtoken1234567890" ] || fail "poisoned cache ($name) did not re-mint, got: $TOK"
done
echo "ok 7 - poisoned cache (int/missing/garbage) re-mints, no crash"

echo "all tests passed"
