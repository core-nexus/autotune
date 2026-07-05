#!/usr/bin/env bats
#
# Tests for extract-pr-review-priority.sh — pulls MAXIMUM_FIX_PRIORITY from the
# latest PR review comment via `gh api`, defaulting to NONE.

load helpers

setup() {
  setup_env
  SCRIPT="${SCRIPTS_DIR}/extract-pr-review-priority.sh"
  export REPO=core-nexus/autotune
  export PR_NUMBER=42
  export GH_TOKEN=fake-token
}

@test "extracts the priority from a matching comment body" {
  write_gh <<'EOF'
# Emulate `gh api .../comments --jq '... | last | .body'` returning the body
# of the most recent comment that contains the marker.
echo "Automated review complete. MAXIMUM_FIX_PRIORITY:HIGH"
EOF
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(output_value priority)" = "HIGH" ]
}

@test "defaults to NONE when no comment contains the marker" {
  write_gh <<'EOF'
echo ""
EOF
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(output_value priority)" = "NONE" ]
}

@test "defaults to NONE when the gh api call fails" {
  write_gh <<'EOF'
echo "gh: could not reach the API" >&2
exit 1
EOF
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(output_value priority)" = "NONE" ]
}

@test "missing PR_NUMBER causes a non-zero exit" {
  run env -u PR_NUMBER "${SCRIPT}"
  [ "${status}" -ne 0 ]
}
