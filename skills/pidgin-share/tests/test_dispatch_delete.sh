#!/usr/bin/env bash
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
: > "$out"   # empty body
echo "204"
SHIM
chmod +x "$SHIM_DIR/curl"
export PATH="$SHIM_DIR:$PATH"

bash "$SCRIPT" delete "itm_doomed" >/dev/null 2>&1
LOG="$PIDGIN_LOG_DIR/uploads.jsonl"
assert_file_exists "log written after delete" "$LOG"
line=$(tail -n1 "$LOG")
assert_match "delete tombstone present" '"kind":"delete"' "$line"
assert_match "tombstone item_id matches" '"item_id":"itm_doomed"' "$line"

# --version delete must NOT tombstone (item still exists).
rm -f "$LOG"
bash "$SCRIPT" delete "itm_alive" --version 2 >/dev/null 2>&1
if [ -f "$LOG" ] && grep -q '"item_id":"itm_alive"' "$LOG"; then
  echo "  FAIL: version delete should not tombstone item"; FAIL_COUNT=$((FAIL_COUNT+1))
else
  echo "  PASS: version delete leaves item intact in log"; PASS_COUNT=$((PASS_COUNT+1))
fi

report_and_exit
