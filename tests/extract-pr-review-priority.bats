#!/usr/bin/env bats
#
# Black-box tests for extract-pr-review-priority.sh — extracts the fix priority
# from the latest PR review comment. `gh api` is stubbed (the only external
# boundary); the parsing runs for real.

load test_helper

SCRIPT="${SCRIPTS_DIR}/extract-pr-review-priority.sh"

setup() { OUT="$(mktemp)"; }
teardown() { rm -f "${OUT}"; teardown_gh_stub; return 0; }

@test "parses priority from the latest matching comment body" {
  use_gh_stub
  export GH_STUB_OUT="$(make_tmpfile 'latest comment text
MAXIMUM_FIX_PRIORITY:MEDIUM')"
  GITHUB_OUTPUT="${OUT}" REPO="o/r" PR_NUMBER="42" run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(output_priority "${OUT}")" = "MEDIUM" ]
}

@test "ignores other uppercase tokens in the comment body" {
  use_gh_stub
  export GH_STUB_OUT="$(make_tmpfile 'Mentions TODO and FIXME.
MAXIMUM_FIX_PRIORITY:HIGH')"
  GITHUB_OUTPUT="${OUT}" REPO="o/r" PR_NUMBER="42" run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(output_priority "${OUT}")" = "HIGH" ]
}

@test "defaults to NONE when no priority comment exists" {
  use_gh_stub
  export GH_STUB_OUT="$(make_tmpfile '')"
  GITHUB_OUTPUT="${OUT}" REPO="o/r" PR_NUMBER="42" run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(output_priority "${OUT}")" = "NONE" ]
}

@test "defaults to NONE when gh api fails" {
  use_gh_stub
  export GH_STUB_RC=1
  GITHUB_OUTPUT="${OUT}" REPO="o/r" PR_NUMBER="42" run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(output_priority "${OUT}")" = "NONE" ]
}

@test "aborts when PR_NUMBER is unset" {
  GITHUB_OUTPUT="${OUT}" REPO="o/r" run bash "${SCRIPT}"
  [ "$status" -ne 0 ]
}

@test "aborts when GITHUB_OUTPUT is unset" {
  run env -u GITHUB_OUTPUT REPO="o/r" PR_NUMBER="42" bash "${SCRIPT}"
  [ "$status" -ne 0 ]
}
