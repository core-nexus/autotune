#!/usr/bin/env bats
# Tests for resolve-review-area.sh — verifies each branch of the area
# resolution logic and that the emitted areas_json is valid JSON.

load helper

SCRIPT="${BATS_TEST_DIRNAME}/../../.github/workflows/scripts/resolve-review-area.sh"

ALL_AREAS='["security","privacy","compliance","ai-compliance","error-handling","code-quality","performance","testing","documentation","dependency-health","correctness","e-commerce"]'

setup() {
  setup_workspace
}

teardown() {
  teardown_workspace
}

@test "workflow_dispatch with a single area emits a one-element array" {
  EVENT_NAME=workflow_dispatch INPUT_REVIEW_AREA=testing run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(output_line_count areas_json)" -eq 1 ]
  [ "$(output_value areas_json)" = '["testing"]' ]
}

@test "workflow_dispatch single-area output is valid JSON" {
  EVENT_NAME=workflow_dispatch INPUT_REVIEW_AREA=security run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  echo "$(output_value areas_json)" | jq -e '. == ["security"]'
}

@test "workflow_dispatch with 'all' emits the full area list" {
  EVENT_NAME=workflow_dispatch INPUT_REVIEW_AREA=all run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(output_value areas_json)" = "${ALL_AREAS}" ]
  echo "$(output_value areas_json)" | jq -e 'length == 12'
}

@test "workflow_dispatch without an area input defaults to security" {
  EVENT_NAME=workflow_dispatch run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(output_value areas_json)" = '["security"]' ]
}

@test "schedule event runs all areas" {
  EVENT_NAME=schedule run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(output_value areas_json)" = "${ALL_AREAS}" ]
  echo "$(output_value areas_json)" | jq -e '. | index("correctness") != null'
}

@test "missing GITHUB_OUTPUT fails fast" {
  run env -u GITHUB_OUTPUT EVENT_NAME=schedule bash "${SCRIPT}"
  [ "$status" -ne 0 ]
}

@test "missing EVENT_NAME fails fast" {
  run env -u EVENT_NAME bash "${SCRIPT}"
  [ "$status" -ne 0 ]
}
