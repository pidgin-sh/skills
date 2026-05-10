#!/usr/bin/env bash
set -u
TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"

total_fail=0
for t in "$TESTS_DIR"/test_*.sh; do
  [ -f "$t" ] || continue
  echo "=> $(basename "$t")"
  if bash "$t"; then :; else total_fail=$((total_fail + 1)); fi
done

if [ "$total_fail" -eq 0 ]; then
  echo "All test files passed."; exit 0
else
  echo "$total_fail test file(s) failed."; exit 1
fi
