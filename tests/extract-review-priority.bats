#!/usr/bin/env bats
#
# Tests for extract-review-priority.sh — the two-method cascade that pulls
# MAXIMUM_FIX_PRIORITY out of a local execution file (method 1) or, failing
# that, the most recent review issue via `gh` (method 2), defaulting to NONE.

load helpers

setup() {
  setup_env
  SCRIPT="${SCRIPTS_DIR}/extract-review-priority.sh"
  FIXTURES="${BATS_TEST_DIRNAME}/fixtures"
  export REVIEW_AREA=testing
  export REPO=core-nexus/autotune
  export GH_TOKEN=fake-token
}

@test "method 1: extracts the priority from a single-marker execution file" {
  EXECUTION_FILE="${FIXTURES}/execution-single-priority.txt" run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(output_value priority)" = "HIGH" ]
}

@test "method 1: with multiple markers, the last (self-authored) value wins" {
  # This fixture echoes the prompt (which lists ALL five priority values) and
  # then ends with the agent's own MAXIMUM_FIX_PRIORITY:MEDIUM line. tail -1
  # must select the trailing value, not one from the prompt text. (M2)
  EXECUTION_FILE="${FIXTURES}/execution-prompt-then-priority.txt" run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(output_value priority)" = "MEDIUM" ]
}

@test "method 2: falls back to gh issue list when EXECUTION_FILE is unset" {
  write_gh <<'EOF'
# Emulate `gh issue list --jq ...` returning the selected issue body.
echo "review(testing): findings ... MAXIMUM_FIX_PRIORITY:CRITICAL"
EOF
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(output_value priority)" = "CRITICAL" ]
}

@test "method 2: falls back when EXECUTION_FILE points at a missing path" {
  write_gh <<'EOF'
echo "review(testing): findings ... MAXIMUM_FIX_PRIORITY:LOW"
EOF
  EXECUTION_FILE="${BATS_TEST_TMPDIR}/does-not-exist.txt" run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(output_value priority)" = "LOW" ]
}

@test "execution file without a marker triggers the gh fallback" {
  write_gh <<'EOF'
echo "review(testing): findings ... MAXIMUM_FIX_PRIORITY:HIGH"
EOF
  EXECUTION_FILE="${FIXTURES}/execution-no-priority.txt" run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(output_value priority)" = "HIGH" ]
}

@test "defaults to NONE when neither the file nor gh yields a priority" {
  write_gh <<'EOF'
echo ""
EOF
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(output_value priority)" = "NONE" ]
}

@test "missing GITHUB_OUTPUT causes a non-zero exit" {
  run env -u GITHUB_OUTPUT "${SCRIPT}"
  [ "${status}" -ne 0 ]
}

@test "missing REVIEW_AREA causes a non-zero exit" {
  run env -u REVIEW_AREA "${SCRIPT}"
  [ "${status}" -ne 0 ]
}
