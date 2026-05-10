#!/usr/bin/env bash
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
setup_test_env
source "$SCRIPT" --source-only

LOG_PATH="$PIDGIN_LOG_DIR/uploads.jsonl"

# 1. First call creates parent dir + file with right modes.
append_log '{"ts":"2026-05-10T00:00:00Z","kind":"upload","item_id":"itm_1"}'
assert_file_exists "log file created" "$LOG_PATH"
assert_file_mode "log file mode 0600" "600" "$LOG_PATH"
assert_file_mode "log dir mode 0700" "700" "$PIDGIN_LOG_DIR"

# 2. Line was actually written.
line1=$(head -n1 "$LOG_PATH")
assert_eq "first line content" '{"ts":"2026-05-10T00:00:00Z","kind":"upload","item_id":"itm_1"}' "$line1"

# 3. Second call appends rather than overwrites.
append_log '{"ts":"2026-05-10T00:00:01Z","kind":"delete","item_id":"itm_1"}'
line_count=$(wc -l < "$LOG_PATH" | tr -d ' ')
assert_eq "two lines after second append" "2" "$line_count"

# 4. Failure path: read-only log file → warns to stderr, returns 0.
chmod 444 "$LOG_PATH"
err=$(append_log '{"ts":"x"}' 2>&1 >/dev/null)
rc=$?
chmod 600 "$LOG_PATH"
assert_eq "failure path returns 0" "0" "$rc"
assert_match "failure prints warning" "pidgin: " "$err"

report_and_exit
