#!/usr/bin/env bats
# Tests for resolve-review-area.sh.

load helpers

SCRIPT="${SCRIPTS_DIR}/resolve-review-area.sh"

# Keep this list in sync with ALL_AREAS_LIST in resolve-review-area.sh.
# The first @test below asserts they agree, so any drift fails fast.
EXPECTED_AREAS=(
  security
  privacy
  compliance
  ai-compliance
  error-handling
  code-quality
  performance
  testing
  documentation
  dependency-health
  correctness
  e-commerce
)

setup() { setup_tmp; }
teardown() { teardown_tmp; }

@test "ALL_AREAS_LIST in script matches the test's expected set" {
  # Extract the array literal from the script's source and compare line-by-line.
  actual=$(awk '
    /^ALL_AREAS_LIST=\(/ { in_arr = 1; next }
    in_arr && /^\)/      { exit }
    in_arr               { gsub(/^[ \t]+|[ \t]+$/, "", $0); if ($0) print }
  ' "${SCRIPT}")
  expected=$(printf '%s\n' "${EXPECTED_AREAS[@]}")
  [ "${actual}" = "${expected}" ]
}

@test "every area in ALL_AREAS_LIST has a prompt file (issue 88 item 4)" {
  for area in "${EXPECTED_AREAS[@]}"; do
    [ -f "${PROMPTS_DIR}/${area}.md" ] || {
      echo "missing prompt file for area: ${area}" >&2
      return 1
    }
  done
}

@test "every prompt file corresponds to an area in ALL_AREAS_LIST (no drift)" {
  for f in "${PROMPTS_DIR}"/*.md; do
    area=$(basename "${f}" .md)
    found=0
    for a in "${EXPECTED_AREAS[@]}"; do
      if [[ "${a}" = "${area}" ]]; then found=1; break; fi
    done
    [ "${found}" -eq 1 ] || {
      echo "prompt file with no matching area in ALL_AREAS_LIST: ${area}" >&2
      return 1
    }
  done
}

@test "workflow_dispatch + specific valid area emits single-element JSON array" {
  export EVENT_NAME="workflow_dispatch"
  export INPUT_REVIEW_AREA="security"
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(get_output_value areas_json)" = '["security"]' ]
}

@test "workflow_dispatch + 'all' emits the full JSON array" {
  export EVENT_NAME="workflow_dispatch"
  export INPUT_REVIEW_AREA="all"
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  value=$(get_output_value areas_json)
  [[ "${value}" == \[\"security\"* ]]
  [[ "${value}" == *\"e-commerce\"\] ]]
}

@test "workflow_dispatch without INPUT_REVIEW_AREA defaults to security" {
  export EVENT_NAME="workflow_dispatch"
  unset INPUT_REVIEW_AREA
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(get_output_value areas_json)" = '["security"]' ]
}

@test "schedule event emits the full JSON array" {
  export EVENT_NAME="schedule"
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  value=$(get_output_value areas_json)
  [[ "${value}" == \[\"security\"* ]]
  [[ "${value}" == *\"e-commerce\"\] ]]
}

@test "unknown area fails fast (issue 88 item 4)" {
  # Previously the script wrote areas_json=["bogus-area"] and let the
  # matrix job 404 on a missing prompt file. Now it must exit non-zero.
  export EVENT_NAME="workflow_dispatch"
  export INPUT_REVIEW_AREA="bogus-area"
  run "${SCRIPT}"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Unknown review area"* ]]
  [[ "${output}" == *"bogus-area"* ]]
}

@test "required env vars are enforced" {
  unset EVENT_NAME
  run "${SCRIPT}"
  [ "${status}" -ne 0 ]
}
