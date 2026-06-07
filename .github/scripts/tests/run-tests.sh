#!/usr/bin/env bash
set -euo pipefail

# Self-contained tests for the error-handling behavior of the review helper
# scripts. No external test framework: each case stubs `gh` on PATH and asserts
# on exit code + the `priority=` line written to GITHUB_OUTPUT.
#
# Run: .github/workflows/scripts/tests/run-tests.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

# Create a temp dir holding a stub `gh` whose behavior is driven by env vars.
STUB_DIR="$(mktemp -d)"
trap 'rm -rf "${STUB_DIR}"' EXIT

cat > "${STUB_DIR}/gh" <<'STUB'
#!/usr/bin/env bash
# Stub gh. Behavior controlled by:
#   GH_STUB_MODE = fail | ok
#   GH_STUB_OUT  = stdout to emit when mode=ok
#   GH_STUB_ERR  = stderr to emit when mode=fail
set -uo pipefail
if [[ "${GH_STUB_MODE:-ok}" == "fail" ]]; then
  printf '%s\n' "${GH_STUB_ERR:-gh: API error}" >&2
  exit 1
fi
printf '%s' "${GH_STUB_OUT:-}"
exit 0
STUB
chmod +x "${STUB_DIR}/gh"

run_case() {
  # run_case <name> <expected_exit> <expected_priority|--> <script> [args...]
  local name="$1" exp_exit="$2" exp_priority="$3" script="$4"; shift 4
  local out_file actual_exit actual_priority
  out_file="$(mktemp)"

  set +e
  GITHUB_OUTPUT="${out_file}" PATH="${STUB_DIR}:${PATH}" \
    "${SCRIPT_DIR}/${script}" "$@" >/dev/null 2>&1
  actual_exit=$?
  set -e

  actual_priority="$(grep -oP '(?<=^priority=).*' "${out_file}" | tail -1 || true)"
  rm -f "${out_file}"

  local ok=1
  [[ "${actual_exit}" == "${exp_exit}" ]] || ok=0
  if [[ "${exp_priority}" != "--" ]]; then
    [[ "${actual_priority}" == "${exp_priority}" ]] || ok=0
  fi

  if [[ "${ok}" == "1" ]]; then
    echo "PASS: ${name}"
    PASS=$((PASS + 1))
  else
    echo "FAIL: ${name} (exit: got ${actual_exit} want ${exp_exit}; priority: got '${actual_priority}' want '${exp_priority}')"
    FAIL=$((FAIL + 1))
  fi
}

echo "== extract-pr-review-priority.sh =="

GH_STUB_MODE=ok GH_STUB_OUT="here MAXIMUM_FIX_PRIORITY:HIGH end" \
REPO="o/r" PR_NUMBER="1" GH_TOKEN="t" \
  run_case "PR: marker present -> extracted" 0 HIGH extract-pr-review-priority.sh

GH_STUB_MODE=ok GH_STUB_OUT="no marker in this body" \
REPO="o/r" PR_NUMBER="1" GH_TOKEN="t" \
  run_case "PR: API ok, no marker -> NONE" 0 NONE extract-pr-review-priority.sh

GH_STUB_MODE=fail GH_STUB_ERR="HTTP 401 Bad credentials" \
REPO="o/r" PR_NUMBER="1" GH_TOKEN="t" \
  run_case "PR: API failure -> EXTRACT_FAILED + exit 1" 1 EXTRACT_FAILED extract-pr-review-priority.sh

# Missing GH_TOKEN must fail fast (the ${VAR:?} guard), not silently degrade.
GH_STUB_MODE=ok REPO="o/r" PR_NUMBER="1" GH_TOKEN="" \
  run_case "PR: missing GH_TOKEN -> fails fast" 1 -- extract-pr-review-priority.sh

echo "== extract-review-priority.sh =="

EXEC_FILE="$(mktemp)"
printf 'blah MAXIMUM_FIX_PRIORITY:MEDIUM\n' > "${EXEC_FILE}"
GH_STUB_MODE=fail EXECUTION_FILE="${EXEC_FILE}" \
REPO="o/r" REVIEW_AREA="error-handling" GH_TOKEN="t" \
  run_case "issue: execution file marker wins (no API)" 0 MEDIUM extract-review-priority.sh
rm -f "${EXEC_FILE}"

GH_STUB_MODE=fail GH_STUB_ERR="HTTP 503" EXECUTION_FILE="/nonexistent" \
REPO="o/r" REVIEW_AREA="error-handling" GH_TOKEN="t" \
  run_case "issue: fallback API failure -> EXTRACT_FAILED + exit 1" 1 EXTRACT_FAILED extract-review-priority.sh

GH_STUB_MODE=ok GH_STUB_OUT="body MAXIMUM_FIX_PRIORITY:LOW" EXECUTION_FILE="/nonexistent" \
REPO="o/r" REVIEW_AREA="error-handling" GH_TOKEN="t" \
  run_case "issue: fallback API ok, marker -> extracted" 0 LOW extract-review-priority.sh

GH_STUB_MODE=ok GH_STUB_OUT="" EXECUTION_FILE="/nonexistent" \
REPO="o/r" REVIEW_AREA="error-handling" GH_TOKEN="t" \
  run_case "issue: fallback API ok, no marker -> NONE" 0 NONE extract-review-priority.sh

echo "== trigger-ci-workflows.sh =="
# trigger script does not write GITHUB_OUTPUT; assert on exit code only ("--").

GH_STUB_MODE=fail GH_STUB_ERR="could not find any workflows named ci.yml" \
GH_TOKEN="t" REPO="o/r" BRANCH="b" WORKFLOWS="ci.yml" \
  run_case "trigger: all not-found -> warn, exit 0" 0 -- trigger-ci-workflows.sh

GH_STUB_MODE=fail GH_STUB_ERR="HTTP 403 Resource not accessible" \
GH_TOKEN="t" REPO="o/r" BRANCH="b" WORKFLOWS="ci.yml" \
  run_case "trigger: real error, none triggered -> exit 1" 1 -- trigger-ci-workflows.sh

GH_STUB_MODE=ok GH_STUB_OUT="" \
GH_TOKEN="t" REPO="o/r" BRANCH="b" WORKFLOWS="ci.yml" \
  run_case "trigger: at least one success -> exit 0" 0 -- trigger-ci-workflows.sh

echo
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "${FAIL}" -eq 0 ]]
