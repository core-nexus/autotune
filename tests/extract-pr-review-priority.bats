#!/usr/bin/env bats

load test_helper

SCRIPT="${BATS_TEST_DIRNAME}/../.github/scripts/extract-pr-review-priority.sh"

setup() {
  setup_tmp
  export REPO=core-nexus/autotune
  export PR_NUMBER=42
}
teardown() { teardown_tmp; }

@test "each valid priority round-trips from the PR comment" {
  for prio in NONE LOW MEDIUM HIGH CRITICAL; do
    setup_tmp
    stub_gh "echo \"some review text MAXIMUM_FIX_PRIORITY:${prio}\""
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "$(output_value priority)" = "${prio}" ]
    teardown_tmp
  done
}

@test "selects the last marker when a comment has several" {
  stub_gh 'printf "MAXIMUM_FIX_PRIORITY:LOW\ntext\nMAXIMUM_FIX_PRIORITY:CRITICAL\n"'
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(output_value priority)" = "CRITICAL" ]
}

@test "no marker yields NONE with a distinguishable warning" {
  stub_gh 'echo "looks good to me, no marker here"'
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(output_value priority)" = "NONE" ]
  [[ "${output}" == *"WARNING: no MAXIMUM_FIX_PRIORITY marker found"* ]]
}

@test "an empty gh response yields NONE" {
  stub_gh 'echo ""'
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(output_value priority)" = "NONE" ]
}

@test "a gh API failure yields NONE rather than crashing" {
  stub_gh 'echo "gh: API error" >&2; exit 1'
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(output_value priority)" = "NONE" ]
}

@test "an unrecognized priority token defaults to NONE" {
  stub_gh 'echo "MAXIMUM_FIX_PRIORITY:WHATEVER"'
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(output_value priority)" = "NONE" ]
  [[ "${output}" == *"unrecognized priority 'WHATEVER'"* ]]
}

@test "fails when PR_NUMBER is unset" {
  run env -u PR_NUMBER "${SCRIPT}"
  [ "${status}" -ne 0 ]
}
