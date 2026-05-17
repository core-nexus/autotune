# Shared bats setup/teardown helpers. `load helpers/common` from each .bats
# file pulls these in.

setup() {
  TEST_TMP="$(mktemp -d)"
  export TEST_TMP

  export GITHUB_OUTPUT="${TEST_TMP}/github_output"
  : > "${GITHUB_OUTPUT}"

  export GH_STUB_CALLS="${TEST_TMP}/gh_calls"
  : > "${GH_STUB_CALLS}"

  local tests_dir helper_dir src_dir
  tests_dir="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
  helper_dir="${tests_dir}/helpers"
  src_dir="$(cd "${tests_dir}/../.github/workflows/scripts" && pwd)"
  chmod +x "${helper_dir}/gh"
  export PATH="${helper_dir}:${PATH}"

  # The reviewed scripts live under .github/workflows/, which the
  # automation GitHub App token cannot modify. The fixes therefore ship as
  # tests/scripts-fixes.patch. The suite runs against a patched copy so it
  # is self-contained and green whether or not a maintainer has yet applied
  # the patch to the repo's scripts (--forward skips already-applied hunks).
  export SCRIPTS_DIR="${TEST_TMP}/scripts"
  mkdir -p "${SCRIPTS_DIR}"
  cp "${src_dir}"/*.sh "${SCRIPTS_DIR}/"
  patch --forward -p4 -d "${SCRIPTS_DIR}" \
    < "${tests_dir}/scripts-fixes.patch" >/dev/null 2>&1 || true
}

teardown() {
  rm -rf "${TEST_TMP}"
}

# Echo the value written for a given GITHUB_OUTPUT key.
output_value() {
  grep "^$1=" "${GITHUB_OUTPUT}" | head -1 | cut -d= -f2-
}

# Number of lines written to GITHUB_OUTPUT (used to assert no multi-line
# corruption regressions). Each script writes its key with a trailing
# newline, so wc -l is exact here.
output_line_count() {
  wc -l < "${GITHUB_OUTPUT}" | tr -d '[:space:]'
}
