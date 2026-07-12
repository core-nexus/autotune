#!/usr/bin/env bats
# Tests for extract-pr-review-priority.sh — covers a normal single-marker
# comment, the NONE default when no marker is present, and the multi-match
# regression guarded by `tail -1`.

load helper

SCRIPT="${BATS_TEST_DIRNAME}/../../.github/workflows/scripts/extract-pr-review-priority.sh"

setup() {
  setup_workspace
}

teardown() {
  teardown_workspace
}

@test "extracts priority from the latest PR comment" {
  # The script pipes gh's output through jq's `last`, so a real body string
  # is returned here; the script's own grep does the extraction.
  stub_gh 'printf "MAXIMUM_FIX_PRIORITY:HIGH\n"'
  REPO=owner/repo PR_NUMBER=42 run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(output_value priority)" = "HIGH" ]
}

@test "comment with two markers yields exactly one clean value (tail -1)" {
  # Regression for finding 2 of the testing review. The `| tail -1` fix lives in
  # extract-pr-review-priority.sh, which is under .github/workflows/ and cannot
  # be committed by the review-bot token (missing GitHub `workflows` write
  # permission). The fix diff is in the PR body; remove this skip once it is
  # applied and this test will pass and guard the multiline regression.
  skip "pending blocked script fix (finding 2) — see PR body"
  stub_gh 'printf "MAXIMUM_FIX_PRIORITY:LOW discussed inline\n\nMAXIMUM_FIX_PRIORITY:CRITICAL\n"'
  REPO=owner/repo PR_NUMBER=42 run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(output_line_count priority)" -eq 1 ]
  [ "$(output_value priority)" = "CRITICAL" ]
}

@test "defaults to NONE when no marker is present" {
  stub_gh 'printf "just a regular comment\n"'
  REPO=owner/repo PR_NUMBER=42 run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(output_value priority)" = "NONE" ]
}

@test "defaults to NONE when gh returns nothing" {
  stub_gh 'true'
  REPO=owner/repo PR_NUMBER=42 run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(output_value priority)" = "NONE" ]
}

@test "missing PR_NUMBER fails fast" {
  run env -u PR_NUMBER REPO=owner/repo bash "${SCRIPT}"
  [ "$status" -ne 0 ]
}
