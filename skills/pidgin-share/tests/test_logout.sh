#!/usr/bin/env bash
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
setup_test_env

unset PIDGIN_API_KEY
export XDG_CONFIG_HOME="$TEST_TMP/config"
export XDG_STATE_HOME="$TEST_TMP/state"
mkdir -p "$XDG_CONFIG_HOME/pidgin" "$XDG_STATE_HOME/pidgin"
printf 'PIDGIN_API_KEY=pdg_X\n' > "$XDG_CONFIG_HOME/pidgin/credentials"
printf 'device_code=X\n' > "$XDG_STATE_HOME/pidgin/pending-login"

bash "$SCRIPT" logout >/dev/null

assert_file_absent "credentials file removed" "$XDG_CONFIG_HOME/pidgin/credentials"
assert_file_absent "pending-login removed" "$XDG_STATE_HOME/pidgin/pending-login"

report_and_exit
