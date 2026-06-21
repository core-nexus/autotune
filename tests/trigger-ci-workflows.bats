#!/usr/bin/env bats
#
# Black-box tests for trigger-ci-workflows.sh — dispatches CI workflows on a
# branch. `gh workflow run` is stubbed and its invocations recorded.

load test_helper

SCRIPT="${SCRIPTS_DIR}/trigger-ci-workflows.sh"

teardown() { teardown_gh_stub; return 0; }

@test "dispatches each workflow once on the given branch/repo" {
  use_gh_stub
  REPO="o/r" BRANCH="my-branch" WORKFLOWS="ci.yml test.yml" run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(wc -l < "${GH_STUB_LOG}")" -eq 2 ]
  grep -q 'workflow run ci.yml --ref my-branch --repo o/r' "${GH_STUB_LOG}"
  grep -q 'workflow run test.yml --ref my-branch --repo o/r' "${GH_STUB_LOG}"
}

@test "a missing/non-dispatchable workflow does not abort the rest" {
  use_gh_stub
  export GH_STUB_RC=1   # every dispatch "fails"
  REPO="o/r" BRANCH="b" WORKFLOWS="a.yml b.yml c.yml" run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(wc -l < "${GH_STUB_LOG}")" -eq 3 ]
  echo "$output" | grep -q "Skipped: a.yml"
  echo "$output" | grep -q "Skipped: c.yml"
}

@test "defaults to common workflow names when WORKFLOWS is unset" {
  use_gh_stub
  REPO="o/r" BRANCH="feat" run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  grep -q 'workflow run ci.yml' "${GH_STUB_LOG}"
  grep -q 'workflow run checks.yml' "${GH_STUB_LOG}"
  grep -q 'workflow run test.yml' "${GH_STUB_LOG}"
}

@test "aborts when BRANCH is unset" {
  REPO="o/r" run bash "${SCRIPT}"
  [ "$status" -ne 0 ]
}

@test "aborts when REPO is unset" {
  BRANCH="b" run bash "${SCRIPT}"
  [ "$status" -ne 0 ]
}
