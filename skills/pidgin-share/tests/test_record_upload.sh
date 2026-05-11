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
assert_match "cohort: item_id is top-level itm_, not co_" '"item_id":"itm_ghi789"' "$line"
assert_match "cohort: url is top-level, not recipient" '"url":"https://brad.pidgin.sh/ijkl9012/poll.html"' "$line"

# 4. cwd JSON-escaping.
export PWD='/Users/bdaily/code/with"quote\bsl'
body=$(cat "$FIX/upload_response_minimal.json")
record_upload_success "$body"
line=$(tail -n1 "$LOG")
assert_match "cwd escaped" '"cwd":"/Users/bdaily/code/with\\"quote\\\\bsl"' "$line"

# Test: agent/model in upload log line when wrapper invocation supplied them.
# record_upload_success only knows what the response body returned. The wrapper
# also needs to fold the user-supplied --agent/--model into the log when the
# response doesn't echo them. We record from local-supplied vars by setting
# PIDGIN_LAST_AGENT/PIDGIN_LAST_MODEL before calling.
PIDGIN_LAST_AGENT="claude-code" PIDGIN_LAST_MODEL="claude-opus-4-7" \
  record_upload_success '{"id":"itm_meta1","url":"https://x.pidgin.sh/abcd1234/p.html","current_filename":"p.html","expires_at":1234567890}'
LOG="$PIDGIN_LOG_DIR/uploads.jsonl"
last=$(tail -n1 "$LOG")
assert_match "log line includes agent" '"agent":"claude-code"' "$last"
assert_match "log line includes model" '"model":"claude-opus-4-7"' "$last"

# When neither var is set, agent/model fields are omitted (not null).
unset PIDGIN_LAST_AGENT PIDGIN_LAST_MODEL
record_upload_success '{"id":"itm_meta2","url":"https://x.pidgin.sh/efgh5678/q.html","current_filename":"q.html","expires_at":null}'
last=$(tail -n1 "$LOG")
if printf '%s' "$last" | grep -qE '"agent":'; then
  FAIL_COUNT=$((FAIL_COUNT + 1)); echo "  FAIL: agent field present when not supplied"
else
  PASS_COUNT=$((PASS_COUNT + 1)); echo "  PASS: agent field absent when not supplied"
fi
if printf '%s' "$last" | grep -qE '"model":'; then
  FAIL_COUNT=$((FAIL_COUNT + 1)); echo "  FAIL: model field present when not supplied"
else
  PASS_COUNT=$((PASS_COUNT + 1)); echo "  PASS: model field absent when not supplied"
fi

report_and_exit
