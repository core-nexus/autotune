# Shared setup for the shell-script bats suite.
#
# Each test runs with:
#   - GITHUB_OUTPUT pointing at a fresh temp file (the scripts append to it)
#   - the gh stub (tests/stubs/gh) first on PATH
#   - SCRIPTS_DIR pointing at the scripts under test

setup() {
  TEST_TMP="$(mktemp -d)"
  export TEST_TMP

  GITHUB_OUTPUT="${TEST_TMP}/github_output"
  : >"${GITHUB_OUTPUT}"
  export GITHUB_OUTPUT

  SCRIPTS_DIR="${BATS_TEST_DIRNAME}/../.github/workflows/scripts"
  export SCRIPTS_DIR

  chmod +x "${BATS_TEST_DIRNAME}/stubs/gh" 2>/dev/null || true
  PATH="${BATS_TEST_DIRNAME}/stubs:${PATH}"
  export PATH
}

teardown() {
  rm -rf "${TEST_TMP}"
}

# Return the value written to GITHUB_OUTPUT for the given key (last wins).
output_value() {
  local key="$1"
  grep -oP "^${key}=\K.*" "${GITHUB_OUTPUT}" | tail -1
}
