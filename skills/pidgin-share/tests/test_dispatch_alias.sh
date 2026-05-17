#!/usr/bin/env bash
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
setup_test_env

SHIM_DIR="$TEST_TMP/bin"
mkdir -p "$SHIM_DIR"

# curl shim. Reads desired HTTP code + body from env (SHIM_CODE / SHIM_BODY)
# and logs the first observed -X method, the URL, and the request body to
# $SHIM_LOG, one field per line.
cat > "$SHIM_DIR/curl" <<'SHIM'
#!/usr/bin/env bash
out=""
method="GET"
url=""
body_arg=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o)              out="$2"; shift 2 ;;
    -X)              method="$2"; shift 2 ;;
    --data|-d|--data-binary)
                     body_arg="$2"; shift 2 ;;
    -H|-w|--header)  shift 2 ;;   # flag-with-value we don't care about
    -*)              shift ;;     # boolean flags (-s, -S, -sS, ...)
    *)               url="$1"; shift ;;
  esac
done
: > "$out"
[ -n "${SHIM_BODY:-}" ] && printf '%s' "$SHIM_BODY" > "$out"
{
  printf '%s\n' "$method"
  printf '%s\n' "$url"
  printf '%s\n' "$body_arg"
} >> "${SHIM_LOG:-/dev/null}"
echo "${SHIM_CODE:-200}"
SHIM
chmod +x "$SHIM_DIR/curl"
export PATH="$SHIM_DIR:$PATH"
export SHIM_LOG="$TEST_TMP/curl.log"

# --- 1. alias set: PUT with JSON body ---
: > "$SHIM_LOG"
out=$(SHIM_CODE=200 SHIM_BODY='{"id":"itm_abc","custom_slug":"hello","random_slug":"ab1cd2","url":"https://x.pidgin.sh/hello","random_url":"https://x.pidgin.sh/ab1cd2/page.html"}' bash "$SCRIPT" alias itm_abc hello 2>&1)
rc=$?
assert_eq "alias set exits 0" "0" "$rc"
method=$(sed -n '1p' "$SHIM_LOG")
url=$(sed -n '2p' "$SHIM_LOG")
body=$(sed -n '3p' "$SHIM_LOG")
assert_eq "alias set uses PUT" "PUT" "$method"
assert_match "alias set hits /v1/items/itm_abc/alias" '/v1/items/itm_abc/alias$' "$url"
assert_eq "alias set sends slug body" '{"slug":"hello"}' "$body"
assert_match "alias set prints response body" 'custom_slug' "$out"

# --- 2. alias set error: surface body + non-zero exit ---
: > "$SHIM_LOG"
out=$(SHIM_CODE=403 SHIM_BODY='{"error":"plan_required","message":"Pro plan required"}' bash "$SCRIPT" alias itm_abc hello 2>&1)
rc=$?
assert_eq "alias set 403 exits 1" "1" "$rc"
assert_match "alias set 403 surfaces body" 'plan_required' "$out"
assert_match "alias set 403 logs HTTP code" 'HTTP 403' "$out"

# --- 3. alias read with slug set: GET, print custom_slug ---
: > "$SHIM_LOG"
out=$(SHIM_CODE=200 SHIM_BODY='{"id":"itm_abc","custom_slug":"hello","random_slug":"ab1cd2"}' bash "$SCRIPT" alias itm_abc 2>&1)
rc=$?
assert_eq "alias read exits 0" "0" "$rc"
method=$(sed -n '1p' "$SHIM_LOG")
url=$(sed -n '2p' "$SHIM_LOG")
assert_eq "alias read uses GET" "GET" "$method"
assert_match "alias read hits /v1/items/itm_abc" '/v1/items/itm_abc$' "$url"
assert_eq "alias read prints just the slug" "hello" "$out"

# --- 4. alias read with no slug: print 'no alias set' ---
: > "$SHIM_LOG"
out=$(SHIM_CODE=200 SHIM_BODY='{"id":"itm_abc","custom_slug":null,"random_slug":"ab1cd2"}' bash "$SCRIPT" alias itm_abc 2>&1)
rc=$?
assert_eq "alias read (null) exits 0" "0" "$rc"
assert_eq "alias read (null) prints sentinel" "no alias set" "$out"

# --- 5. alias read 404: surface body + non-zero exit ---
: > "$SHIM_LOG"
out=$(SHIM_CODE=404 SHIM_BODY='{"error":"not_found","message":"Item not found."}' bash "$SCRIPT" alias itm_missing 2>&1)
rc=$?
assert_eq "alias read 404 exits 1" "1" "$rc"
assert_match "alias read 404 surfaces body" 'not_found' "$out"

# --- 6. unalias: DELETE ---
: > "$SHIM_LOG"
out=$(SHIM_CODE=204 SHIM_BODY='' bash "$SCRIPT" unalias itm_abc 2>&1)
rc=$?
assert_eq "unalias exits 0" "0" "$rc"
method=$(sed -n '1p' "$SHIM_LOG")
url=$(sed -n '2p' "$SHIM_LOG")
assert_eq "unalias uses DELETE" "DELETE" "$method"
assert_match "unalias hits /v1/items/itm_abc/alias" '/v1/items/itm_abc/alias$' "$url"

# --- 7. argument validation ---
rc=0; bash "$SCRIPT" alias >/dev/null 2>&1 || rc=$?
assert_eq "alias with no args exits 2" "2" "$rc"
rc=0; bash "$SCRIPT" unalias >/dev/null 2>&1 || rc=$?
assert_eq "unalias with no args exits 2" "2" "$rc"
rc=0; bash "$SCRIPT" alias itm_abc slug extra >/dev/null 2>&1 || rc=$?
assert_eq "alias with extra arg exits 2" "2" "$rc"
rc=0; bash "$SCRIPT" unalias itm_abc extra >/dev/null 2>&1 || rc=$?
assert_eq "unalias with extra arg exits 2" "2" "$rc"

# --- 8. _json_escape: slug with double-quote is escaped safely in PUT body ---
: > "$SHIM_LOG"
SHIM_CODE=200 SHIM_BODY='{"id":"itm_abc","custom_slug":"x"}' bash "$SCRIPT" alias itm_abc 'odd"slug' >/dev/null 2>&1
body=$(sed -n '3p' "$SHIM_LOG")
assert_eq "slug with double-quote is JSON-escaped in body" '{"slug":"odd\"slug"}' "$body"

report_and_exit
