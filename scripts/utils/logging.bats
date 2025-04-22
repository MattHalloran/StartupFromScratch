#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
load '../__tests/__testHelper.bash'

SCRIPT_PATH="$BATS_TEST_DIRNAME/../utils/logging.sh"
. "$SCRIPT_PATH"

@test "get_color_code returns correct codes" {
    [ "$(get_color_code RED)" = "1" ]
    [ "$(get_color_code GREEN)" = "2" ]
    [ "$(get_color_code YELLOW)" = "3" ]
    [ "$(get_color_code BLUE)" = "4" ]
    [ "$(get_color_code MAGENTA)" = "5" ]
    [ "$(get_color_code CYAN)" = "6" ]
    [ "$(get_color_code WHITE)" = "7" ]
    [ "$(get_color_code INVALID)" = "0" ]
}
