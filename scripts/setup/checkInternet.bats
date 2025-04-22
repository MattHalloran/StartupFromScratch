#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

# Path to the script under test
SCRIPT_PATH="$BATS_TEST_DIRNAME/checkInternet.sh"

@test "sourcing checkInternet.sh defines check_internet function" {
    run bash -c "source '$SCRIPT_PATH' && declare -f check_internet"
    [ "$status" -eq 0 ]
    [[ "$output" =~ check_internet ]]
}

@test "check_internet prints success when ping succeeds" {
    run bash -c "source '$SCRIPT_PATH'; ping(){ return 0; }; check_internet"
    [ "$status" -eq 0 ]
    [[ "$output" =~ \[HEADER\]\ +Checking\ host\ internet\ access\.\.\. ]]
    [[ "$output" =~ \[SUCCESS\]\ +Host\ internet\ access:\ OK ]]
}

@test "check_internet prints error and exits with correct code when ping fails" {
    run bash -c "export ERROR_NO_INTERNET=5; source '$SCRIPT_PATH'; ping(){ return 1; }; check_internet"
    [ "$status" -eq 5 ]
    [[ "$output" =~ \[HEADER\]\ +Checking\ host\ internet\ access\.\.\. ]]
    [[ "$output" =~ \[ERROR\]\ +Host\ internet\ access:\ FAILED ]]
}