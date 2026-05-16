#!/usr/bin/env bash
# Tests credential loading behavior:
#  - file is sourced when PIDGIN_API_KEY is unset
#  - env var wins over file
#  - missing both → exit 2 with the new message
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
setup_test_env

unset PIDGIN_API_KEY
export XDG_CONFIG_HOME="$TEST_TMP/config"
export XDG_STATE_HOME="$TEST_TMP/state"
mkdir -p "$XDG_CONFIG_HOME/pidgin"

# Stub curl to echo the Authorization header for verification.
SHIM_DIR="$TEST_TMP/bin"
mkdir -p "$SHIM_DIR"
cat > "$SHIM_DIR/curl" <<'SHIM'
#!/usr/bin/env bash
out=""
auth=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) out="$2"; shift 2 ;;
    -H)
      case "$2" in
        Authorization:*) auth="$2" ;;
      esac
      shift 2 ;;
    *) shift ;;
  esac
done
printf '{"auth":%s}\n' "$(printf '%s' "$auth" | sed 's/"/\\"/g; s/.*/"&"/')" > "$out"
echo "200"
SHIM
chmod +x "$SHIM_DIR/curl"
export PATH="$SHIM_DIR:$PATH"

# Case 1: credentials file present, env var unset → file is loaded.
printf 'PIDGIN_API_KEY=pdg_FROMFILE\n' > "$XDG_CONFIG_HOME/pidgin/credentials"
chmod 600 "$XDG_CONFIG_HOME/pidgin/credentials"
out=$(bash "$SCRIPT" me)
assert_match "case 1: env unset, file loaded" 'pdg_FROMFILE' "$out"

# Case 2: env var set → env wins.
out=$(PIDGIN_API_KEY=pdg_FROMENV bash "$SCRIPT" me)
assert_match "case 2: env var wins over file" 'pdg_FROMENV' "$out"

# Case 3: neither set, non-login command → exit 2.
rm "$XDG_CONFIG_HOME/pidgin/credentials"
err_out=$(bash "$SCRIPT" me 2>&1) || rc=$?
assert_eq "case 3: exit code 2 when no key" "2" "${rc:-0}"
assert_match "case 3: helpful message" "Run 'pidgin login'" "$err_out"

report_and_exit
