#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

# Ensure the temporary deps dir is cleaned up even if a test crashes
TMP_DEPS_DIR="$BATS_TEST_DIRNAME/deps_dir"
trap 'rm -rf "$TMP_DEPS_DIR"' EXIT

# Path to the script under test
SCRIPT_PATH="$BATS_TEST_DIRNAME/setupBats.sh"

setup() {
    # Prepare a clean temporary dependencies dir for each test
    rm -rf "$TMP_DEPS_DIR"
    mkdir -p "$TMP_DEPS_DIR"
    # Save original CWD and override the deps directory
    export ORIGINAL_DIR="$PWD"
    export BATS_DEPENDENCIES_DIR="$TMP_DEPS_DIR"
}

teardown() {
    # Restore CWD and clean up
    cd "$ORIGINAL_DIR"
    rm -rf "$TMP_DEPS_DIR"
}

@test "sourcing setupBats.sh defines functions" {
    run bash -c "source '$SCRIPT_PATH' && declare -f create_bats_dependencies_dir install_bats_dependency install_bats_core install_bats"
    [ "$status" -eq 0 ]
    [[ "$output" =~ create_bats_dependencies_dir ]]
    [[ "$output" =~ install_bats_dependency ]]
    [[ "$output" =~ install_bats_core ]]
    [[ "$output" =~ install_bats ]]
}

@test "create_bats_dependencies_dir creates directory when missing" {
    source "$SCRIPT_PATH"
    rm -rf "$BATS_DEPENDENCIES_DIR"
    create_bats_dependencies_dir
    [ -d "$BATS_DEPENDENCIES_DIR" ]
}

@test "install_bats_dependency clones absent dependency" {
    source "$SCRIPT_PATH"
    # Stub git clone to just create the target directory
    git() { [[ "$1" == "clone" ]] && mkdir -p "$BATS_DEPENDENCIES_DIR/$3"; }

    run install_bats_dependency "https://example.com/foo.git" "foo"
    [ "$status" -eq 0 ]
    [ -d "$BATS_DEPENDENCIES_DIR/foo" ]
    [[ "$output" =~ installed\ successfully ]]
}

@test "install_bats_dependency skips when already present" {
    source "$SCRIPT_PATH"
    mkdir -p "$BATS_DEPENDENCIES_DIR/bar"

    run install_bats_dependency "any" "bar"
    [ "$status" -eq 0 ]
    [[ "$output" =~ already\ installed ]]
}

@test "install_bats_core clones and installs when missing" {
    source "$SCRIPT_PATH"
    # Stub git clone and sudo install.sh
    git() { [[ "$1" == "clone" ]] && mkdir -p "$BATS_DEPENDENCIES_DIR/bats-core"; }
    sudo() { :; }

    run install_bats_core
    [ "$status" -eq 0 ]
    [ -d "$BATS_DEPENDENCIES_DIR/bats-core" ]
    [[ "$output" =~ installed\ successfully ]]
}

@test "install_bats_core skips when already installed" {
    source "$SCRIPT_PATH"
    mkdir -p "$BATS_DEPENDENCIES_DIR/bats-core"

    run install_bats_core
    [ "$status" -eq 0 ]
    [[ "$output" =~ already\ installed ]]
} 