#!/usr/bin/env bash
# Verify --agent / --model client-side validation before any API call.
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
setup_test_env

SHIM_DIR="$TEST_TMP/bin"
mkdir -p "$SHIM_DIR"
# Curl shim that always fails — if the wrapper makes an HTTP call, that's a bug.
cat > "$SHIM_DIR/curl" <<'SHIM'
#!/usr/bin/env bash
echo "curl: should not be called for invalid metadata" >&2
exit 99
SHIM
chmod +x "$SHIM_DIR/curl"
export PATH="$SHIM_DIR:$PATH"

echo "<html></html>" > "$TEST_TMP/p.html"

# Bad agent (whitespace) — should fail before calling curl.
out=$(bash "$SCRIPT" upload "$TEST_TMP/p.html" --agent "claude code" --model "claude-opus-4-7" 2>&1)
rc=$?
assert_eq "rejects bad agent with non-zero exit" "2" "$rc"
assert_match "rejects bad agent with clear message" "invalid --agent value" "$out"

# Bad model (special chars) — should fail before calling curl.
out=$(bash "$SCRIPT" upload "$TEST_TMP/p.html" --agent "claude-code" --model "model;rm" 2>&1)
rc=$?
assert_eq "rejects bad model with non-zero exit" "2" "$rc"
assert_match "rejects bad model with clear message" "invalid --model value" "$out"

# Over-length — should fail before calling curl.
LONG=$(printf 'a%.0s' {1..65})
out=$(bash "$SCRIPT" upload "$TEST_TMP/p.html" --agent "$LONG" 2>&1)
rc=$?
assert_eq "rejects over-length agent with non-zero exit" "2" "$rc"
assert_match "rejects over-length agent with clear message" "invalid --agent value" "$out"

report_and_exit
