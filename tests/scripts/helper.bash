# Shared bats helpers for the pipeline shell-script tests.
#
# These tests exercise the real scripts under
# .github/workflows/scripts/ end-to-end. The only thing stubbed is `gh`,
# which is a genuine external boundary (the GitHub CLI / network). All
# parsing, branching and JSON construction runs for real.

# Absolute path to the scripts directory, regardless of CWD.
SCRIPTS_DIR="$(cd "${BATS_TEST_DIRNAME}/../../.github/workflows/scripts" && pwd)"

# Create an isolated temp workspace for a single test and route GITHUB_OUTPUT
# into it. Call from setup().
setup_workspace() {
  TEST_TMP="$(mktemp -d)"
  export GITHUB_OUTPUT="${TEST_TMP}/github_output"
  : >"${GITHUB_OUTPUT}"
}

teardown_workspace() {
  [[ -n "${TEST_TMP:-}" ]] && rm -rf "${TEST_TMP}"
  [[ -n "${STUB_BIN:-}" ]] && rm -rf "${STUB_BIN}"
  return 0
}

# Install a fake `gh` on PATH whose behaviour is defined by the body passed in.
# The body is the shell to run when `gh` is invoked (with "$@" available).
stub_gh() {
  STUB_BIN="$(mktemp -d)"
  cat >"${STUB_BIN}/gh" <<EOF
#!/usr/bin/env bash
${1}
EOF
  chmod +x "${STUB_BIN}/gh"
  export PATH="${STUB_BIN}:${PATH}"
}

# Read the value written for a given key in GITHUB_OUTPUT (last occurrence).
output_value() {
  local key="$1"
  grep "^${key}=" "${GITHUB_OUTPUT}" | tail -1 | cut -d= -f2-
}

# Count how many lines in GITHUB_OUTPUT begin with "<key>=".
output_line_count() {
  local key="$1"
  grep -c "^${key}=" "${GITHUB_OUTPUT}"
}
