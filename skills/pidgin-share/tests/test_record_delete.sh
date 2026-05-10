#!/usr/bin/env bash
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
setup_test_env
source "$SCRIPT" --source-only

LOG="$PIDGIN_LOG_DIR/uploads.jsonl"

record_delete_success "itm_abc123"
line=$(tail -n1 "$LOG")
assert_match "delete: kind"    '"kind":"delete"' "$line"
assert_match "delete: item_id" '"item_id":"itm_abc123"' "$line"
assert_match "delete: ts"      '"ts":"[0-9]{4}-' "$line"

for key in cwd url filename expires_at channel_handle cohort_id; do
  if printf '%s' "$line" | grep -q "\"$key\""; then
    echo "  FAIL: delete record should not contain $key"; FAIL_COUNT=$((FAIL_COUNT+1))
  else
    echo "  PASS: delete record omits $key"; PASS_COUNT=$((PASS_COUNT+1))
  fi
done

# Empty item_id is a no-op; warn and skip.
err=$(record_delete_success "" 2>&1)
line_count=$(wc -l < "$LOG" | tr -d ' ')
assert_eq "no log line on empty item_id" "1" "$line_count"
assert_match "warning printed for empty item_id" "pidgin:" "$err"

report_and_exit
