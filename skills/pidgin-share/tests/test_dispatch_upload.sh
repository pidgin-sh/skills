#!/usr/bin/env bash
# Shim curl, run `pidgin upload`, assert log line lands.
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
setup_test_env

SHIM_DIR="$TEST_TMP/bin"
mkdir -p "$SHIM_DIR"
cat > "$SHIM_DIR/curl" <<'SHIM'
#!/usr/bin/env bash
out=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) out="$2"; shift 2 ;;
    *) shift ;;
  esac
done
cat "$PIDGIN_TEST_FIXTURE" > "$out"
echo "201"
SHIM
chmod +x "$SHIM_DIR/curl"
export PATH="$SHIM_DIR:$PATH"
export PIDGIN_TEST_FIXTURE="$TESTS_DIR/fixtures/upload_response_minimal.json"

echo "<html></html>" > "$TEST_TMP/plot.html"

bash "$SCRIPT" upload "$TEST_TMP/plot.html" >/dev/null
LOG="$PIDGIN_LOG_DIR/uploads.jsonl"
assert_file_exists "log written after upload" "$LOG"
line=$(tail -n1 "$LOG")
assert_match "logged item_id from response" '"item_id":"itm_abc123"' "$line"
assert_match "logged url from response" '"url":"https://brad.pidgin.sh/abcd1234/plot.html"' "$line"

report_and_exit
