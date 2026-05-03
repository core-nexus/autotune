#!/usr/bin/env bash
# Tests for .github/workflows/scripts/extract-pr-review-priority.sh.
#
# `gh api ... --jq ...` is stubbed via PATH. The stub either prints a body
# (containing or not containing the sentinel) or exits non-zero to simulate
# an API failure.
#
# NOTE: The current script collapses any failure (no comments, no sentinel,
# gh api error) into priority=NONE. Tests named `..._defaults_none_today`
# pin that current behavior so it cannot regress, and are easy to flip
# when the script is updated to emit ::warning:: + priority=UNKNOWN on
# API errors (see the testing review issue for the proposed fix).

set -euo pipefail

SUT="${SCRIPTS_DIR}/extract-pr-review-priority.sh"

# $1: the body the fake gh should print (what `--jq` would have produced).
# $2: optional "FAIL" to simulate gh exiting non-zero.
# Echoes the value of `priority=` from the SUT's $GITHUB_OUTPUT.
_run_sut() {
  local jq_output="$1"
  local mode="${2:-OK}"

  local tmpdir
  tmpdir=$(make_tmpdir)
  local output_file="${tmpdir}/github_output"
  : > "${output_file}"

  local bin_dir="${tmpdir}/bin"
  mkdir -p "${bin_dir}"
  if [[ "${mode}" == "FAIL" ]]; then
    cat > "${bin_dir}/gh" <<'EOF'
#!/usr/bin/env bash
echo "fake gh: API error" >&2
exit 1
EOF
  else
    {
      echo '#!/usr/bin/env bash'
      echo 'cat <<'\''EOF_GH'\'''
      printf '%s' "${jq_output}"
      echo
      echo 'EOF_GH'
    } > "${bin_dir}/gh"
  fi
  chmod +x "${bin_dir}/gh"

  (
    export PATH="${bin_dir}:${PATH}"
    export GITHUB_OUTPUT="${output_file}"
    export REPO="example/repo"
    export PR_NUMBER="123"
    export GH_TOKEN="fake"
    bash "${SUT}" >/dev/null 2>&1 || true
  )

  read_output_priority "${output_file}"
  rm -rf "${tmpdir}"
}

test_parses_low_priority_from_comment_body() {
  local body
  body='## Review

findings...

MAXIMUM_FIX_PRIORITY:LOW'
  local out
  out=$(_run_sut "${body}")
  assert_eq "LOW" "${out}" "should parse LOW from comment body"
}

test_parses_high_priority() {
  local out
  out=$(_run_sut "MAXIMUM_FIX_PRIORITY:HIGH")
  assert_eq "HIGH" "${out}"
}

test_parses_medium_priority() {
  local out
  out=$(_run_sut "MAXIMUM_FIX_PRIORITY:MEDIUM")
  assert_eq "MEDIUM" "${out}"
}

test_no_sentinel_defaults_none_today() {
  # gh succeeded but the body is empty / no sentinel. Today this collapses
  # to NONE — a legitimate "no priority recorded" state.
  local out
  out=$(_run_sut "")
  assert_eq "NONE" "${out}" "current behavior: empty body collapses to NONE"
}

test_gh_failure_defaults_none_today() {
  # gh exits non-zero. Today this is silently treated like a clean review.
  # The proposed fix is to distinguish API failure from a clean review by
  # emitting UNKNOWN + ::warning::.
  local out
  out=$(_run_sut "irrelevant" "FAIL")
  assert_eq "NONE" "${out}" "current behavior: failed gh api collapses to NONE"
}
