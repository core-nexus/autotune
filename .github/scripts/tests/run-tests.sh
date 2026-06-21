#!/usr/bin/env bash
set -uo pipefail

# Unit tests for the codebase-review helper scripts. These exercise the error
# handling that the error-handling review flagged: failed API calls must NOT be
# silently coerced into benign "NONE"/"skipped" outcomes, CI-trigger failures
# must be surfaced, and failure notifications must be durable + mark the run.
#
# A `gh` test double (gh-stub.sh) is placed first on PATH; per-test env vars
# drive its behavior. No network access required.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$(cd "${HERE}/.." && pwd)"

PASS=0
FAIL=0

# --- test harness ------------------------------------------------------------

WORKDIR=""
setup() {
  WORKDIR="$(mktemp -d)"
  # Build an isolated bin dir with our `gh` stub first on PATH.
  mkdir -p "${WORKDIR}/bin"
  cp "${HERE}/gh-stub.sh" "${WORKDIR}/bin/gh"
  chmod +x "${WORKDIR}/bin/gh"
  export PATH="${WORKDIR}/bin:${PATH}"
  export GH_STUB_LOG="${WORKDIR}/gh.log"
  : > "${GH_STUB_LOG}"
  export GITHUB_OUTPUT="${WORKDIR}/github_output"
  : > "${GITHUB_OUTPUT}"
  export GH_TOKEN="test-token"
  export REPO="o/r"
  # Reset stub controls between tests.
  unset GH_ISSUE_LIST_FAIL GH_ISSUE_LIST_OUT GH_API_FAIL GH_API_OUT \
        GH_WORKFLOW_MODE EXECUTION_FILE REVIEW_AREA PR_NUMBER BRANCH \
        WORKFLOWS RUN_URL DETERMINE_RESULT REVIEW_RESULT FIX_RESULT 2>/dev/null || true
}

teardown() {
  [[ -n "${WORKDIR}" && -d "${WORKDIR}" ]] && rm -rf "${WORKDIR}"
  WORKDIR=""
}

# assert_contains <name> <haystack> <needle>
assert_contains() {
  if [[ "$2" == *"$3"* ]]; then
    PASS=$((PASS + 1)); echo "  ok: $1"
  else
    FAIL=$((FAIL + 1)); echo "  FAIL: $1"; echo "    expected to contain: $3"; echo "    actual: $2"
  fi
}

# assert_not_contains <name> <haystack> <needle>
assert_not_contains() {
  if [[ "$2" != *"$3"* ]]; then
    PASS=$((PASS + 1)); echo "  ok: $1"
  else
    FAIL=$((FAIL + 1)); echo "  FAIL: $1"; echo "    expected NOT to contain: $3"; echo "    actual: $2"
  fi
}

# assert_eq <name> <actual> <expected>
assert_eq() {
  if [[ "$2" == "$3" ]]; then
    PASS=$((PASS + 1)); echo "  ok: $1"
  else
    FAIL=$((FAIL + 1)); echo "  FAIL: $1 (expected '$3', got '$2')"
  fi
}

# run_script <script> -> sets RC, OUT (combined stdout+stderr)
run_script() {
  set +e
  OUT="$(bash "${SCRIPTS}/$1" 2>&1)"
  RC=$?
  set -e
}

# ============================================================================
echo "extract-review-priority.sh"
# ============================================================================

# Method 1: priority read from the execution file (no network).
setup
export REVIEW_AREA="error-handling"
export EXECUTION_FILE="${WORKDIR}/exec.txt"
printf 'blah\nMAXIMUM_FIX_PRIORITY:HIGH\n' > "${EXECUTION_FILE}"
run_script extract-review-priority.sh
assert_eq "exec-file: exit 0" "${RC}" "0"
assert_contains "exec-file: writes HIGH" "$(cat "${GITHUB_OUTPUT}")" "priority=HIGH"
assert_eq "exec-file: no gh call" "$(cat "${GH_STUB_LOG}")" ""
teardown

# Method 2: fallback to issue list, marker present.
setup
export REVIEW_AREA="error-handling"
export GH_ISSUE_LIST_OUT=$'findings\nMAXIMUM_FIX_PRIORITY:MEDIUM\n'
run_script extract-review-priority.sh
assert_eq "issue-list: exit 0" "${RC}" "0"
assert_contains "issue-list: writes MEDIUM" "$(cat "${GITHUB_OUTPUT}")" "priority=MEDIUM"
teardown

# Method 2: API succeeds but no marker -> genuine NONE.
setup
export REVIEW_AREA="error-handling"
export GH_ISSUE_LIST_OUT="some body without a marker"
run_script extract-review-priority.sh
assert_eq "no-marker: exit 0" "${RC}" "0"
assert_contains "no-marker: writes NONE" "$(cat "${GITHUB_OUTPUT}")" "priority=NONE"
teardown

# Method 2: API call FAILS -> must fail loudly, NOT coerce to NONE.
setup
export REVIEW_AREA="error-handling"
export GH_ISSUE_LIST_FAIL="1"
run_script extract-review-priority.sh
assert_not_contains "api-fail: non-zero exit" "${RC}" "0"
assert_contains "api-fail: emits ::error::" "${OUT}" "::error::"
assert_not_contains "api-fail: does NOT write priority" "$(cat "${GITHUB_OUTPUT}")" "priority="
teardown

# ============================================================================
echo "extract-pr-review-priority.sh"
# ============================================================================

# Marker present in comments.
setup
export PR_NUMBER="7"
export GH_API_OUT="MAXIMUM_FIX_PRIORITY:LOW"
run_script extract-pr-review-priority.sh
assert_eq "pr: exit 0" "${RC}" "0"
assert_contains "pr: writes LOW" "$(cat "${GITHUB_OUTPUT}")" "priority=LOW"
teardown

# API succeeds but no marker -> NONE.
setup
export PR_NUMBER="7"
export GH_API_OUT=""
run_script extract-pr-review-priority.sh
assert_eq "pr-empty: exit 0" "${RC}" "0"
assert_contains "pr-empty: writes NONE" "$(cat "${GITHUB_OUTPUT}")" "priority=NONE"
teardown

# API FAILS -> fail loudly, no coercion to NONE.
setup
export PR_NUMBER="7"
export GH_API_FAIL="1"
run_script extract-pr-review-priority.sh
assert_not_contains "pr-fail: non-zero exit" "${RC}" "0"
assert_contains "pr-fail: emits ::error::" "${OUT}" "::error::"
assert_not_contains "pr-fail: does NOT write priority" "$(cat "${GITHUB_OUTPUT}")" "priority="
teardown

# ============================================================================
echo "trigger-ci-workflows.sh"
# ============================================================================

# All workflows trigger successfully.
setup
export BRANCH="review/error-handling-2026-06-21"
export WORKFLOWS="ci.yml"
export GH_WORKFLOW_MODE="success"
run_script trigger-ci-workflows.sh
assert_eq "trigger-ok: exit 0" "${RC}" "0"
assert_contains "trigger-ok: counts 1 triggered" "${OUT}" "1 triggered, 0 errored"
assert_not_contains "trigger-ok: no empty warning" "${OUT}" "No CI workflows were triggered"
teardown

# Workflow not found -> benign skip, but zero triggered must warn.
setup
export BRANCH="review/error-handling-2026-06-21"
export WORKFLOWS="ci.yml"
export GH_WORKFLOW_MODE="notfound"
run_script trigger-ci-workflows.sh
assert_eq "trigger-notfound: exit 0" "${RC}" "0"
assert_contains "trigger-notfound: labelled skip" "${OUT}" "Skipped: ci.yml"
assert_contains "trigger-notfound: warns none triggered" "${OUT}" "No CI workflows were triggered"
teardown

# Real error (auth) -> must surface as a warning, not a benign skip.
setup
export BRANCH="review/error-handling-2026-06-21"
export WORKFLOWS="ci.yml"
export GH_WORKFLOW_MODE="autherror"
run_script trigger-ci-workflows.sh
assert_eq "trigger-autherror: exit 0" "${RC}" "0"
assert_contains "trigger-autherror: warns on failure" "${OUT}" "::warning::Failed to trigger ci.yml"
assert_not_contains "trigger-autherror: not labelled skip" "${OUT}" "Skipped: ci.yml"
assert_contains "trigger-autherror: counts errored" "${OUT}" "0 triggered, 1 errored"
teardown

# ============================================================================
echo "notify-failure.sh"
# ============================================================================

# No existing tracking issue -> create one, and fail the run (exit 1).
setup
export RUN_URL="https://github.com/o/r/actions/runs/1"
export GH_ISSUE_LIST_OUT=""
export REVIEW_RESULT="failure"
run_script notify-failure.sh
assert_eq "notify-new: exit 1" "${RC}" "1"
assert_contains "notify-new: emits ::warning::" "${OUT}" "::warning::"
assert_contains "notify-new: creates issue" "$(cat "${GH_STUB_LOG}")" "gh issue create"
teardown

# Existing tracking issue -> comment on it, still fail the run.
setup
export RUN_URL="https://github.com/o/r/actions/runs/1"
export GH_ISSUE_LIST_OUT="42"
export REVIEW_RESULT="failure"
run_script notify-failure.sh
assert_eq "notify-existing: exit 1" "${RC}" "1"
assert_contains "notify-existing: comments on issue" "$(cat "${GH_STUB_LOG}")" "gh issue comment 42"
assert_not_contains "notify-existing: does not create" "$(cat "${GH_STUB_LOG}")" "gh issue create"
teardown

# ============================================================================
echo "notify-pr-failure.sh"
# ============================================================================

setup
export PR_NUMBER="13"
export RUN_URL="https://github.com/o/r/actions/runs/1"
export REVIEW_RESULT="failure"
export FIX_RESULT="skipped"
run_script notify-pr-failure.sh
assert_eq "notify-pr: exit 0" "${RC}" "0"
assert_contains "notify-pr: emits ::warning::" "${OUT}" "::warning::"
assert_contains "notify-pr: comments on PR" "$(cat "${GH_STUB_LOG}")" "gh pr comment 13"
teardown

# ============================================================================
echo ""
echo "RESULTS: ${PASS} passed, ${FAIL} failed"
[[ ${FAIL} -eq 0 ]]
