#!/usr/bin/env bats

load test_helper

SCRIPT="${BATS_TEST_DIRNAME}/../.github/scripts/extract-review-priority.sh"

setup() {
  setup_tmp
  export REVIEW_AREA=testing
  export REPO=core-nexus/autotune
}
teardown() { teardown_tmp; }

# Write an execution file containing the given body and point EXECUTION_FILE at it.
make_execution_file() {
  EXECUTION_FILE="${TMP_DIR}/execution.txt"
  printf '%s\n' "$1" > "${EXECUTION_FILE}"
  export EXECUTION_FILE
}

@test "each valid priority round-trips from the execution file" {
  for prio in NONE LOW MEDIUM HIGH CRITICAL; do
    setup_tmp
    make_execution_file "blah blah MAXIMUM_FIX_PRIORITY:${prio}"
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "$(output_value priority)" = "${prio}" ]
    teardown_tmp
  done
}

@test "execution file takes precedence over the issue-list fallback" {
  # gh would return HIGH, but the execution file says LOW — the file wins and
  # gh must not even be consulted.
  stub_gh 'echo "should-not-be-called: $*" >&2; exit 1'
  make_execution_file "MAXIMUM_FIX_PRIORITY:LOW"
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(output_value priority)" = "LOW" ]
}

@test "multiple markers in the execution file select the last one" {
  make_execution_file "$(printf 'MAXIMUM_FIX_PRIORITY:LOW\nsome text\nMAXIMUM_FIX_PRIORITY:HIGH\n')"
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(output_value priority)" = "HIGH" ]
}

@test "falls back to the issue list when no execution file is present" {
  stub_gh 'echo "## Findings ... MAXIMUM_FIX_PRIORITY:MEDIUM"'
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(output_value priority)" = "MEDIUM" ]
}

@test "missing marker deterministically yields NONE with a distinguishable warning" {
  stub_gh 'echo "a perfectly clean review with no marker"'
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(output_value priority)" = "NONE" ]
  [[ "${output}" == *"WARNING: no MAXIMUM_FIX_PRIORITY marker found"* ]]
}

@test "empty execution file falls through to the fallback then to NONE" {
  make_execution_file ""
  stub_gh 'echo ""'
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(output_value priority)" = "NONE" ]
}

@test "an unrecognized priority token is rejected and defaults to NONE" {
  make_execution_file "MAXIMUM_FIX_PRIORITY:BOGUS"
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(output_value priority)" = "NONE" ]
  [[ "${output}" == *"unrecognized priority 'BOGUS'"* ]]
}

@test "fails when a required env var is unset" {
  run env -u REVIEW_AREA "${SCRIPT}"
  [ "${status}" -ne 0 ]
}
