# Shared helpers for the bats suites.
#
# Each test runs a script under .github/scripts/ with a temp
# GITHUB_OUTPUT file and (where needed) a stubbed `gh` on PATH so no network
# call is ever made.

# Create an isolated temp dir per test and point GITHUB_OUTPUT at a file in it.
setup_tmp() {
  TMP_DIR="$(mktemp -d)"
  export GITHUB_OUTPUT="${TMP_DIR}/github_output"
  : > "${GITHUB_OUTPUT}"
}

teardown_tmp() {
  if [[ -n "${TMP_DIR:-}" && -d "${TMP_DIR}" ]]; then
    rm -rf "${TMP_DIR}"
  fi
  if [[ -n "${STUB_DIR:-}" && -d "${STUB_DIR}" ]]; then
    rm -rf "${STUB_DIR}"
  fi
  return 0
}

# Return the value written to GITHUB_OUTPUT for a given key (last wins).
output_value() {
  local key="$1"
  grep "^${key}=" "${GITHUB_OUTPUT}" | tail -1 | cut -d= -f2-
}

# Install a fake `gh` executable on PATH whose body is the given script text.
# Use within a test to control what the script's `gh` calls return.
stub_gh() {
  STUB_DIR="$(mktemp -d)"
  cat > "${STUB_DIR}/gh" <<EOF
#!/usr/bin/env bash
${1}
EOF
  chmod +x "${STUB_DIR}/gh"
  export PATH="${STUB_DIR}:${PATH}"
}
