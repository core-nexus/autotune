#!/usr/bin/env bats
#
# Tests for trigger-ci-workflows.sh — dispatches a list of CI workflows on a
# branch, tolerating individual workflows that don't exist / aren't dispatchable.

load helpers

setup() {
  setup_env
  SCRIPT="${SCRIPTS_DIR}/trigger-ci-workflows.sh"
  export REPO=core-nexus/autotune
  export BRANCH=review/testing-2026-07-05
  export GH_TOKEN=fake-token
}

@test "a failing workflow does not abort the loop; the rest still dispatch" {
  # $3 is the workflow filename: succeed for ok.yml, fail for missing.yml.
  write_gh <<'EOF'
if [ "$3" = "missing.yml" ]; then
  echo "gh: workflow not found" >&2
  exit 1
fi
echo "dispatched $3"
EOF
  WORKFLOWS="ok.yml missing.yml also-ok.yml" run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"dispatched ok.yml"* ]]
  [[ "${output}" == *"Skipped: missing.yml"* ]]
  [[ "${output}" == *"dispatched also-ok.yml"* ]]
}

@test "every workflow succeeding produces no Skipped messages" {
  write_gh <<'EOF'
echo "dispatched $3"
EOF
  WORKFLOWS="ci.yml" run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"dispatched ci.yml"* ]]
  [[ "${output}" != *"Skipped"* ]]
}

@test "missing BRANCH causes a non-zero exit" {
  run env -u BRANCH "${SCRIPT}"
  [ "${status}" -ne 0 ]
}

@test "missing REPO causes a non-zero exit" {
  run env -u REPO "${SCRIPT}"
  [ "${status}" -ne 0 ]
}
