#!/usr/bin/env bats
load helpers/common

setup_env() {
  export REPO=owner/repo
  export PR_NUMBER=42
  export GH_TOKEN=fake-token
}

@test "extracts a single priority token from the comment" {
  setup_env
  export GH_STUB_STDOUT='Review complete.

MAXIMUM_FIX_PRIORITY:HIGH
'
  run bash "${SCRIPTS_DIR}/extract-pr-review-priority.sh"
  [ "$status" -eq 0 ]
  [ "$(output_value priority)" = "HIGH" ]
  [ "$(output_line_count)" -eq 1 ]
}

# Regression for the missing single-match guard: a comment that echoes the
# prompt's token list produces multiple grep hits. Without `| tail -1` the
# step output becomes multi-line and corrupts the fix gate.
@test "collapses multiple matches to the final token (single output line)" {
  setup_env
  export GH_STUB_STDOUT='Use MAXIMUM_FIX_PRIORITY:NONE when clean, else MAXIMUM_FIX_PRIORITY:LOW.
Final verdict:
MAXIMUM_FIX_PRIORITY:MEDIUM
'
  run bash "${SCRIPTS_DIR}/extract-pr-review-priority.sh"
  [ "$status" -eq 0 ]
  [ "$(output_value priority)" = "MEDIUM" ]
  [ "$(output_line_count)" -eq 1 ]
}

@test "defaults to NONE when no token is present" {
  setup_env
  export GH_STUB_STDOUT='No priority marker in this comment body.'
  run bash "${SCRIPTS_DIR}/extract-pr-review-priority.sh"
  [ "$status" -eq 0 ]
  [ "$(output_value priority)" = "NONE" ]
  [ "$(output_line_count)" -eq 1 ]
}
