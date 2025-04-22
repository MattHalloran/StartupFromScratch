#!/usr/bin/env bash
# exit_codes.sh
# Central definitions of global exit codes for scripts and tests.
# These use default assignments so tests or callers can override them by exporting beforehand.

: "${EXIT_SUCCESS:=0}"       # Success
: "${ERROR_DEFAULT:=1}"      # Default error
: "${ERROR_USAGE:=64}"       # Command line usage error
: "${ERROR_NO_INTERNET:=65}" # No internet access 
: "${ERROR_ENV_FILE_MISSING:=66}" # Environment file missing