#!/usr/bin/env bats
#
# Tests for resolve-review-area.sh — the branch logic that decides which review
# area(s) a run covers based on the triggering event.

load helpers

setup() {
  setup_env
  SCRIPT="${SCRIPTS_DIR}/resolve-review-area.sh"
  # The canonical full-area list, kept in sync with the script (see areas-sync.bats).
  ALL_AREAS='["security","privacy","compliance","ai-compliance","error-handling","code-quality","performance","testing","documentation","dependency-health","correctness","e-commerce"]'
}

@test "workflow_dispatch + 'all' emits the full area list" {
  EVENT_NAME=workflow_dispatch INPUT_REVIEW_AREA=all run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(output_value areas_json)" = "${ALL_AREAS}" ]
}

@test "workflow_dispatch + single area emits a one-element array" {
  EVENT_NAME=workflow_dispatch INPUT_REVIEW_AREA=testing run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(output_value areas_json)" = '["testing"]' ]
}

@test "workflow_dispatch with INPUT_REVIEW_AREA unset defaults to security" {
  EVENT_NAME=workflow_dispatch run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(output_value areas_json)" = '["security"]' ]
}

@test "schedule event emits the full area list" {
  EVENT_NAME=schedule run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(output_value areas_json)" = "${ALL_AREAS}" ]
}

@test "any non-dispatch event (e.g. push) falls through to the full area list" {
  EVENT_NAME=push run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(output_value areas_json)" = "${ALL_AREAS}" ]
}

@test "missing GITHUB_OUTPUT causes a non-zero exit (the :? guard)" {
  run env -u GITHUB_OUTPUT EVENT_NAME=schedule "${SCRIPT}"
  [ "${status}" -ne 0 ]
}

@test "missing EVENT_NAME causes a non-zero exit (the :? guard)" {
  run env -u EVENT_NAME "${SCRIPT}"
  [ "${status}" -ne 0 ]
}
