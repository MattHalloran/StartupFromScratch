#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

SCRIPT_PATH="$BATS_TEST_DIRNAME/../utils/flow.sh"
. "$SCRIPT_PATH"

@test "flow::confirm accepts 'y' input" {
    # Create a simple shell script that sources flow.sh and runs flow::confirm
    cat > "${BATS_TEST_TMPDIR}/test_script.sh" << 'EOL'
#!/bin/bash
source "$1"
echo "$2" | flow::confirm "Do you want to continue?"
exit $?
EOL
    chmod +x "${BATS_TEST_TMPDIR}/test_script.sh"
    run "${BATS_TEST_TMPDIR}/test_script.sh" "$SCRIPT_PATH" "y"
    [ "$status" -eq 0 ]
}

@test "flow::confirm accepts 'Y' input" {
    # Create a simple shell script that sources flow.sh and runs flow::confirm
    cat > "${BATS_TEST_TMPDIR}/test_script.sh" << 'EOL'
#!/bin/bash
source "$1"
echo "$2" | flow::confirm "Do you want to continue?"
exit $?
EOL
    chmod +x "${BATS_TEST_TMPDIR}/test_script.sh"
    run "${BATS_TEST_TMPDIR}/test_script.sh" "$SCRIPT_PATH" "Y"
    [ "$status" -eq 0 ]
}

@test "flow::confirm rejects 'n' input" {
    # Create a simple shell script that sources flow.sh and runs flow::confirm
    cat > "${BATS_TEST_TMPDIR}/test_script.sh" << 'EOL'
#!/bin/bash
source "$1"
echo "$2" | flow::confirm "Do you want to continue?"
exit $?
EOL
    chmod +x "${BATS_TEST_TMPDIR}/test_script.sh"
    run "${BATS_TEST_TMPDIR}/test_script.sh" "$SCRIPT_PATH" "n"
    [ "$status" -eq 1 ]
}

@test "flow::confirm rejects any other input" {
    # Create a simple shell script that sources flow.sh and runs flow::confirm
    cat > "${BATS_TEST_TMPDIR}/test_script.sh" << 'EOL'
#!/bin/bash
source "$1"
echo "$2" | flow::confirm "Do you want to continue?"
exit $?
EOL
    chmod +x "${BATS_TEST_TMPDIR}/test_script.sh"
    run "${BATS_TEST_TMPDIR}/test_script.sh" "$SCRIPT_PATH" "z"
    [ "$status" -eq 1 ]
}

# Tests for flow::exit_with_error function
@test "flow::exit_with_error exits with provided message and default code" {
    run flow::exit_with_error "Test error message"
    [ "$status" -eq 1 ]
    [ "${lines[0]}" = "[ERROR]   Test error message" ]
}
@test "flow::exit_with_error exits with provided message and custom code" {
    run flow::exit_with_error "Custom error message" 2
    [ "$status" -eq 2 ]
    [ "${lines[0]}" = "[ERROR]   Custom error message" ]
}

@test "flow::is_yes returns 0 for 'y' input" {
    run flow::is_yes "y"
    [ "$status" -eq 0 ]
}
@test "flow::is_yes returns 0 for 'Y' input" {
    run flow::is_yes "Y"
    [ "$status" -eq 0 ]
}
@test "flow::is_yes returns 0 for 'yes' input" {
    run flow::is_yes "yes"
    [ "$status" -eq 0 ]
}
@test "flow::is_yes returns 0 for 'YES' input" {
    run flow::is_yes "YES"
    [ "$status" -eq 0 ]
}
@test "flow::is_yes returns 1 for 'n' input" {
    run flow::is_yes "n"
    [ "$status" -eq 1 ]
}
@test "flow::is_yes returns 1 for 'no' input" {
    run flow::is_yes "no"
    [ "$status" -eq 1 ]
}
@test "flow::is_yes returns 1 for random input" {
    run flow::is_yes "random-string"
    [ "$status" -eq 1 ]
}

# Tests for auto-confirm skipping the prompt
@test "flow::confirm auto-confirms when YES is 'y'" {
    YES=y run flow::confirm "Do you want to continue?"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "[INFO]    Auto-confirm enabled, skipping prompt" ]
}

@test "flow::confirm auto-confirms when YES is 'yes'" {
    YES=yes run flow::confirm "Do you want to continue?"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "[INFO]    Auto-confirm enabled, skipping prompt" ]
}
