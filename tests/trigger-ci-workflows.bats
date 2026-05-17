#!/usr/bin/env bats
load helpers/common

@test "fails fast when GH_TOKEN is unset" {
  unset GH_TOKEN
  export REPO=owner/repo
  export BRANCH=review/testing-2026-05-17
  run bash "${SCRIPTS_DIR}/trigger-ci-workflows.sh"
  [ "$status" -ne 0 ]
}

@test "iterates every configured workflow when the token is present" {
  export GH_TOKEN=fake-token
  export REPO=owner/repo
  export BRANCH=review/testing-2026-05-17
  export WORKFLOWS="ci.yml checks.yml"
  run bash "${SCRIPTS_DIR}/trigger-ci-workflows.sh"
  [ "$status" -eq 0 ]
  grep -q "workflow run ci.yml --ref ${BRANCH} --repo ${REPO}" "${GH_STUB_CALLS}"
  grep -q "workflow run checks.yml --ref ${BRANCH} --repo ${REPO}" "${GH_STUB_CALLS}"
}

@test "reports a skipped workflow without aborting the run" {
  export GH_TOKEN=fake-token
  export REPO=owner/repo
  export BRANCH=review/testing-2026-05-17
  export WORKFLOWS="ci.yml missing.yml"
  export GH_STUB_FAIL_ARGS="missing.yml"
  run bash "${SCRIPTS_DIR}/trigger-ci-workflows.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Skipped: missing.yml"* ]]
}
