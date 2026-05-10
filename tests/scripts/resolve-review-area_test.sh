#!/usr/bin/env bash
# Tests for .github/workflows/scripts/resolve-review-area.sh.

set -euo pipefail

SUT="${SCRIPTS_DIR}/resolve-review-area.sh"

_run_sut() {
  local event_name="$1"
  local input_area="${2:-}"

  local tmpdir
  tmpdir=$(make_tmpdir)
  local output_file="${tmpdir}/github_output"
  : > "${output_file}"

  (
    export GITHUB_OUTPUT="${output_file}"
    export EVENT_NAME="${event_name}"
    if [[ -n "${input_area}" ]]; then
      export INPUT_REVIEW_AREA="${input_area}"
    fi
    bash "${SUT}" >/dev/null 2>&1 || true
  )

  grep -oP '(?<=^areas_json=).*' "${output_file}" | tail -1 || true
  rm -rf "${tmpdir}"
}

test_schedule_emits_all_areas() {
  local out
  out=$(_run_sut "schedule")
  assert_contains "${out}" '"security"' "schedule should include security"
  assert_contains "${out}" '"testing"' "schedule should include testing"
  assert_contains "${out}" '"e-commerce"' "schedule should include e-commerce"
  if ! echo "${out}" | jq -e 'type == "array"' >/dev/null; then
    printf '    schedule output is not a JSON array: %s\n' "${out}" >&2
    return 1
  fi
}

test_workflow_dispatch_with_specific_area() {
  local out
  out=$(_run_sut "workflow_dispatch" "security")
  assert_eq '["security"]' "${out}"
}

test_workflow_dispatch_with_all() {
  local out
  out=$(_run_sut "workflow_dispatch" "all")
  assert_contains "${out}" '"security"'
  assert_contains "${out}" '"testing"'
  if ! echo "${out}" | jq -e 'type == "array" and length >= 12' >/dev/null; then
    printf '    "all" output should be array of >=12 areas: %s\n' "${out}" >&2
    return 1
  fi
}

test_workflow_dispatch_default_when_no_input() {
  # If INPUT_REVIEW_AREA is unset, the script defaults to "security".
  local out
  out=$(_run_sut "workflow_dispatch" "")
  assert_eq '["security"]' "${out}" "default should be security when INPUT_REVIEW_AREA unset"
}
