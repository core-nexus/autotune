# Shared test helpers for the Bats suite.
#
# Testing philosophy (see .github/review-prompts/testing.md):
#   - Exercise the REAL scripts under .github/workflows/scripts/.
#   - Mock ONLY the external boundary: the `gh` CLI. We stub it by placing an
#     executable named `gh` earlier on PATH; the scripts' own logic runs for real.

# Absolute path to the directory holding the scripts under test.
SCRIPTS_DIR="${BATS_TEST_DIRNAME}/../.github/workflows/scripts"
REPO_ROOT="${BATS_TEST_DIRNAME}/.."

# Create a per-test bin directory at the front of PATH for stubbing external
# commands, and a fresh GITHUB_OUTPUT file the scripts append to.
setup_env() {
  STUB_BIN="${BATS_TEST_TMPDIR}/bin"
  mkdir -p "${STUB_BIN}"
  PATH="${STUB_BIN}:${PATH}"

  export GITHUB_OUTPUT="${BATS_TEST_TMPDIR}/github_output"
  : > "${GITHUB_OUTPUT}"
}

# Install a `gh` stub. Reads the stub body from stdin so each test can define
# exactly how the external boundary behaves.
#
# Usage:
#   write_gh <<'EOF'
#   echo "some output"
#   EOF
write_gh() {
  cat > "${STUB_BIN}/gh"
  chmod +x "${STUB_BIN}/gh"
}

# Read the value written to GITHUB_OUTPUT for a given key (last wins).
output_value() {
  local key="$1"
  grep -oP "(?<=^${key}=).*" "${GITHUB_OUTPUT}" | tail -1
}
