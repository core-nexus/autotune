#!/usr/bin/env bats
#
# Regression test (M1): the canonical list of review areas is duplicated across
# three places that MUST stay in sync. Nothing else verifies they match, and the
# review found observable drift. This test fails the moment they diverge.
#
#   1. ALL_AREAS in resolve-review-area.sh
#   2. workflow_dispatch inputs.review_area.options in codebase-review.yml
#      (minus the "all" sentinel)
#   3. The Review Areas table in README.md

load helpers

setup() {
  RESOLVE_SCRIPT="${SCRIPTS_DIR}/resolve-review-area.sh"
  WORKFLOW="${REPO_ROOT}/.github/workflows/codebase-review.yml"
  README="${REPO_ROOT}/README.md"
}

# Sorted, newline-delimited areas declared in ALL_AREAS.
areas_from_script() {
  grep -oP "(?<=^ALL_AREAS=')[^']+" "${RESOLVE_SCRIPT}" | jq -r '.[]' | sort
}

# Sorted areas from the workflow_dispatch choice options, minus "all".
areas_from_workflow() {
  awk '
    /^ *options:/ { inblock = 1; next }
    inblock && /^ *- / { gsub(/^ *- /, ""); print; next }
    inblock { inblock = 0 }
  ' "${WORKFLOW}" | grep -vx 'all' | sort
}

# Sorted areas from the README review-areas table (| **area** | ... |).
areas_from_readme() {
  grep -oP '(?<=\| \*\*)[a-z-]+(?=\*\*)' "${README}" | sort -u
}

@test "ALL_AREAS parses as valid JSON" {
  run bash -c "$(declare -f areas_from_script); areas_from_script"
  [ "${status}" -eq 0 ]
  [ -n "${output}" ]
}

@test "script ALL_AREAS matches the workflow_dispatch options" {
  diff <(areas_from_script) <(areas_from_workflow)
}

@test "script ALL_AREAS matches the README review-areas table" {
  diff <(areas_from_script) <(areas_from_readme)
}

@test "the README area count matches ALL_AREAS" {
  local count
  count=$(areas_from_script | wc -l | tr -d ' ')
  # e.g. "Running all 12 areas weekly ..."
  grep -qE "all ${count} areas" "${README}"
}
