#!/usr/bin/env bash
# Tests for .github/workflows/scripts/extract-review-priority.sh.
#
# These tests exercise the real script as a subprocess. The only mock is
# `gh` itself (the external boundary): each test installs a stub `gh`
# binary into a per-test tempdir and prepends it to PATH.
#
# NOTE: The script today defaults to priority=NONE on parse failure
# (silently swallowing missing-input from a legitimate clean review).
# These tests document that current behavior so it cannot silently
# regress, and they are written to be easy to flip when the script is
# updated to emit ::warning:: + priority=UNKNOWN on parse failure (see
# the testing review issue for the proposed fix). Tests named
# `..._defaults_none_today` cover the failure-mode behavior that is
# expected to change.

set -euo pipefail

SUT="${SCRIPTS_DIR}/extract-review-priority.sh"

# $1: execution_file path (or empty for "no execution file").
# $2: body to return from `gh issue list` (or "FAIL" to make gh exit non-zero).
# Echoes the value of `priority=` from the SUT's $GITHUB_OUTPUT.
_run_sut() {
  local execution_file="$1"
  local gh_body="$2"

  local tmpdir
  tmpdir=$(make_tmpdir)
  local output_file="${tmpdir}/github_output"
  : > "${output_file}"

  local bin_dir="${tmpdir}/bin"
  mkdir -p "${bin_dir}"
  if [[ "${gh_body}" == "FAIL" ]]; then
    cat > "${bin_dir}/gh" <<'EOF'
#!/usr/bin/env bash
echo "fake gh: simulated network failure" >&2
exit 1
EOF
  else
    {
      echo '#!/usr/bin/env bash'
      echo 'cat <<'\''EOF_GH'\'''
      printf '%s\n' "${gh_body}"
      echo 'EOF_GH'
    } > "${bin_dir}/gh"
  fi
  chmod +x "${bin_dir}/gh"

  (
    export PATH="${bin_dir}:${PATH}"
    export GITHUB_OUTPUT="${output_file}"
    export REVIEW_AREA="testing"
    export REPO="example/repo"
    export GH_TOKEN="fake"
    if [[ -n "${execution_file}" ]]; then
      export EXECUTION_FILE="${execution_file}"
    fi
    bash "${SUT}" >/dev/null 2>&1 || true
  )

  read_output_priority "${output_file}"
  rm -rf "${tmpdir}"
}

test_execution_file_high() {
  local tmpdir
  tmpdir=$(make_tmpdir)
  local exec_file="${tmpdir}/exec.txt"
  cat > "${exec_file}" <<'EOF'
some preamble
findings...
MAXIMUM_FIX_PRIORITY:HIGH
EOF
  local out
  out=$(_run_sut "${exec_file}" "ignored")
  rm -rf "${tmpdir}"
  assert_eq "HIGH" "${out}" "execution file with HIGH should yield HIGH"
}

test_execution_file_picks_last_when_multiple() {
  # Multiple sentinels can appear in the transcript (an earlier draft, then
  # the final value). The script must take the *last* occurrence.
  local tmpdir
  tmpdir=$(make_tmpdir)
  local exec_file="${tmpdir}/exec.txt"
  cat > "${exec_file}" <<'EOF'
draft 1: MAXIMUM_FIX_PRIORITY:LOW
revised: MAXIMUM_FIX_PRIORITY:MEDIUM
final:   MAXIMUM_FIX_PRIORITY:HIGH
EOF
  local out
  out=$(_run_sut "${exec_file}" "ignored")
  rm -rf "${tmpdir}"
  assert_eq "HIGH" "${out}" "should pick the last sentinel in the file"
}

test_execution_file_with_none_yields_none() {
  local tmpdir
  tmpdir=$(make_tmpdir)
  local exec_file="${tmpdir}/exec.txt"
  cat > "${exec_file}" <<'EOF'
clean review.
MAXIMUM_FIX_PRIORITY:NONE
EOF
  local out
  out=$(_run_sut "${exec_file}" "ignored")
  rm -rf "${tmpdir}"
  assert_eq "NONE" "${out}" "execution file with NONE should yield NONE"
}

test_execution_file_with_medium_yields_medium() {
  local tmpdir
  tmpdir=$(make_tmpdir)
  local exec_file="${tmpdir}/exec.txt"
  cat > "${exec_file}" <<'EOF'
MAXIMUM_FIX_PRIORITY:MEDIUM
EOF
  local out
  out=$(_run_sut "${exec_file}" "ignored")
  rm -rf "${tmpdir}"
  assert_eq "MEDIUM" "${out}"
}

test_no_execution_file_falls_back_to_gh() {
  # No execution file. gh returns an issue body containing the sentinel.
  local body
  body='## Findings
some text
MAXIMUM_FIX_PRIORITY:LOW'
  local out
  out=$(_run_sut "" "${body}")
  assert_eq "LOW" "${out}" "fallback to gh should parse the sentinel from the issue body"
}

test_execution_file_without_sentinel_defaults_none_today() {
  # Execution file exists but contains no sentinel. The current script
  # silently falls through to NONE, so a parse failure is indistinguishable
  # from a clean review. The PR proposes changing this to UNKNOWN +
  # ::warning::; until that lands, this test asserts current behavior.
  local tmpdir
  tmpdir=$(make_tmpdir)
  local exec_file="${tmpdir}/exec.txt"
  cat > "${exec_file}" <<'EOF'
no sentinel here, just some text
EOF
  local out
  out=$(_run_sut "${exec_file}" "")
  rm -rf "${tmpdir}"
  assert_eq "NONE" "${out}" "current behavior: missing sentinel defaults to NONE"
}

test_no_execution_file_gh_empty_defaults_none_today() {
  # gh returns an empty body. Same silent NONE today.
  local out
  out=$(_run_sut "" "")
  assert_eq "NONE" "${out}" "current behavior: empty gh response defaults to NONE"
}

test_gh_failure_defaults_none_today() {
  # gh exits non-zero (network/rate-limit/auth). Today the script swallows
  # this and emits NONE.
  local out
  out=$(_run_sut "" "FAIL")
  assert_eq "NONE" "${out}" "current behavior: failed gh defaults to NONE"
}
