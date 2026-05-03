#!/usr/bin/env bash
# Shared test helpers for the shell-script tests in this directory.
#
# Each test file sources this helper, defines `test_*` functions, and ends
# with `_run_all_tests` (called by run-tests.sh). Tests use `assert_*`
# helpers that return non-zero on failure (and trigger function exit
# under `set -e`).

# Resolve directories relative to this helper file, so tests work from any cwd.
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${TESTS_ROOT}/.." && pwd)"
SCRIPTS_DIR="${REPO_ROOT}/.github/workflows/scripts"
WORKFLOWS_DIR="${REPO_ROOT}/.github/workflows"
GITHUB_DIR="${REPO_ROOT}/.github"
export TESTS_DIR TESTS_ROOT REPO_ROOT SCRIPTS_DIR WORKFLOWS_DIR GITHUB_DIR

PASS_COUNT=0
FAIL_COUNT=0
FAILED_TESTS=()

assert_eq() {
  local expected="$1"
  local actual="$2"
  local msg="${3:-values differ}"
  if [[ "${expected}" != "${actual}" ]]; then
    printf '    ASSERT FAIL: %s\n      expected: %q\n      actual:   %q\n' \
      "${msg}" "${expected}" "${actual}" >&2
    return 1
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local msg="${3:-substring not found}"
  if [[ "${haystack}" != *"${needle}"* ]]; then
    printf '    ASSERT FAIL: %s\n      needle:   %q\n      haystack: %q\n' \
      "${msg}" "${needle}" "${haystack}" >&2
    return 1
  fi
}

# Make a fresh tempdir for the duration of one test. Caller is responsible
# for `rm -rf`'ing it (typically via a trap or at the end of the test).
make_tmpdir() {
  mktemp -d
}

# Read the value of `priority=` from a fake $GITHUB_OUTPUT file.
read_output_priority() {
  local output_file="$1"
  grep -oP '(?<=^priority=).*' "${output_file}" | tail -1 || true
}

_run_all_tests() {
  local funcs
  mapfile -t funcs < <(declare -F | awk '$3 ~ /^test_/ {print $3}')
  if (( ${#funcs[@]} == 0 )); then
    echo "  (no tests defined in this file)"
    return 0
  fi
  for fn in "${funcs[@]}"; do
    printf '  - %s ... ' "${fn}"
    local rc=0
    local out
    out=$("${fn}" 2>&1) || rc=$?
    if (( rc == 0 )); then
      PASS_COUNT=$((PASS_COUNT + 1))
      printf 'PASS\n'
    else
      FAIL_COUNT=$((FAIL_COUNT + 1))
      FAILED_TESTS+=("${fn}")
      printf 'FAIL (rc=%d)\n' "${rc}"
      printf '%s\n' "${out}" | sed 's/^/      /'
    fi
  done
}

# Print a per-file summary and exit non-zero if any test failed.
_print_summary_and_exit() {
  printf '\nTests run: %d, passed: %d, failed: %d\n' \
    "$((PASS_COUNT + FAIL_COUNT))" "${PASS_COUNT}" "${FAIL_COUNT}"
  if (( FAIL_COUNT > 0 )); then
    printf 'Failed tests:\n'
    for t in "${FAILED_TESTS[@]}"; do
      printf '  - %s\n' "${t}"
    done
    exit 1
  fi
}
