#!/usr/bin/env bats

load test_helper

SCRIPT="${BATS_TEST_DIRNAME}/../.github/scripts/trigger-ci-workflows.sh"

setup() {
  setup_tmp
  export REPO=core-nexus/autotune
  export BRANCH=review/testing-2026-06-14
}
teardown() { teardown_tmp; }

@test "iterates over the explicit WORKFLOWS list and reports each as triggered" {
  stub_gh 'exit 0'
  WORKFLOWS="ci.yml lint.yml" run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"-> ci.yml"* ]]
  [[ "${output}" == *"Triggered: ci.yml"* ]]
  [[ "${output}" == *"-> lint.yml"* ]]
  [[ "${output}" == *"Triggered: lint.yml"* ]]
}

@test "a not-found workflow is reported as Skipped, not Failed" {
  stub_gh 'echo "could not find any workflows named ${1}" >&2; exit 1'
  WORKFLOWS="ghost.yml" run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Skipped: ghost.yml"* ]]
  [[ "${output}" != *"Failed:"* ]]
}

@test "a genuine error is reported distinctly as Failed, not Skipped" {
  stub_gh 'echo "HTTP 401: Bad credentials" >&2; exit 1'
  WORKFLOWS="ci.yml" run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Failed: ci.yml"* ]]
  [[ "${output}" == *"Bad credentials"* ]]
  [[ "${output}" != *"Skipped:"* ]]
}

@test "the loop continues past a failing workflow to later ones" {
  # First workflow errors hard, second succeeds — both must be visited.
  stub_gh 'if [[ "$3" == "boom.yml" ]]; then echo "HTTP 500" >&2; exit 1; fi; exit 0'
  WORKFLOWS="boom.yml ci.yml" run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Failed: boom.yml"* ]]
  [[ "${output}" == *"Triggered: ci.yml"* ]]
}

@test "fails when REPO is unset" {
  run env -u REPO "${SCRIPT}"
  [ "${status}" -ne 0 ]
}

@test "fails when BRANCH is unset" {
  run env -u BRANCH "${SCRIPT}"
  [ "${status}" -ne 0 ]
}
