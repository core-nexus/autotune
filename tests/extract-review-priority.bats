#!/usr/bin/env bats
#
# Tests for .github/workflows/scripts/extract-review-priority.sh
# Covers the execution-file path (Method 1), the gh-issue fallback (Method 2),
# the multi-marker robustness fix (tail -1 on the fallback), and the NONE default.

load helpers/common

setup() {
  setup_tmp
  export REVIEW_AREA=testing REPO=core-nexus/autotune
}

@test "method 1: single marker in execution file is extracted" {
  export EXECUTION_FILE="${FIXTURES_DIR}/execution-single.txt"
  run "${SCRIPTS_DIR}/extract-review-priority.sh"
  [ "$status" -eq 0 ]
  [ "$(cat "${GITHUB_OUTPUT}")" = "priority=MEDIUM" ]
}

@test "method 1: multiple markers collapse to the last value, one clean line" {
  export EXECUTION_FILE="${FIXTURES_DIR}/execution-multi.txt"
  run "${SCRIPTS_DIR}/extract-review-priority.sh"
  [ "$status" -eq 0 ]
  [ "$(wc -l < "${GITHUB_OUTPUT}")" -eq 1 ]
  [ "$(cat "${GITHUB_OUTPUT}")" = "priority=HIGH" ]
}

@test "fallback: multiple markers in issue body collapse to a single clean line" {
  # No EXECUTION_FILE -> force the gh issue list fallback (Method 2).
  stub_gh "${FIXTURES_DIR}/issue-body-multi.txt"
  run "${SCRIPTS_DIR}/extract-review-priority.sh"
  [ "$status" -eq 0 ]
  # The fix: exactly one line, not one per matched marker.
  [ "$(wc -l < "${GITHUB_OUTPUT}")" -eq 1 ]
  [ "$(cat "${GITHUB_OUTPUT}")" = "priority=MEDIUM" ]
}

@test "no marker anywhere yields NONE" {
  stub_gh "${FIXTURES_DIR}/no-marker.txt"
  run "${SCRIPTS_DIR}/extract-review-priority.sh"
  [ "$status" -eq 0 ]
  [ "$(cat "${GITHUB_OUTPUT}")" = "priority=NONE" ]
}
