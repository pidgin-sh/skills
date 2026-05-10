#!/usr/bin/env bash
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
setup_test_env
source "$SCRIPT" --source-only

LOG="$PIDGIN_LOG_DIR/uploads.jsonl"
FIX="$TESTS_DIR/fixtures"
export PWD="/test/cwd"

# 1. Minimal upload (no channel/cohort).
body=$(cat "$FIX/upload_response_minimal.json")
record_upload_success "$body"
line=$(tail -n1 "$LOG")
assert_match "minimal: kind=upload"        '"kind":"upload"' "$line"
assert_match "minimal: item_id"            '"item_id":"itm_abc123"' "$line"
assert_match "minimal: url"                '"url":"https://brad.pidgin.sh/abcd1234/plot.html"' "$line"
assert_match "minimal: filename"           '"filename":"plot.html"' "$line"
assert_match "minimal: cwd"                '"cwd":"/test/cwd"' "$line"
assert_match "minimal: expires_at numeric" '"expires_at":1748000000' "$line"
assert_match "minimal: ts ISO8601"         '"ts":"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z"' "$line"

if printf '%s' "$line" | grep -q '"channel_handle"'; then
  echo "  FAIL: minimal response should not include channel_handle"; FAIL_COUNT=$((FAIL_COUNT+1))
else
  echo "  PASS: minimal response omits channel_handle"; PASS_COUNT=$((PASS_COUNT+1))
fi
if printf '%s' "$line" | grep -q '"cohort_id"'; then
  echo "  FAIL: minimal response should not include cohort_id"; FAIL_COUNT=$((FAIL_COUNT+1))
else
  echo "  PASS: minimal response omits cohort_id"; PASS_COUNT=$((PASS_COUNT+1))
fi

# 2. Channel response.
body=$(cat "$FIX/upload_response_with_channel.json")
record_upload_success "$body"
line=$(tail -n1 "$LOG")
assert_match "channel: channel_handle"  '"channel_handle":"ch_xyz"' "$line"
assert_match "channel: expires_at null" '"expires_at":null' "$line"

# 3. Cohort response.
body=$(cat "$FIX/upload_response_with_cohort.json")
record_upload_success "$body"
line=$(tail -n1 "$LOG")
assert_match "cohort: cohort_id" '"cohort_id":"co_qrs"' "$line"

# 4. cwd JSON-escaping.
export PWD='/Users/bdaily/code/with"quote\bsl'
body=$(cat "$FIX/upload_response_minimal.json")
record_upload_success "$body"
line=$(tail -n1 "$LOG")
assert_match "cwd escaped" '"cwd":"/Users/bdaily/code/with\\"quote\\\\bsl"' "$line"

report_and_exit
