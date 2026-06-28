#!/usr/bin/env bats
#
# Tests for .github/workflows/scripts/extract-pr-review-priority.sh
# Covers single-marker extraction, the multi-marker robustness fix (tail -1),
# and the NONE default when no marker is present.

load helpers/common

setup() {
  setup_tmp
  export REPO=core-nexus/autotune PR_NUMBER=42
}

@test "single marker comment is extracted" {
  stub_gh "${FIXTURES_DIR}/pr-comment-single.txt"
  run "${SCRIPTS_DIR}/extract-pr-review-priority.sh"
  [ "$status" -eq 0 ]
  [ "$(wc -l < "${GITHUB_OUTPUT}")" -eq 1 ]
  [ "$(cat "${GITHUB_OUTPUT}")" = "priority=LOW" ]
}

@test "multiple markers collapse to the last value, one clean line" {
  stub_gh "${FIXTURES_DIR}/pr-comment-multi.txt"
  run "${SCRIPTS_DIR}/extract-pr-review-priority.sh"
  [ "$status" -eq 0 ]
  # The fix: a multi-marker body must not write a multi-line step output.
  [ "$(wc -l < "${GITHUB_OUTPUT}")" -eq 1 ]
  [ "$(cat "${GITHUB_OUTPUT}")" = "priority=HIGH" ]
}

@test "no marker in the comment yields NONE" {
  stub_gh "${FIXTURES_DIR}/no-marker.txt"
  run "${SCRIPTS_DIR}/extract-pr-review-priority.sh"
  [ "$status" -eq 0 ]
  [ "$(cat "${GITHUB_OUTPUT}")" = "priority=NONE" ]
}
