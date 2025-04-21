#!/usr/bin/env bash

# is_yes: returns 0 (true) if argument is y, yes, true, or 1 (case-insensitive)
is_yes() {
  local val="$1"
  case "${val,,}" in
    y|yes|true|1) return 0;;
    *) return 1;;
  esac
} 