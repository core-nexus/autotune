#!/usr/bin/env bash
# Shared bats helpers.

# Resolve the repo root from the test file's location so tests can be
# run from any working directory (`bats test/`, `make test`, CI, etc.).
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
SCRIPTS_DIR="${REPO_ROOT}/scripts"
LIB_DIR="${SCRIPTS_DIR}/lib"
PROMPTS_DIR="${REPO_ROOT}/.github/review-prompts"

export TEST_DIR REPO_ROOT SCRIPTS_DIR LIB_DIR PROMPTS_DIR

# setup_tmp — create a per-test temp dir and point GITHUB_OUTPUT into it.
setup_tmp() {
  TMP_DIR="$(mktemp -d)"
  export TMP_DIR
  export GITHUB_OUTPUT="${TMP_DIR}/github_output"
  : > "${GITHUB_OUTPUT}"
}

teardown_tmp() {
  if [[ -n "${TMP_DIR:-}" && -d "${TMP_DIR}" ]]; then
    rm -rf "${TMP_DIR}"
  fi
}

# install_gh_stub PATH_TO_SHIM — prepend a directory containing a `gh`
# executable to PATH so the script under test calls the shim instead of
# the real gh CLI. The shim itself is a separate bash file the caller
# writes; this helper just wires up PATH.
install_gh_stub() {
  local shim_path="$1"
  local stub_dir
  stub_dir="${TMP_DIR}/bin"
  mkdir -p "${stub_dir}"
  cp "${shim_path}" "${stub_dir}/gh"
  chmod +x "${stub_dir}/gh"
  export PATH="${stub_dir}:${PATH}"
}

# write_gh_stub OUTPUT_PATH — emit a configurable gh stub that records
# its invocations to $TMP_DIR/gh_calls.log and returns a body/exit code
# controlled by env vars GH_STUB_BODY / GH_STUB_EXIT / GH_STUB_STDERR.
write_gh_stub() {
  local path="$1"
  cat > "${path}" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "${TMP_DIR}/gh_calls.log"
if [[ -n "${GH_STUB_STDERR:-}" ]]; then
  printf '%s\n' "${GH_STUB_STDERR}" >&2
fi
if [[ -n "${GH_STUB_BODY:-}" ]]; then
  printf '%s\n' "${GH_STUB_BODY}"
fi
exit "${GH_STUB_EXIT:-0}"
EOF
  chmod +x "${path}"
}

# assert_github_output_lines EXPECTED_COUNT — fail unless GITHUB_OUTPUT
# contains exactly EXPECTED_COUNT non-empty lines. Catches the multi-
# line write bug from the original extract-review-priority.sh:37-44.
assert_github_output_lines() {
  local expected="$1"
  local actual
  actual=$(grep -cve '^[[:space:]]*$' "${GITHUB_OUTPUT}")
  if [[ "${actual}" -ne "${expected}" ]]; then
    echo "expected ${expected} non-empty line(s) in GITHUB_OUTPUT, got ${actual}:" >&2
    cat -An "${GITHUB_OUTPUT}" >&2
    return 1
  fi
}

# get_output_value KEY — print the value of `KEY=...` from GITHUB_OUTPUT.
get_output_value() {
  local key="$1"
  awk -F= -v k="${key}" '$1 == k { sub(/^[^=]*=/, ""); print }' "${GITHUB_OUTPUT}"
}
