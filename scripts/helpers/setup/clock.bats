#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

# Path to the script under test
SCRIPT_PATH="$BATS_TEST_DIRNAME/time.sh"

@test "sourcing time.sh defines clock::fix_system_clock function" {
    run bash -c "source '$SCRIPT_PATH' && declare -f clock::fix_system_clock"
    [ "$status" -eq 0 ]
    [[ "$output" =~ clock::fix_system_clock ]]
}

@test "clock::fix_system_clock prints header and info with stubbed date" {
    # Stub sudo to noop and date to return a fixed timestamp
    run bash -c "source '$SCRIPT_PATH'; sudo(){ :; }; date(){ echo 'TEST_DATE'; }; clock::fix_system_clock"
    [ "$status" -eq 0 ]
    [[ "$output" =~ \[HEADER\]\ +Making\ sure\ the\ system\ clock\ is\ accurate ]]
    [[ "$output" =~ \[INFO\]\ +System\ clock\ is\ now:\ TEST_DATE ]]
} 