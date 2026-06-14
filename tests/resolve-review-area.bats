#!/usr/bin/env bats

load test_helper

SCRIPT="${BATS_TEST_DIRNAME}/../.github/scripts/resolve-review-area.sh"

ALL_AREAS_JSON='["security","privacy","compliance","ai-compliance","error-handling","code-quality","performance","testing","documentation","dependency-health","correctness","e-commerce"]'

setup() { setup_tmp; }
teardown() { teardown_tmp; }

@test "schedule expands to the full ALL_AREAS array" {
  EVENT_NAME=schedule run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(output_value areas_json)" = "${ALL_AREAS_JSON}" ]
}

@test "workflow_dispatch with 'all' expands to the full ALL_AREAS array" {
  EVENT_NAME=workflow_dispatch INPUT_REVIEW_AREA=all run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(output_value areas_json)" = "${ALL_AREAS_JSON}" ]
}

@test "workflow_dispatch with a valid single area emits a one-element array" {
  EVENT_NAME=workflow_dispatch INPUT_REVIEW_AREA=testing run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(output_value areas_json)" = '["testing"]' ]
}

@test "workflow_dispatch defaults to security when INPUT_REVIEW_AREA is unset" {
  EVENT_NAME=workflow_dispatch run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(output_value areas_json)" = '["security"]' ]
}

@test "every canonical area is accepted as a single area" {
  local areas=(security privacy compliance ai-compliance error-handling code-quality performance testing documentation dependency-health correctness e-commerce)
  for area in "${areas[@]}"; do
    setup_tmp
    EVENT_NAME=workflow_dispatch INPUT_REVIEW_AREA="${area}" run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "$(output_value areas_json)" = "[\"${area}\"]" ]
    teardown_tmp
  done
}

@test "an unknown area fails fast with a clear message and writes nothing" {
  EVENT_NAME=workflow_dispatch INPUT_REVIEW_AREA=bogus run "${SCRIPT}"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Unknown review area: 'bogus'"* ]]
  [ ! -s "${GITHUB_OUTPUT}" ]
}

@test "an empty area string is rejected (not silently turned into an empty matrix entry)" {
  EVENT_NAME=workflow_dispatch INPUT_REVIEW_AREA="" run "${SCRIPT}"
  # Empty defaults to security (parameter default), which is valid.
  [ "${status}" -eq 0 ]
  [ "$(output_value areas_json)" = '["security"]' ]
}

@test "a whitespace-only area is rejected" {
  EVENT_NAME=workflow_dispatch INPUT_REVIEW_AREA="  " run "${SCRIPT}"
  [ "${status}" -ne 0 ]
}

@test "fails when GITHUB_OUTPUT is unset" {
  run env -u GITHUB_OUTPUT EVENT_NAME=schedule "${SCRIPT}"
  [ "${status}" -ne 0 ]
}

@test "fails when EVENT_NAME is unset" {
  run env -u EVENT_NAME "${SCRIPT}"
  [ "${status}" -ne 0 ]
}
