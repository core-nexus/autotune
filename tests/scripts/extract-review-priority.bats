#!/usr/bin/env bats
# Tests for extract-review-priority.sh — covers the execution-file path, the
# `gh issue list` fallback path, the parse-failure default, and the
# multi-match (multiline) regression guarded by `tail -1`.

load helper

SCRIPT="${BATS_TEST_DIRNAME}/../../.github/workflows/scripts/extract-review-priority.sh"

setup() {
  setup_workspace
}

teardown() {
  teardown_workspace
}

@test "extracts priority from the execution file" {
  local exec_file="${TEST_TMP}/exec.txt"
  printf 'some review text\nMAXIMUM_FIX_PRIORITY:HIGH\n' >"${exec_file}"
  REVIEW_AREA=security REPO=owner/repo EXECUTION_FILE="${exec_file}" \
    run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(output_value priority)" = "HIGH" ]
}

@test "execution file with two markers yields exactly one clean value (tail -1)" {
  local exec_file="${TEST_TMP}/exec.txt"
  # First occurrence in prose, real marker at the end.
  printf 'We use MAXIMUM_FIX_PRIORITY:LOW as a discussion example.\n\nMAXIMUM_FIX_PRIORITY:CRITICAL\n' \
    >"${exec_file}"
  REVIEW_AREA=security REPO=owner/repo EXECUTION_FILE="${exec_file}" \
    run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(output_line_count priority)" -eq 1 ]
  [ "$(output_value priority)" = "CRITICAL" ]
}

@test "falls back to gh issue list when no execution file is present" {
  stub_gh 'printf "review(security): findings\n\nMAXIMUM_FIX_PRIORITY:MEDIUM\n"'
  REVIEW_AREA=security REPO=owner/repo run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(output_value priority)" = "MEDIUM" ]
}

@test "fallback path with two markers in the body yields one clean value (tail -1)" {
  # Regression for finding 2 of the testing review. The one-line `| tail -1`
  # fix lives in extract-review-priority.sh, which is under .github/workflows/
  # and cannot be committed by the review-bot token (missing GitHub `workflows`
  # write permission). The fix diff is in the PR body; remove this skip once it
  # is applied and this test will pass and guard the multiline regression.
  skip "pending blocked script fix (finding 2) — see PR body"
  stub_gh 'printf "MAXIMUM_FIX_PRIORITY:LOW mentioned inline\n\nMAXIMUM_FIX_PRIORITY:HIGH\n"'
  REVIEW_AREA=security REPO=owner/repo run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(output_line_count priority)" -eq 1 ]
  [ "$(output_value priority)" = "HIGH" ]
}

@test "defaults to NONE when nothing matches" {
  stub_gh 'printf "no marker here\n"'
  REVIEW_AREA=security REPO=owner/repo run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(output_value priority)" = "NONE" ]
}

@test "defaults to NONE when the execution file exists but lacks a marker" {
  local exec_file="${TEST_TMP}/exec.txt"
  printf 'a review with no priority marker\n' >"${exec_file}"
  stub_gh 'printf "still nothing\n"'
  REVIEW_AREA=security REPO=owner/repo EXECUTION_FILE="${exec_file}" \
    run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(output_value priority)" = "NONE" ]
}

@test "missing REVIEW_AREA fails fast" {
  run env -u REVIEW_AREA REPO=owner/repo bash "${SCRIPT}"
  [ "$status" -ne 0 ]
}
