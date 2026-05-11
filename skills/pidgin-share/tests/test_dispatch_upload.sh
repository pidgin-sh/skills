#!/usr/bin/env bash
# Shim curl, run `pidgin upload`, assert log line lands and X-Pidgin-Agent/Model
# headers are forwarded.
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
setup_test_env

SHIM_DIR="$TEST_TMP/bin"
mkdir -p "$SHIM_DIR"
cat > "$SHIM_DIR/curl" <<'SHIM'
#!/usr/bin/env bash
out=""
hdrs="$PIDGIN_TEST_HDR_LOG"
while [ $# -gt 0 ]; do
  case "$1" in
    -o) out="$2"; shift 2 ;;
    -H) printf '%s\n' "$2" >> "$hdrs"; shift 2 ;;
    *) shift ;;
  esac
done
cat "$PIDGIN_TEST_FIXTURE" > "$out"
echo "201"
SHIM
chmod +x "$SHIM_DIR/curl"
export PATH="$SHIM_DIR:$PATH"
export PIDGIN_TEST_FIXTURE="$TESTS_DIR/fixtures/upload_response_minimal.json"
export PIDGIN_TEST_HDR_LOG="$TEST_TMP/headers.log"
: > "$PIDGIN_TEST_HDR_LOG"

echo "<html></html>" > "$TEST_TMP/plot.html"

# Case 1: no agent/model flags → no headers sent.
bash "$SCRIPT" upload "$TEST_TMP/plot.html" >/dev/null
LOG="$PIDGIN_LOG_DIR/uploads.jsonl"
assert_file_exists "log written after upload" "$LOG"
line=$(tail -n1 "$LOG")
assert_match "logged item_id from response" '"item_id":"itm_abc123"' "$line"
assert_match "logged url from response" '"url":"https://brad.pidgin.sh/abcd1234/plot.html"' "$line"
if grep -qE '^X-Pidgin-Agent:' "$PIDGIN_TEST_HDR_LOG"; then
  FAIL_COUNT=$((FAIL_COUNT + 1)); echo "  FAIL: no agent header without --agent flag"
else
  PASS_COUNT=$((PASS_COUNT + 1)); echo "  PASS: no agent header without --agent flag"
fi

# Case 2: with --agent and --model, both headers are sent.
: > "$PIDGIN_TEST_HDR_LOG"
bash "$SCRIPT" upload "$TEST_TMP/plot.html" --agent "claude-code" --model "claude-opus-4-7" >/dev/null
assert_match "X-Pidgin-Agent header sent" '^X-Pidgin-Agent: claude-code$' "$(cat "$PIDGIN_TEST_HDR_LOG")"
assert_match "X-Pidgin-Model header sent" '^X-Pidgin-Model: claude-opus-4-7$' "$(cat "$PIDGIN_TEST_HDR_LOG")"

report_and_exit
