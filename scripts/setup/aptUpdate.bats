#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

# Path to the script under test
SCRIPT_PATH="$BATS_TEST_DIRNAME/aptUpdate.sh"

@test "sourcing aptUpdate.sh defines functions" {
    run bash -c "source '$SCRIPT_PATH' && declare -f should_run_apt_get_update should_run_apt_get_upgrade run_apt_get_update_and_upgrade"
    [ "$status" -eq 0 ]
    [[ "$output" =~ should_run_apt_get_update ]]
    [[ "$output" =~ should_run_apt_get_upgrade ]]
    [[ "$output" =~ run_apt_get_update_and_upgrade ]]
}

@test "run_apt_get_update_and_upgrade runs both update and upgrade when needed" {
    # Stub decision functions and noop out sudo; we only assert on header output
    run bash -c "source '$SCRIPT_PATH'; should_run_apt_get_update(){ return 0; }; should_run_apt_get_upgrade(){ return 0; }; sudo(){ :; }; run_apt_get_update_and_upgrade"
    [ "$status" -eq 0 ]
    # Expect real logging prefixes: [HEADER]
    [[ "$output" =~ \[HEADER\]\ +Updating\ apt-get\ package\ lists ]]
    [[ "$output" =~ \[HEADER\]\ +Upgrading\ apt-get\ packages ]]
}

@test "run_apt_get_update_and_upgrade skips both update and upgrade when not needed" {
    run bash -c "source '$SCRIPT_PATH'; should_run_apt_get_update(){ return 1; }; should_run_apt_get_upgrade(){ return 1; }; sudo(){ :; }; run_apt_get_update_and_upgrade"
    [ "$status" -eq 0 ]
    [[ "$output" =~ \[INFO\]\ +Skipping\ apt-get\ update ]]
    [[ "$output" =~ \[INFO\]\ +Skipping\ apt-get\ upgrade ]]
}

@test "should_run_apt_get_update returns true when last update older than interval" {
    source "$SCRIPT_PATH"
    # Stub stat to simulate old last update and date to simulate current time
    stat() { echo 0; }
    date() { echo 200000; }
    run should_run_apt_get_update
    [ "$status" -eq 0 ]
}

@test "should_run_apt_get_update returns false when last update within interval" {
    source "$SCRIPT_PATH"
    stat() { echo 200000; }
    date() { echo 200000; }
    run should_run_apt_get_update
    [ "$status" -eq 1 ]
}

@test "should_run_apt_get_upgrade returns true when last upgrade older than interval" {
    source "$SCRIPT_PATH"
    stat() { echo 0; }
    date() { echo 1000000; }
    run should_run_apt_get_upgrade
    [ "$status" -eq 0 ]
}

@test "should_run_apt_get_upgrade returns false when last upgrade within interval" {
    source "$SCRIPT_PATH"
    stat() { echo 1000000; }
    date() { echo 1000000; }
    run should_run_apt_get_upgrade
    [ "$status" -eq 1 ]
} 