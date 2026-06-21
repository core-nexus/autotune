#!/usr/bin/env bats
#
# Black-box tests for extract-review-priority.sh — the script whose `priority`
# output is the single gate deciding whether the fix stage edits code and opens
# a PR (see the `fix` job `if:` in codebase-review.yml).

load test_helper

SCRIPT="${SCRIPTS_DIR}/extract-review-priority.sh"

setup() { OUT="$(mktemp)"; }
teardown() {
  rm -f "${OUT}"
  [[ -n "${EXEC_FILE:-}" ]] && rm -f "${EXEC_FILE}"
  teardown_gh_stub
  return 0
}

# Run the script with a given execution-file body (Method 1 path).
run_with_exec_body() {
  EXEC_FILE="$(make_tmpfile "$1")"
  GITHUB_OUTPUT="${OUT}" REVIEW_AREA="testing" REPO="o/r" EXECUTION_FILE="${EXEC_FILE}" \
    run bash "${SCRIPT}"
}

# ─── Method 1: execution file parsing ──────────────────────────────────────

@test "execution file: canonical trailing token is emitted" {
  run_with_exec_body 'Findings summary...

MAXIMUM_FIX_PRIORITY:MEDIUM'
  [ "$status" -eq 0 ]
  [ "$(output_priority "${OUT}")" = "MEDIUM" ]
}

@test "execution file: body enumerating all values then ending with one — tail -1 wins" {
  # The review prompt itself lists every value; the real assessment is the LAST
  # occurrence. A regression in the tail -1 selection would pick a wrong value
  # and silently mis-gate the fix stage.
  run_with_exec_body 'Values:
MAXIMUM_FIX_PRIORITY:NONE
MAXIMUM_FIX_PRIORITY:XLOW
MAXIMUM_FIX_PRIORITY:LOW
MAXIMUM_FIX_PRIORITY:MEDIUM
MAXIMUM_FIX_PRIORITY:HIGH

Final assessment:

MAXIMUM_FIX_PRIORITY:LOW'
  [ "$status" -eq 0 ]
  [ "$(output_priority "${OUT}")" = "LOW" ]
}

@test "execution file: surrounding uppercase tokens are not mistaken for the value" {
  run_with_exec_body 'A CRITICAL AUTH BUG was found in MODULE X.
MAXIMUM_FIX_PRIORITY:HIGH'
  [ "$status" -eq 0 ]
  [ "$(output_priority "${OUT}")" = "HIGH" ]
}

@test "execution file: each canonical value round-trips" {
  for v in HIGH MEDIUM LOW XLOW NONE; do
    OUT="$(mktemp)"
    run_with_exec_body "MAXIMUM_FIX_PRIORITY:${v}"
    [ "$status" -eq 0 ]
    [ "$(output_priority "${OUT}")" = "$v" ]
    rm -f "${OUT}" "${EXEC_FILE}"
  done
}

@test "execution file: missing token falls back to gh, then defaults to NONE" {
  use_gh_stub
  export GH_STUB_OUT="$(make_tmpfile '')"   # gh finds no matching issue
  run_with_exec_body 'Findings but no priority line at all.'
  [ "$status" -eq 0 ]
  [ "$(output_priority "${OUT}")" = "NONE" ]
}

@test "execution file: empty file falls back to gh" {
  use_gh_stub
  export GH_STUB_OUT="$(make_tmpfile 'issue body
MAXIMUM_FIX_PRIORITY:HIGH')"
  run_with_exec_body ''
  [ "$status" -eq 0 ]
  [ "$(output_priority "${OUT}")" = "HIGH" ]
}

# ─── Method 2: gh issue list fallback ──────────────────────────────────────

@test "no execution file: parses priority from gh issue body" {
  use_gh_stub
  export GH_STUB_OUT="$(make_tmpfile 'recent issue
MAXIMUM_FIX_PRIORITY:MEDIUM')"
  GITHUB_OUTPUT="${OUT}" REVIEW_AREA="security" REPO="o/r" run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(output_priority "${OUT}")" = "MEDIUM" ]
}

@test "no execution file: empty gh result defaults to NONE" {
  use_gh_stub
  export GH_STUB_OUT="$(make_tmpfile '')"
  GITHUB_OUTPUT="${OUT}" REVIEW_AREA="security" REPO="o/r" run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(output_priority "${OUT}")" = "NONE" ]
}

@test "no execution file: gh failure is tolerated and defaults to NONE" {
  use_gh_stub
  export GH_STUB_RC=1
  GITHUB_OUTPUT="${OUT}" REVIEW_AREA="security" REPO="o/r" run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(output_priority "${OUT}")" = "NONE" ]
}

@test "no execution file: gh issue body with extra uppercase only extracts the token" {
  use_gh_stub
  export GH_STUB_OUT="$(make_tmpfile 'This issue mentions SECURITY and TODO items.
MAXIMUM_FIX_PRIORITY:LOW')"
  GITHUB_OUTPUT="${OUT}" REVIEW_AREA="security" REPO="o/r" run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(output_priority "${OUT}")" = "LOW" ]
}

# ─── Required env var guards ───────────────────────────────────────────────

@test "aborts when REVIEW_AREA is unset" {
  GITHUB_OUTPUT="${OUT}" REPO="o/r" run bash "${SCRIPT}"
  [ "$status" -ne 0 ]
}

@test "aborts when GITHUB_OUTPUT is unset" {
  run env -u GITHUB_OUTPUT REVIEW_AREA="testing" REPO="o/r" bash "${SCRIPT}"
  [ "$status" -ne 0 ]
}
