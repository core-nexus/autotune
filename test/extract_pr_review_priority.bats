#!/usr/bin/env bats
# Integration tests for extract-pr-review-priority.sh.

load helpers

SCRIPT="${SCRIPTS_DIR}/extract-pr-review-priority.sh"

setup() {
  setup_tmp
  export REPO="owner/repo"
  export PR_NUMBER="42"
  export GH_TOKEN="dummy"
  write_gh_stub "${TMP_DIR}/gh-shim.sh"
  install_gh_stub "${TMP_DIR}/gh-shim.sh"
}

teardown() { teardown_tmp; }

@test "single-verdict PR comment writes that priority" {
  export GH_STUB_BODY="MAXIMUM_FIX_PRIORITY:MEDIUM"
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  assert_github_output_lines 1
  [ "$(get_output_value priority)" = "MEDIUM" ]
}

@test "PR comment with multiple verdicts writes exactly one line (issue 88 item 3)" {
  export GH_STUB_BODY=$'MAXIMUM_FIX_PRIORITY:MEDIUM\nlater\nMAXIMUM_FIX_PRIORITY:HIGH\n'
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  assert_github_output_lines 1
  [ "$(get_output_value priority)" = "HIGH" ]
}

@test "gh returns no body -> NONE" {
  export GH_STUB_BODY=""
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  assert_github_output_lines 1
  [ "$(get_output_value priority)" = "NONE" ]
}

@test "gh returns 'null' -> NONE" {
  # `jq ... | last | .body` emits the literal string "null" when the
  # filtered array is empty. The script must treat that as no body.
  export GH_STUB_BODY="null"
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  assert_github_output_lines 1
  [ "$(get_output_value priority)" = "NONE" ]
}

@test "invalid token in PR comment is sanitised to NONE" {
  export GH_STUB_BODY="MAXIMUM_FIX_PRIORITY:BANANA"
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(get_output_value priority)" = "NONE" ]
}

@test "required env vars are enforced" {
  unset PR_NUMBER
  run "${SCRIPT}"
  [ "${status}" -ne 0 ]
}
