#!/usr/bin/env bats

load test_helper

ALL_AREAS='["security","privacy","compliance","ai-compliance","error-handling","code-quality","performance","testing","documentation","dependency-health","correctness","e-commerce"]'

@test "schedule trigger emits the full 12-area list" {
  export EVENT_NAME=schedule
  run "${SCRIPTS_DIR}/resolve-review-area.sh"
  [ "$status" -eq 0 ]
  [ "$(output_value areas_json)" = "${ALL_AREAS}" ]
}

@test "workflow_dispatch with 'all' emits the full 12-area list" {
  export EVENT_NAME=workflow_dispatch INPUT_REVIEW_AREA=all
  run "${SCRIPTS_DIR}/resolve-review-area.sh"
  [ "$status" -eq 0 ]
  [ "$(output_value areas_json)" = "${ALL_AREAS}" ]
}

@test "workflow_dispatch with a single area emits just that area" {
  export EVENT_NAME=workflow_dispatch INPUT_REVIEW_AREA=testing
  run "${SCRIPTS_DIR}/resolve-review-area.sh"
  [ "$status" -eq 0 ]
  [ "$(output_value areas_json)" = '["testing"]' ]
}

@test "workflow_dispatch with no area defaults to security" {
  export EVENT_NAME=workflow_dispatch
  run "${SCRIPTS_DIR}/resolve-review-area.sh"
  [ "$status" -eq 0 ]
  [ "$(output_value areas_json)" = '["security"]' ]
}

@test "missing GITHUB_OUTPUT fails fast" {
  export EVENT_NAME=schedule
  unset GITHUB_OUTPUT
  run "${SCRIPTS_DIR}/resolve-review-area.sh"
  [ "$status" -ne 0 ]
}

@test "missing EVENT_NAME fails fast" {
  run "${SCRIPTS_DIR}/resolve-review-area.sh"
  [ "$status" -ne 0 ]
}
