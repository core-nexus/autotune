#!/usr/bin/env bats
# Integration tests for extract-review-priority.sh.

load helpers

SCRIPT="${SCRIPTS_DIR}/extract-review-priority.sh"

setup() {
  setup_tmp
  export REVIEW_AREA="security"
  export REPO="owner/repo"
  export GH_TOKEN="dummy"
}

teardown() { teardown_tmp; }

# Build an execution-file fixture by joining its arguments with \n.
make_exec_file() {
  local path="${TMP_DIR}/exec"
  : > "${path}"
  while (( $# )); do
    printf '%s\n' "$1" >> "${path}"
    shift
  done
  printf '%s' "${path}"
}

@test "execution file with verdict before example block returns the verdict (issue 88 item 3)" {
  export EXECUTION_FILE
  EXECUTION_FILE=$(make_exec_file \
    "preamble" \
    "MAXIMUM_FIX_PRIORITY:NONE" \
    "" \
    "(prompt menu follows)" \
    "MAXIMUM_FIX_PRIORITY:NONE" \
    "MAXIMUM_FIX_PRIORITY:XLOW" \
    "MAXIMUM_FIX_PRIORITY:LOW" \
    "MAXIMUM_FIX_PRIORITY:MEDIUM" \
    "MAXIMUM_FIX_PRIORITY:HIGH")
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  assert_github_output_lines 1
  [ "$(get_output_value priority)" = "NONE" ]
}

@test "execution file with a single verdict writes that value" {
  export EXECUTION_FILE
  EXECUTION_FILE=$(make_exec_file "MAXIMUM_FIX_PRIORITY:MEDIUM")
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  assert_github_output_lines 1
  [ "$(get_output_value priority)" = "MEDIUM" ]
}

@test "execution file with multiple separated verdicts writes exactly one priority= line (issue 88 item 3)" {
  # Reproduces the malformed multi-line GITHUB_OUTPUT bug.
  export EXECUTION_FILE
  EXECUTION_FILE=$(make_exec_file \
    "MAXIMUM_FIX_PRIORITY:MEDIUM" \
    "later" \
    "MAXIMUM_FIX_PRIORITY:HIGH")
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  assert_github_output_lines 1
  [ "$(get_output_value priority)" = "HIGH" ]
}

@test "no execution file falls back to gh issue body" {
  unset EXECUTION_FILE
  write_gh_stub "${TMP_DIR}/gh-shim.sh"
  install_gh_stub "${TMP_DIR}/gh-shim.sh"
  export GH_STUB_BODY=$'Issue body text\n\nMAXIMUM_FIX_PRIORITY:HIGH\n'

  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  assert_github_output_lines 1
  [ "$(get_output_value priority)" = "HIGH" ]
}

@test "fallback gh issue body with example block + verdict returns verdict" {
  unset EXECUTION_FILE
  write_gh_stub "${TMP_DIR}/gh-shim.sh"
  install_gh_stub "${TMP_DIR}/gh-shim.sh"
  export GH_STUB_BODY=$'MAXIMUM_FIX_PRIORITY:NONE\nMAXIMUM_FIX_PRIORITY:XLOW\nMAXIMUM_FIX_PRIORITY:LOW\nMAXIMUM_FIX_PRIORITY:MEDIUM\nMAXIMUM_FIX_PRIORITY:HIGH\n\nMAXIMUM_FIX_PRIORITY:LOW\n'

  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(get_output_value priority)" = "LOW" ]
}

@test "missing execution file and empty gh response writes NONE" {
  unset EXECUTION_FILE
  write_gh_stub "${TMP_DIR}/gh-shim.sh"
  install_gh_stub "${TMP_DIR}/gh-shim.sh"
  export GH_STUB_BODY=""

  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  assert_github_output_lines 1
  [ "$(get_output_value priority)" = "NONE" ]
}

@test "invalid token in execution file is sanitised to NONE" {
  export EXECUTION_FILE
  EXECUTION_FILE=$(make_exec_file "MAXIMUM_FIX_PRIORITY:BANANA")
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(get_output_value priority)" = "NONE" ]
}

@test "jq startswith filter uses 'review(area):' (issue 88 item 6)" {
  # If the filter were unanchored (`startswith("review(code")`), area
  # "code" would match neighbouring issues like "review(code-quality):".
  # Verify the script passes the closing `):` to gh's --jq.
  unset EXECUTION_FILE
  write_gh_stub "${TMP_DIR}/gh-shim.sh"
  install_gh_stub "${TMP_DIR}/gh-shim.sh"
  export GH_STUB_BODY="MAXIMUM_FIX_PRIORITY:LOW"
  export REVIEW_AREA="code"

  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  # The shim records its full argv in TMP_DIR/gh_calls.log.
  grep -q 'review(code):' "${TMP_DIR}/gh_calls.log"
}

@test "required env vars are enforced" {
  unset REVIEW_AREA
  run "${SCRIPT}"
  [ "${status}" -ne 0 ]
}
