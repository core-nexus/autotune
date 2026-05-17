#!/usr/bin/env bats
load helpers/common

setup_env() {
  export REVIEW_AREA=testing
  export REPO=owner/repo
  export GH_TOKEN=fake-token
}

@test "reads priority from the execution file" {
  setup_env
  printf 'some review text\nMAXIMUM_FIX_PRIORITY:HIGH\n' > "${TEST_TMP}/exec.md"
  export EXECUTION_FILE="${TEST_TMP}/exec.md"
  run bash "${SCRIPTS_DIR}/extract-review-priority.sh"
  [ "$status" -eq 0 ]
  [ "$(output_value priority)" = "HIGH" ]
}

@test "takes the last priority when the execution file has several" {
  setup_env
  printf 'MAXIMUM_FIX_PRIORITY:LOW\nMAXIMUM_FIX_PRIORITY:MEDIUM\n' > "${TEST_TMP}/exec.md"
  export EXECUTION_FILE="${TEST_TMP}/exec.md"
  run bash "${SCRIPTS_DIR}/extract-review-priority.sh"
  [ "$status" -eq 0 ]
  [ "$(output_value priority)" = "MEDIUM" ]
}

@test "falls back to gh issue list when no execution file is present" {
  setup_env
  export GH_STUB_STDOUT='## findings

MAXIMUM_FIX_PRIORITY:MEDIUM
'
  run bash "${SCRIPTS_DIR}/extract-review-priority.sh"
  [ "$status" -eq 0 ]
  [ "$(output_value priority)" = "MEDIUM" ]
}

@test "defaults to NONE when nothing yields a priority" {
  setup_env
  export GH_STUB_STDOUT=''
  run bash "${SCRIPTS_DIR}/extract-review-priority.sh"
  [ "$status" -eq 0 ]
  [ "$(output_value priority)" = "NONE" ]
  [ "$(output_line_count)" -eq 1 ]
}
