#!/usr/bin/env bats
#
# Tests for .github/workflows/scripts/trigger-ci-workflows.sh
# Covers the WORKFLOWS word-splitting loop and the per-workflow skip-on-failure
# branch, using a gh stub whose exit code is controlled by the test.

load helpers/common

setup() {
  setup_tmp
  export REPO=core-nexus/autotune BRANCH=review/testing-2026-06-28
  export WORKFLOWS="alpha.yml beta.yml"
}

@test "iterates every workflow listed in WORKFLOWS" {
  stub_gh_exit 0
  run "${SCRIPTS_DIR}/trigger-ci-workflows.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"-> alpha.yml"* ]]
  [[ "$output" == *"-> beta.yml"* ]]
  [[ "$output" != *"Skipped"* ]]
}

@test "reports a skip (without failing) when a workflow is not dispatchable" {
  stub_gh_exit 1
  run "${SCRIPTS_DIR}/trigger-ci-workflows.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Skipped: alpha.yml"* ]]
  [[ "$output" == *"Skipped: beta.yml"* ]]
}
