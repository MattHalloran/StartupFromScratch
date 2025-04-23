#!/usr/bin/env bash
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${HERE}/../utils/logging.sh"
# shellcheck disable=SC1091
source "${HERE}/../utils/exit_codes.sh"

# Function to match target strings to their canonical form
# Usage: match_target "target_string"
# Returns the canonical target name or exits with ERROR_USAGE if invalid
match_target() {
    # Convert input to lowercase for case-insensitive matching
    local target
    target=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    
    case "$target" in
        l|nl|linux|unix|ubuntu|native-linux)
            echo "native-linux"
            return 0
            ;;
        m|nm|mac|macos|mac-os|native-mac)
            echo "native-mac"
            return 0
            ;;
        w|nw|win|windows|windows-os|native-win)
            echo "native-win"
            return 0
            ;;
        d|dc|docker|docker-only|docker-compose)
            echo "docker-only"
            return 0
            ;;
        k|kc|k8s|cluster|k8s-cluster|kubernetes)
            echo "k8s-cluster"
            return 0
            ;;
        *)
            error "Bad --target" >&2
            return 1
            ;;
    esac
}

# Function to execute a target-specific function based on the target
# Usage: execute_for_target "target_string" "function_prefix"
# Example: execute_for_target "native-linux" "setup_" will call setup_native_linux
execute_for_target() {
    local target="$1"
    local prefix="$2"
    
    # Match the target first
    local matched_target
    matched_target=$(match_target "$target") || return $?
    
    # Convert target to function name by:
    # 1. Replacing hyphens with underscores
    # 2. Adding the prefix
    local function_name="${prefix}${matched_target//-/_}"
    
    # Check if the function exists
    if ! declare -F "$function_name" > /dev/null; then
        error "Function $function_name does not exist"
        return "${ERROR_FUNCTION_NOT_FOUND}"
    fi
    
    # Execute the function
    "$function_name"
} 