#!/usr/bin/env bats
load helpers/common

ALL='["security","privacy","compliance","ai-compliance","error-handling","code-quality","performance","testing","documentation","dependency-health","correctness","e-commerce"]'

@test "schedule trigger emits the full area matrix" {
  export EVENT_NAME=schedule
  run bash "${SCRIPTS_DIR}/resolve-review-area.sh"
  [ "$status" -eq 0 ]
  [ "$(output_value areas_json)" = "${ALL}" ]
}

@test "workflow_dispatch with a valid area emits just that area" {
  export EVENT_NAME=workflow_dispatch
  export INPUT_REVIEW_AREA=testing
  run bash "${SCRIPTS_DIR}/resolve-review-area.sh"
  [ "$status" -eq 0 ]
  [ "$(output_value areas_json)" = '["testing"]' ]
}

@test "workflow_dispatch with 'all' emits the full area matrix" {
  export EVENT_NAME=workflow_dispatch
  export INPUT_REVIEW_AREA=all
  run bash "${SCRIPTS_DIR}/resolve-review-area.sh"
  [ "$status" -eq 0 ]
  [ "$(output_value areas_json)" = "${ALL}" ]
}

@test "workflow_dispatch with no input defaults to security" {
  export EVENT_NAME=workflow_dispatch
  run bash "${SCRIPTS_DIR}/resolve-review-area.sh"
  [ "$status" -eq 0 ]
  [ "$(output_value areas_json)" = '["security"]' ]
}

@test "workflow_dispatch with an unknown area fails fast and writes nothing" {
  export EVENT_NAME=workflow_dispatch
  export INPUT_REVIEW_AREA=typo
  run bash "${SCRIPTS_DIR}/resolve-review-area.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown review area: 'typo'"* ]]
  [ "$(output_line_count)" -eq 0 ]
}
