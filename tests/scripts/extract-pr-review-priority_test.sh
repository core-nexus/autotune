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

test_multiple_sentinels_takes_first_today() {
  # NEW MEDIUM finding from review issue 29 (testing — 2026-05-10):
  # extract-pr-review-priority.sh lacks `| tail -1`, so when a comment
  # body contains multiple MAXIMUM_FIX_PRIORITY: lines (e.g., the model
  # quoted the legend before its final answer), the resulting multi-line
  # value is written to GITHUB_OUTPUT; GitHub Actions parses that
  # line-by-line, so the FIRST match wins.
  #
  # extract-review-priority.sh (the codebase-review path) explicitly
  # uses `| tail -1` to make the LAST match win — the model's chosen
  # value. The two scripts disagree on a load-bearing rule.
  #
  # This test pins the current (buggy) "first wins" behavior on the PR
  # path so the regression cannot drift further. After the deferred fix
  # in the PR body is applied, flip the expected value to "MEDIUM" (the
  # last match — the model's actual chosen severity).
  local body
  body='Reviewing the diff…

Possible severities, for reference:
- MAXIMUM_FIX_PRIORITY:NONE
- MAXIMUM_FIX_PRIORITY:LOW
- MAXIMUM_FIX_PRIORITY:HIGH

Final answer for this PR:
MAXIMUM_FIX_PRIORITY:MEDIUM'
  local out
  out=$(_run_sut "${body}")
  assert_eq "NONE" "${out}" \
    "current behavior: PR script picks the FIRST sentinel; codebase-review script picks the LAST. See review issue 29 (MEDIUM)."
}

test_multiple_sentinels_codebase_review_uses_tail() {
  # Companion to the test above: the codebase-review extractor uses
  # `tail -1`, so the same input above produces the LAST value
  # ("MEDIUM"). This test pins the desired behavior (last wins) for the
  # script that already implements it, so a future refactor that drops
  # `tail -1` from extract-review-priority.sh is caught immediately.
  local exec_file
  exec_file=$(mktemp)
  cat > "${exec_file}" <<'EOF'
Possible severities, for reference:
- MAXIMUM_FIX_PRIORITY:NONE
- MAXIMUM_FIX_PRIORITY:LOW
- MAXIMUM_FIX_PRIORITY:HIGH

Final answer:
MAXIMUM_FIX_PRIORITY:MEDIUM
EOF
  local tmpdir; tmpdir=$(make_tmpdir)
  local output_file="${tmpdir}/github_output"
  : > "${output_file}"
  (
    export GITHUB_OUTPUT="${output_file}"
    export REVIEW_AREA="testing"
    export REPO="example/repo"
    export EXECUTION_FILE="${exec_file}"
    export GH_TOKEN="fake"
    bash "${SCRIPTS_DIR}/extract-review-priority.sh" >/dev/null 2>&1 || true
  )
  local out
  out=$(read_output_priority "${output_file}")
  assert_eq "MEDIUM" "${out}" \
    "codebase-review extractor must keep using tail -1 (last match wins)"
  rm -rf "${tmpdir}" "${exec_file}"
}

test_priority_extractors_agree_on_last_match_rule() {
  # Static check: BOTH extract-*.sh scripts should use `tail -1` so they
  # agree on the last-match-wins rule. Today the PR script does not, so
  # this test currently fails — keep it as a `_today` pin once flipped.
  local pr_script="${SCRIPTS_DIR}/extract-pr-review-priority.sh"
  local cr_script="${SCRIPTS_DIR}/extract-review-priority.sh"
  local cr_has_tail
  if grep -qE '\| *tail *-1' "${cr_script}"; then
    cr_has_tail="yes"
  else
    cr_has_tail="no"
  fi
  local pr_has_tail
  if grep -qE '\| *tail *-1' "${pr_script}"; then
    pr_has_tail="yes"
  else
    pr_has_tail="no"
  fi
  # We pin the CURRENT state: codebase-review has `tail -1`, PR review
  # does NOT. After the deferred fix in the PR body is applied, change
  # `pr_has_tail` expected value to "yes".
  assert_eq "yes" "${cr_has_tail}" "extract-review-priority.sh must keep tail -1"
  assert_eq "no"  "${pr_has_tail}" \
    "current state: extract-pr-review-priority.sh lacks tail -1 (review issue 29 MEDIUM). Flip to 'yes' after the deferred script fix is applied."
}
