#!/usr/bin/env bats
# Tests for trigger-ci-workflows.sh — verifies it dispatches each configured
# workflow and degrades gracefully when a workflow is not dispatchable.

load helper

SCRIPT="${BATS_TEST_DIRNAME}/../../.github/workflows/scripts/trigger-ci-workflows.sh"

setup() {
  setup_workspace
}

teardown() {
  teardown_workspace
}

# A gh stub that records each `workflow run` invocation to a log file.
stub_gh_recording() {
  STUB_BIN="$(mktemp -d)"
  cat >"${STUB_BIN}/gh" <<EOF
#!/usr/bin/env bash
echo "\$*" >>"${TEST_TMP}/gh_calls.log"
exit 0
EOF
  chmod +x "${STUB_BIN}/gh"
  export PATH="${STUB_BIN}:${PATH}"
}

@test "dispatches every workflow in WORKFLOWS on the given branch" {
  stub_gh_recording
  REPO=owner/repo BRANCH=review/testing-2026-07-12 WORKFLOWS="ci.yml lint.yml" \
    run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(grep -c 'workflow run' "${TEST_TMP}/gh_calls.log")" -eq 2 ]
  grep -q 'workflow run ci.yml --ref review/testing-2026-07-12 --repo owner/repo' \
    "${TEST_TMP}/gh_calls.log"
  grep -q 'workflow run lint.yml --ref review/testing-2026-07-12 --repo owner/repo' \
    "${TEST_TMP}/gh_calls.log"
}

@test "reports a skip when a workflow is not dispatchable" {
  # gh exits non-zero -> script should emit a 'Skipped' line, not fail.
  stub_gh 'exit 1'
  REPO=owner/repo BRANCH=main WORKFLOWS="missing.yml" run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Skipped: missing.yml"* ]]
}

@test "uses the default workflow list when WORKFLOWS is unset" {
  stub_gh_recording
  REPO=owner/repo BRANCH=main run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  # Defaults are ci.yml checks.yml test.yml -> three dispatch attempts.
  [ "$(grep -c 'workflow run' "${TEST_TMP}/gh_calls.log")" -eq 3 ]
}

@test "missing BRANCH fails fast" {
  run env -u BRANCH REPO=owner/repo bash "${SCRIPT}"
  [ "$status" -ne 0 ]
}
