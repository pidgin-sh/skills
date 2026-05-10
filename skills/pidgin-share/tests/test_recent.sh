#!/usr/bin/env bash
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
setup_test_env

mkdir -p "$PIDGIN_LOG_DIR"
cp "$TESTS_DIR/fixtures/sample_log.jsonl" "$PIDGIN_LOG_DIR/uploads.jsonl"

# Pin "now" so --since math is deterministic.
# 1778425200 = 2026-05-10T15:00:00Z (matches BSD `date -j -f` parse of the fixture's reference).
export PIDGIN_NOW_EPOCH=1778425200

# 1. Default cwd-filtered, last 1h.
out=$(cd /Users/bdaily/code/pidgin && bash "$SCRIPT" recent)
assert_match "default: shows itm_aaa" "recent.html" "$out"
assert_match "default: shows itm_bbb" "midwindow.html" "$out"
assert_match "default: shows itm_ggg" "withcohort.html" "$out"
for needle in oldwindow othercwd expired tombstoned; do
  if printf '%s' "$out" | grep -q "$needle"; then
    echo "  FAIL: default should not include $needle"; FAIL_COUNT=$((FAIL_COUNT+1))
  else
    echo "  PASS: default excludes $needle"; PASS_COUNT=$((PASS_COUNT+1))
  fi
done

# 2. Newest-first ordering. Fixture timestamps: aaa=14:55, ggg=14:35, bbb=14:30.
order_aaa=$(printf '%s' "$out" | grep -n recent.html | head -n1 | cut -d: -f1)
order_bbb=$(printf '%s' "$out" | grep -n midwindow.html | head -n1 | cut -d: -f1)
order_ggg=$(printf '%s' "$out" | grep -n withcohort.html | head -n1 | cut -d: -f1)
if [ -n "$order_aaa" ] && [ -n "$order_bbb" ] && [ -n "$order_ggg" ] \
   && [ "$order_aaa" -lt "$order_ggg" ] && [ "$order_ggg" -lt "$order_bbb" ]; then
  echo "  PASS: newest-first ordering"; PASS_COUNT=$((PASS_COUNT+1))
else
  echo "  FAIL: ordering aaa($order_aaa)/ggg($order_ggg)/bbb($order_bbb)"; FAIL_COUNT=$((FAIL_COUNT+1))
fi

# 3. --since 24h widens enough to include itm_ccc.
out=$(cd /Users/bdaily/code/pidgin && bash "$SCRIPT" recent --since 24h)
assert_match "--since 24h includes itm_ccc" "oldwindow.html" "$out"

# 4. --all disables cwd filter.
out=$(cd /Users/bdaily/code/pidgin && bash "$SCRIPT" recent --all)
assert_match "--all includes other-cwd entry" "othercwd.html" "$out"

# 5. --json emits valid-shaped array; no tombstones.
out=$(cd /Users/bdaily/code/pidgin && bash "$SCRIPT" recent --json)
first=$(printf '%s' "$out" | head -c 1)
last=$(printf '%s' "$out" | tail -c 1)
assert_eq "--json starts with [" "[" "$first"
assert_eq "--json ends with ]" "]" "$last"
if printf '%s' "$out" | grep -q '"kind":"delete"'; then
  echo "  FAIL: --json should not surface tombstones"; FAIL_COUNT=$((FAIL_COUNT+1))
else
  echo "  PASS: --json omits tombstones"; PASS_COUNT=$((PASS_COUNT+1))
fi

# 6. --since rejects malformed values.
err=$(bash "$SCRIPT" recent --since 5xyz 2>&1 >/dev/null) || true
assert_match "rejects bad --since" "since" "$err"

# 7. Empty/missing log → friendly stderr message, exit 0.
rm -f "$PIDGIN_LOG_DIR/uploads.jsonl"
err=$(cd /Users/bdaily/code/pidgin && bash "$SCRIPT" recent 2>&1 >/dev/null)
rc=$?
assert_eq "exit 0 on empty log" "0" "$rc"
assert_match "friendly message on empty log" "no recent uploads" "$err"

report_and_exit
