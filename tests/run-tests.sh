#!/usr/bin/env bash
# Run every *_test.sh file under tests/scripts/.
#
# Each test file is sourced into its own subshell so they cannot contaminate
# each other's environment. Subshell prints a per-file summary; this script
# aggregates exit codes and prints an overall result.
#
# Usage:
#   bash tests/run-tests.sh

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS="${ROOT}/scripts/_helpers.sh"

if [[ ! -f "${HELPERS}" ]]; then
  echo "Test helpers missing: ${HELPERS}" >&2
  exit 1
fi

shopt -s nullglob
test_files=("${ROOT}"/scripts/*_test.sh)
shopt -u nullglob

if (( ${#test_files[@]} == 0 )); then
  echo "No test files found in ${ROOT}/scripts" >&2
  exit 1
fi

overall_rc=0
files_passed=0
files_failed=0

for tf in "${test_files[@]}"; do
  printf '\n=== %s ===\n' "$(basename "${tf}")"
  if (
    # shellcheck source=scripts/_helpers.sh
    source "${HELPERS}"
    # shellcheck disable=SC1090
    source "${tf}"
    _run_all_tests
    _print_summary_and_exit
  ); then
    files_passed=$((files_passed + 1))
  else
    files_failed=$((files_failed + 1))
    overall_rc=1
  fi
done

printf '\n========================================\n'
printf 'Test files passed: %d\n' "${files_passed}"
printf 'Test files failed: %d\n' "${files_failed}"
if (( overall_rc != 0 )); then
  printf 'Overall: FAILED\n' >&2
  exit 1
fi
printf 'Overall: PASSED\n'
