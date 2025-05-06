#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

# Path to the script under test
SCRIPT_PATH="$BATS_TEST_DIRNAME/permissions.sh"

@test "sourcing permissions.sh defines set_script_permissions function" {
    run bash -c "source '$SCRIPT_PATH' && declare -f set_script_permissions"
    [ "$status" -eq 0 ]
    [[ "$output" =~ set_script_permissions ]]
}

@test "set_script_permissions prints header and success messages" {
    run bash -c "source '$SCRIPT_PATH'; find(){ return 0; }; set_script_permissions"
    [ "$status" -eq 0 ]
    [[ "$output" =~ \[HEADER\]\ +Setting\ script\ permissions ]]
    [[ "$output" =~ \[SUCCESS\]\ +All\ scripts\ in\ .*are\ now\ executable ]]
} 