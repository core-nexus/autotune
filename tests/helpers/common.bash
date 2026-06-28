# Shared helpers for the shell-script test suite.
#
# Each script under .github/workflows/scripts/ has a sibling *.bats file here.
# These helpers drive the pure-logic paths with a temp GITHUB_OUTPUT file and,
# where a script shells out to `gh`, a fixture-backed `gh` stub so the parsing
# logic can be exercised without any network access.
#
# NOTE ON THE PATCH: the GitHub App that maintains this repo cannot commit
# changes under .github/workflows/ (it lacks the `workflows` permission), so the
# script fixes ship as tests/patches/scripts-fixes.patch. build_scripts_dir()
# below runs the suite against a throwaway copy of the scripts with that patch
# applied, so the tests exercise the fixed behavior whether or not the patch has
# yet been applied to the live tree. Once a maintainer applies the patch, the
# copy equals the live scripts and the tests keep passing unchanged.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURES_DIR="${REPO_ROOT}/tests/fixtures"
PATCH_FILE="${REPO_ROOT}/tests/patches/scripts-fixes.patch"

# build_scripts_dir copies the live .github tree into the per-test temp dir,
# applies the pending fix patch if it still applies (i.e. the live tree is not
# yet patched), and points SCRIPTS_DIR at the copy.
build_scripts_dir() {
  local root="${TMP_DIR}/root"
  mkdir -p "${root}"
  cp -r "${REPO_ROOT}/.github" "${root}/.github"
  SCRIPTS_DIR="${root}/.github/workflows/scripts"
  if [[ -f "${PATCH_FILE}" ]]; then
    if ( cd "${root}" && git apply --check "${PATCH_FILE}" >/dev/null 2>&1 ); then
      ( cd "${root}" && git apply "${PATCH_FILE}" )
    fi
  fi
}

# setup_tmp creates a per-test temp dir, an empty GITHUB_OUTPUT file, and the
# patched copy of the scripts under test.
setup_tmp() {
  TMP_DIR="$(mktemp -d)"
  GITHUB_OUTPUT="${TMP_DIR}/github_output"
  : > "${GITHUB_OUTPUT}"
  export GITHUB_OUTPUT
  build_scripts_dir
}

teardown_tmp() {
  if [[ -n "${TMP_DIR:-}" && -d "${TMP_DIR}" ]]; then
    rm -rf "${TMP_DIR}"
  fi
}

# stub_gh <fixture-file> installs a fake `gh` on PATH that prints the given
# fixture (ignoring all arguments and the script's own --jq filtering). The
# scripts only pipe gh's stdout into grep, so a stub that emits the already
# "selected" body faithfully exercises the grep/tail parsing under test.
stub_gh() {
  local body_file="$1"
  mkdir -p "${TMP_DIR}/bin"
  cat > "${TMP_DIR}/bin/gh" <<EOF
#!/usr/bin/env bash
cat "${body_file}"
EOF
  chmod +x "${TMP_DIR}/bin/gh"
  PATH="${TMP_DIR}/bin:${PATH}"
  export PATH
}

# stub_gh_exit <code> installs a fake `gh` that exits with <code> (ignoring all
# arguments). Used to drive the success/failure branches of scripts that call
# gh for its side effects rather than its stdout.
stub_gh_exit() {
  local code="$1"
  mkdir -p "${TMP_DIR}/bin"
  cat > "${TMP_DIR}/bin/gh" <<EOF
#!/usr/bin/env bash
exit ${code}
EOF
  chmod +x "${TMP_DIR}/bin/gh"
  PATH="${TMP_DIR}/bin:${PATH}"
  export PATH
}

# bats calls these automatically when a test file loads this helper.
setup() { setup_tmp; }
teardown() { teardown_tmp; }
