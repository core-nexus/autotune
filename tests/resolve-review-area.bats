#!/usr/bin/env bats
#
# Tests for .github/workflows/scripts/resolve-review-area.sh
# Exercises every branch: schedule, dispatch+all, dispatch+specific,
# dispatch default, and the new invalid-area validation.

load helpers/common

ALL_AREAS_JSON='areas_json=["security","privacy","compliance","ai-compliance","error-handling","code-quality","performance","testing","documentation","dependency-health","correctness","e-commerce"]'

@test "schedule event resolves to all twelve areas" {
  export EVENT_NAME=schedule
  run "${SCRIPTS_DIR}/resolve-review-area.sh"
  [ "$status" -eq 0 ]
  [ "$(cat "${GITHUB_OUTPUT}")" = "${ALL_AREAS_JSON}" ]
}

@test "workflow_dispatch with 'all' resolves to all twelve areas" {
  export EVENT_NAME=workflow_dispatch INPUT_REVIEW_AREA=all
  run "${SCRIPTS_DIR}/resolve-review-area.sh"
  [ "$status" -eq 0 ]
  [ "$(cat "${GITHUB_OUTPUT}")" = "${ALL_AREAS_JSON}" ]
}

@test "workflow_dispatch with a specific area resolves to just that area" {
  export EVENT_NAME=workflow_dispatch INPUT_REVIEW_AREA=testing
  run "${SCRIPTS_DIR}/resolve-review-area.sh"
  [ "$status" -eq 0 ]
  [ "$(cat "${GITHUB_OUTPUT}")" = 'areas_json=["testing"]' ]
}

@test "workflow_dispatch with no input defaults to security" {
  export EVENT_NAME=workflow_dispatch
  run "${SCRIPTS_DIR}/resolve-review-area.sh"
  [ "$status" -eq 0 ]
  [ "$(cat "${GITHUB_OUTPUT}")" = 'areas_json=["security"]' ]
}

@test "workflow_dispatch with an empty input defaults to security" {
  export EVENT_NAME=workflow_dispatch INPUT_REVIEW_AREA=
  run "${SCRIPTS_DIR}/resolve-review-area.sh"
  [ "$status" -eq 0 ]
  [ "$(cat "${GITHUB_OUTPUT}")" = 'areas_json=["security"]' ]
}

@test "workflow_dispatch with an unknown area fails and writes no output" {
  export EVENT_NAME=workflow_dispatch INPUT_REVIEW_AREA=bogus-area
  run "${SCRIPTS_DIR}/resolve-review-area.sh"
  [ "$status" -ne 0 ]
  [ ! -s "${GITHUB_OUTPUT}" ]
  [[ "$output" == *"unknown review area"* ]]
}

@test "every resolved area has a matching review-prompt file" {
  export EVENT_NAME=schedule
  run "${SCRIPTS_DIR}/resolve-review-area.sh"
  [ "$status" -eq 0 ]
  json="$(sed 's/^areas_json=//' "${GITHUB_OUTPUT}")"
  while read -r area; do
    [ -f "${REPO_ROOT}/.github/review-prompts/${area}.md" ]
  done < <(printf '%s' "${json}" | jq -r '.[]')
}
