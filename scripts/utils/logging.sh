#!/bin/bash
set -euo pipefail

# Set default terminal type if not set
export TERM=${TERM:-xterm}

# Helper function to get color code
get_color_code() {
    local color=$1
    case $color in
    RED) echo "1" ;;
    GREEN) echo "2" ;;
    YELLOW) echo "3" ;;
    BLUE) echo "4" ;;
    MAGENTA) echo "5" ;;
    CYAN) echo "6" ;;
    WHITE) echo "7" ;;
    *) echo "0" ;;
    esac
}

# Initialize a single color
initialize_color() {
    local color_name="$1"
    local color_code
    color_code=$(get_color_code "$color_name")

    if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
        eval "$color_name=$(tput setaf "$color_code")"
    else
        eval "$color_name=''"
    fi
}

# Initialize color reset
initialize_reset() {
    if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
        RESET=$(tput sgr0)
    else
        RESET=''
    fi
}

# Echo colored text
echo_color() {
    local color="$1"
    local message="$2"
    local color_value

    initialize_color "$color"
    initialize_reset

    eval "color_value=\$$color"

    printf '%s%s%s\n' "$color_value" "$message" "$RESET"
}

# Print header message
header() {
    echo_color MAGENTA "[HEADER]  $*"
}

# Print info message
info() {
    echo_color CYAN "[INFO]    $*"
}

# Print success message
success() {
    echo_color GREEN "[SUCCESS] $*"
}

# Print error message
error() {
    echo_color RED "[ERROR]   $*"
}

# Print warning message
warning() {
    echo_color YELLOW "[WARNING] $*"
}

# Print input prompt message
prompt() {
    echo_color BLUE "[PROMPT]  $*"
}
