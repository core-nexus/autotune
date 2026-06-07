#!/usr/bin/env bats

load test_helper

# bats already runs setup() (from test_helper) before each test; this only adds
# the env vars this script requires.
setup_priority_env() {
  export REVIEW_AREA=testing REPO=core-nexus/autotune
}

@test "reads the priority from the execution file" {
  setup_priority_env
  printf 'some review prose\nMAXIMUM_FIX_PRIORITY:MEDIUM\n' >"${TEST_TMP}/exec.txt"
  export EXECUTION_FILE="${TEST_TMP}/exec.txt"
  run "${SCRIPTS_DIR}/extract-review-priority.sh"
  [ "$status" -eq 0 ]
  [ "$(output_value priority)" = "MEDIUM" ]
}

@test "the last marker occurrence wins" {
  setup_priority_env
  printf 'MAXIMUM_FIX_PRIORITY:LOW\nMAXIMUM_FIX_PRIORITY:HIGH\n' >"${TEST_TMP}/exec.txt"
  export EXECUTION_FILE="${TEST_TMP}/exec.txt"
  run "${SCRIPTS_DIR}/extract-review-priority.sh"
  [ "$status" -eq 0 ]
  [ "$(output_value priority)" = "HIGH" ]
}

@test "a marker mentioned in prose loses to the final authoritative line" {
  setup_priority_env
  printf 'We considered MAXIMUM_FIX_PRIORITY:HIGH but decided otherwise.\n\nMAXIMUM_FIX_PRIORITY:LOW\n' >"${TEST_TMP}/exec.txt"
  export EXECUTION_FILE="${TEST_TMP}/exec.txt"
  run "${SCRIPTS_DIR}/extract-review-priority.sh"
  [ "$status" -eq 0 ]
  [ "$(output_value priority)" = "LOW" ]
}

@test "falls back to gh issue list when no execution file is present" {
  setup_priority_env
  export STUB_GH_BODY=$'issue body text\nMAXIMUM_FIX_PRIORITY:MEDIUM\n'
  run "${SCRIPTS_DIR}/extract-review-priority.sh"
  [ "$status" -eq 0 ]
  [ "$(output_value priority)" = "MEDIUM" ]
}

@test "defaults to NONE when neither source yields a marker" {
  setup_priority_env
  export STUB_GH_BODY=""
  run "${SCRIPTS_DIR}/extract-review-priority.sh"
  [ "$status" -eq 0 ]
  [ "$(output_value priority)" = "NONE" ]
}

@test "missing required env fails fast" {
  setup_priority_env
  unset REVIEW_AREA
  run "${SCRIPTS_DIR}/extract-review-priority.sh"
  [ "$status" -ne 0 ]
}
