#!/usr/bin/env bash
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
setup_test_env

unset PIDGIN_API_KEY
export XDG_STATE_HOME="$TEST_TMP/state"
export XDG_CONFIG_HOME="$TEST_TMP/config"

# Stub curl to return a canned /v1/cli-auth/start response.
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
cat > "$out" <<'JSON'
{"device_code":"AAAA1111BBBB2222CCCC3333DDDD4444EEEE5555FFFF6666GGGG7777HHHH8888","user_code":"WXYZ-9KQ7","verification_uri":"https://pidgin.sh/cli-auth?code=WXYZ-9KQ7","interval":2,"expires_in":600}
JSON
echo "200"
SHIM
chmod +x "$SHIM_DIR/curl"

# Stub `open` and `xdg-open` as no-ops so we don't actually open a browser.
cat > "$SHIM_DIR/open" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$SHIM_DIR/xdg-open" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$SHIM_DIR/open" "$SHIM_DIR/xdg-open"

export PATH="$SHIM_DIR:$PATH"

output=$(bash "$SCRIPT" login)

assert_match "URL printed" 'https://pidgin\.sh/cli-auth\?code=WXYZ-9KQ7' "$output"
assert_match "user_code printed" 'WXYZ-9KQ7' "$output"
assert_match "next-step message printed" 'pidgin login --finish' "$output"

STATE_FILE="$XDG_STATE_HOME/pidgin/pending-login"
assert_file_exists "pending-login file written" "$STATE_FILE"
assert_match "state has device_code" 'device_code=AAAA1111' "$(cat "$STATE_FILE")"
assert_match "state has user_code" 'user_code=WXYZ-9KQ7' "$(cat "$STATE_FILE")"
assert_match "state has interval" 'interval=2' "$(cat "$STATE_FILE")"
assert_match "state has expires_at" 'expires_at=[0-9]+' "$(cat "$STATE_FILE")"
assert_file_mode "pending-login mode 0600" "600" "$STATE_FILE"

report_and_exit
