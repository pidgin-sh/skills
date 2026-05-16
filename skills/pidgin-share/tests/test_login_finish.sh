#!/usr/bin/env bash
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
setup_test_env

unset PIDGIN_API_KEY
export XDG_STATE_HOME="$TEST_TMP/state"
export XDG_CONFIG_HOME="$TEST_TMP/config"
mkdir -p "$XDG_STATE_HOME/pidgin" "$XDG_CONFIG_HOME/pidgin"

SHIM_DIR="$TEST_TMP/bin"
mkdir -p "$SHIM_DIR"

# Reusable shim: returns successive responses based on a counter file.
# Test orchestrates by setting PIDGIN_TEST_RESPONSES to a path containing a
# series of JSON responses, one per line.
cat > "$SHIM_DIR/curl" <<'SHIM'
#!/usr/bin/env bash
counter_file="$PIDGIN_TEST_COUNTER"
n=$(cat "$counter_file" 2>/dev/null || echo 0)
n=$((n+1))
echo "$n" > "$counter_file"
out=""
prev=""
for arg in "$@"; do
  if [ "$prev" = "-o" ]; then out="$arg"; fi
  prev="$arg"
done
sed -n "${n}p" "$PIDGIN_TEST_RESPONSES" > "$out"
echo "200"
SHIM
chmod +x "$SHIM_DIR/curl"
export PATH="$SHIM_DIR:$PATH"
export PIDGIN_TEST_COUNTER="$TEST_TMP/counter"

# Reusable: write a fresh pending-login state file.
seed_state() {
  local exp=${1:-$(( $(date +%s) + 600 ))}
  cat > "$XDG_STATE_HOME/pidgin/pending-login" <<EOS
device_code=$(printf 'A%.0s' {1..64})
user_code=AAAA-BBBB
interval=0
expires_at=$exp
EOS
  chmod 600 "$XDG_STATE_HOME/pidgin/pending-login"
}

reset_curl() { : > "$PIDGIN_TEST_COUNTER"; }

# ---- Case 1: pending → approved ----
reset_curl
seed_state
export PIDGIN_TEST_RESPONSES="$TEST_TMP/responses1.txt"
cat > "$PIDGIN_TEST_RESPONSES" <<'EOF'
{"status":"pending"}
{"status":"approved","api_key":"pdg_NEWKEY","key_id":"key_X"}
EOF
output=$(bash "$SCRIPT" login --finish)
assert_match "case 1: saved credentials message" 'Saved credentials to' "$output"
assert_file_exists "case 1: credentials file" "$XDG_CONFIG_HOME/pidgin/credentials"
assert_match "case 1: credentials contain api_key" 'pdg_NEWKEY' "$(cat "$XDG_CONFIG_HOME/pidgin/credentials")"
assert_file_mode "case 1: credentials mode 0600" "600" "$XDG_CONFIG_HOME/pidgin/credentials"
assert_file_absent "case 1: pending-login removed after success" "$XDG_STATE_HOME/pidgin/pending-login"

# ---- Case 2: denied → exit 1, pending-login removed ----
rm -f "$XDG_CONFIG_HOME/pidgin/credentials"
reset_curl
seed_state
export PIDGIN_TEST_RESPONSES="$TEST_TMP/responses2.txt"
cat > "$PIDGIN_TEST_RESPONSES" <<'EOF'
{"status":"denied"}
EOF
err_output=$(bash "$SCRIPT" login --finish 2>&1) || rc=$?
assert_eq "case 2: exit 1 on denied" "1" "${rc:-0}"
assert_match "case 2: denied message" "Approval denied" "$err_output"
assert_file_absent "case 2: pending-login removed" "$XDG_STATE_HOME/pidgin/pending-login"

# ---- Case 3: expired → exit 1, pending-login removed ----
reset_curl
seed_state
export PIDGIN_TEST_RESPONSES="$TEST_TMP/responses3.txt"
cat > "$PIDGIN_TEST_RESPONSES" <<'EOF'
{"status":"expired"}
EOF
unset rc
err_output=$(bash "$SCRIPT" login --finish 2>&1) || rc=$?
assert_eq "case 3: exit 1 on server-expired" "1" "${rc:-0}"
assert_match "case 3: expired message" "expired" "$err_output"
assert_file_absent "case 3: pending-login removed" "$XDG_STATE_HOME/pidgin/pending-login"

# ---- Case 4: pending forever within bounded window → exit 75, file retained ----
reset_curl
seed_state
export PIDGIN_TEST_RESPONSES="$TEST_TMP/responses4.txt"
# Many pending lines so the script keeps polling until its window expires.
for i in $(seq 1 20); do echo '{"status":"pending"}'; done > "$PIDGIN_TEST_RESPONSES"
unset rc
PIDGIN_LOGIN_FINISH_TIMEOUT=1 err_output=$(bash "$SCRIPT" login --finish 2>&1) || rc=$?
assert_eq "case 4: exit 75 on still-pending" "75" "${rc:-0}"
assert_match "case 4: still-waiting message" "Run 'pidgin login --finish' again" "$err_output"
assert_file_exists "case 4: pending-login retained" "$XDG_STATE_HOME/pidgin/pending-login"

# ---- Case 5: no pending-login file → exit 2 ----
rm -f "$XDG_STATE_HOME/pidgin/pending-login"
unset rc
err_output=$(bash "$SCRIPT" login --finish 2>&1) || rc=$?
assert_eq "case 5: exit 2 with no pending-login" "2" "${rc:-0}"
assert_match "case 5: helpful message" "No login in progress" "$err_output"

# ---- Case 6: state file's expires_at is in the past → exit 1 ----
reset_curl
seed_state 1   # past
unset rc
err_output=$(bash "$SCRIPT" login --finish 2>&1) || rc=$?
assert_eq "case 6: exit 1 on locally-expired state" "1" "${rc:-0}"
assert_match "case 6: code-expired message" "Code expired" "$err_output"
assert_file_absent "case 6: pending-login removed" "$XDG_STATE_HOME/pidgin/pending-login"

report_and_exit
