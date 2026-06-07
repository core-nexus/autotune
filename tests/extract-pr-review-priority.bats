#!/usr/bin/env bats
#
# NOTE: This script lives under .github/workflows/, which the review/fix
# GitHub App cannot modify (no `workflows` permission). Tests here therefore
# pin only the behavior of the currently deployed script. The standardization
# fix (tighten the regex to the legal value set and take the LAST marker
# occurrence, mirroring extract-review-priority.sh) needs a maintainer with
# `workflows` permission; once applied, add the prose-vs-authoritative and
# illegal-value cases here too.

load test_helper

# bats already runs setup() (from test_helper) before each test; this only adds
# the env vars this script requires.
setup_pr_env() {
  export REPO=core-nexus/autotune PR_NUMBER=42
}

@test "reads the priority from the latest review comment" {
  setup_pr_env
  export STUB_GH_BODY=$'Review summary.\nMAXIMUM_FIX_PRIORITY:HIGH\n'
  run "${SCRIPTS_DIR}/extract-pr-review-priority.sh"
  [ "$status" -eq 0 ]
  [ "$(output_value priority)" = "HIGH" ]
}

@test "no matching comment yields NONE" {
  setup_pr_env
  export STUB_GH_BODY=""
  run "${SCRIPTS_DIR}/extract-pr-review-priority.sh"
  [ "$status" -eq 0 ]
  [ "$(output_value priority)" = "NONE" ]
}

@test "missing PR_NUMBER fails fast" {
  export REPO=core-nexus/autotune
  run "${SCRIPTS_DIR}/extract-pr-review-priority.sh"
  [ "$status" -ne 0 ]
}
