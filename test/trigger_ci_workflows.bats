#!/usr/bin/env bats
# Tests for trigger-ci-workflows.sh.

load helpers

SCRIPT="${SCRIPTS_DIR}/trigger-ci-workflows.sh"

setup() {
  setup_tmp
  export REPO="owner/repo"
  export BRANCH="review/testing-2026-05-31"
  export GH_TOKEN="dummy"
  write_gh_stub "${TMP_DIR}/gh-shim.sh"
  install_gh_stub "${TMP_DIR}/gh-shim.sh"
}

teardown() { teardown_tmp; }

@test "success path: each configured workflow is dispatched once" {
  export WORKFLOWS="ci.yml"
  export GH_STUB_EXIT=0
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"dispatched"* ]]
  # One workflow run call recorded.
  [ "$(wc -l < "${TMP_DIR}/gh_calls.log")" -eq 1 ]
  grep -q "workflow run ci.yml --ref ${BRANCH}" "${TMP_DIR}/gh_calls.log"
}

@test "not-found error is reported as a skip, not a warning (issue 88 item 8)" {
  export WORKFLOWS="missing.yml"
  export GH_STUB_EXIT=1
  export GH_STUB_STDERR="Could not find any workflows named missing.yml"
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Skipped: missing.yml (not found)"* ]]
  [[ "${output}" != *"::warning::"* ]]
}

@test "generic failure surfaces a ::warning:: instead of being swallowed (issue 88 item 8)" {
  # A transient network or auth failure should NOT look like "not found".
  export WORKFLOWS="ci.yml"
  export GH_STUB_EXIT=1
  export GH_STUB_STDERR="HTTP 503: service unavailable"
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"::warning::Failed to dispatch ci.yml"* ]]
  [[ "${output}" == *"503"* ]]
}

@test "multi-workflow list dispatches each in order" {
  export WORKFLOWS="ci.yml checks.yml test.yml"
  export GH_STUB_EXIT=0
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(wc -l < "${TMP_DIR}/gh_calls.log")" -eq 3 ]
  # The recorded args contain each workflow name in order.
  workflows_seen=$(awk '{print $3}' "${TMP_DIR}/gh_calls.log" | tr '\n' ' ')
  [ "${workflows_seen}" = "ci.yml checks.yml test.yml " ]
}

@test "required env vars are enforced" {
  unset BRANCH
  run "${SCRIPT}"
  [ "${status}" -ne 0 ]
}
