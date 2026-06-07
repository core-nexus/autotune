#!/usr/bin/env bats

load test_helper

@test "triggers the default CI workflow names when WORKFLOWS is unset" {
  export REPO=core-nexus/autotune BRANCH=feature
  export STUB_GH_LOG="${TEST_TMP}/gh.log"
  run "${SCRIPTS_DIR}/trigger-ci-workflows.sh"
  [ "$status" -eq 0 ]
  [ "$(wc -l <"${STUB_GH_LOG}")" -eq 3 ]
  grep -q 'workflow run ci.yml --ref feature --repo core-nexus/autotune' "${STUB_GH_LOG}"
  grep -q 'workflow run checks.yml --ref feature' "${STUB_GH_LOG}"
  grep -q 'workflow run test.yml --ref feature' "${STUB_GH_LOG}"
}

@test "triggers exactly the workflows listed in WORKFLOWS" {
  export REPO=core-nexus/autotune BRANCH=main
  export WORKFLOWS="a.yml b.yml"
  export STUB_GH_LOG="${TEST_TMP}/gh.log"
  run "${SCRIPTS_DIR}/trigger-ci-workflows.sh"
  [ "$status" -eq 0 ]
  [ "$(wc -l <"${STUB_GH_LOG}")" -eq 2 ]
  grep -q 'workflow run a.yml --ref main' "${STUB_GH_LOG}"
  grep -q 'workflow run b.yml --ref main' "${STUB_GH_LOG}"
}

@test "a non-dispatchable workflow is skipped without failing the script" {
  export REPO=core-nexus/autotune BRANCH=main
  export WORKFLOWS="missing.yml"
  export STUB_GH_EXIT=1
  run "${SCRIPTS_DIR}/trigger-ci-workflows.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Skipped: missing.yml"* ]]
}

@test "missing BRANCH fails fast" {
  export REPO=core-nexus/autotune
  run "${SCRIPTS_DIR}/trigger-ci-workflows.sh"
  [ "$status" -ne 0 ]
}
