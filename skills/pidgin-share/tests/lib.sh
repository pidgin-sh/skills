#!/usr/bin/env bash
# Shared test helpers. Source from each test_*.sh.

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$TESTS_DIR/.." && pwd)"
SCRIPT="$SKILL_DIR/scripts/pidgin"

setup_test_env() {
  TEST_TMP="$(mktemp -d)"
  export PIDGIN_LOG_DIR="$TEST_TMP/log"
  export PIDGIN_API_KEY="test-key-not-real"
  trap 'rm -rf "$TEST_TMP"' EXIT
}

PASS_COUNT=0
FAIL_COUNT=0

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    PASS_COUNT=$((PASS_COUNT + 1)); echo "  PASS: $name"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1)); echo "  FAIL: $name"
    echo "    expected: $(printf '%q' "$expected")"
    echo "    actual:   $(printf '%q' "$actual")"
  fi
}

assert_match() {
  local name="$1" pattern="$2" actual="$3"
  if printf '%s' "$actual" | grep -qE "$pattern"; then
    PASS_COUNT=$((PASS_COUNT + 1)); echo "  PASS: $name"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1)); echo "  FAIL: $name"
    echo "    pattern: $pattern"
    echo "    actual:  $actual"
  fi
}

assert_file_exists() {
  local name="$1" path="$2"
  if [ -f "$path" ]; then
    PASS_COUNT=$((PASS_COUNT + 1)); echo "  PASS: $name"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1)); echo "  FAIL: $name (file missing: $path)"
  fi
}

assert_file_absent() {
  local name="$1" path="$2"
  if [ ! -e "$path" ]; then
    PASS_COUNT=$((PASS_COUNT + 1)); echo "  PASS: $name"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1)); echo "  FAIL: $name (unexpected file: $path)"
  fi
}

assert_file_mode() {
  local name="$1" expected="$2" path="$3"
  local actual
  if actual=$(stat -f %Lp "$path" 2>/dev/null) || actual=$(stat -c %a "$path" 2>/dev/null); then
    if [ "$expected" = "$actual" ]; then
      PASS_COUNT=$((PASS_COUNT + 1)); echo "  PASS: $name"
    else
      FAIL_COUNT=$((FAIL_COUNT + 1)); echo "  FAIL: $name (expected mode $expected, got $actual)"
    fi
  else
    FAIL_COUNT=$((FAIL_COUNT + 1)); echo "  FAIL: $name (stat failed for $path)"
  fi
}

report_and_exit() {
  echo "  -- $PASS_COUNT passed, $FAIL_COUNT failed --"
  [ "$FAIL_COUNT" -eq 0 ] || exit 1
}
