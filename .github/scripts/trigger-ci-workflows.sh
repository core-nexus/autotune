#!/usr/bin/env bash
set -euo pipefail

# Trigger CI workflows on a given branch via workflow_dispatch.
#
# Required env vars:
#   GH_TOKEN
#   REPO - GitHub repository (owner/repo)
#   BRANCH - branch name to trigger on
#
# Optional env vars:
#   WORKFLOWS - space-separated list of workflow filenames (default: auto-detect)
#
# If WORKFLOWS is not set, this script will attempt to trigger common CI
# workflow names. Customize the WORKFLOWS variable for your project.

: "${GH_TOKEN:?}" "${REPO:?}" "${BRANCH:?}"

# Default: try common CI workflow names. Override with WORKFLOWS env var.
WORKFLOWS="${WORKFLOWS:-ci.yml checks.yml test.yml}"

echo "Triggering CI workflows on branch: ${BRANCH}"

triggered=0
errored=0
attempted=0
for workflow in ${WORKFLOWS}; do
  attempted=$((attempted + 1))
  echo "  -> ${workflow}"
  # Capture combined output so we can tell a benign "workflow not found / not
  # dispatchable" (expected when a repo hasn't customized WORKFLOWS) apart from
  # a real auth/network/permission failure. A genuine error must not be
  # silently reported as "Skipped" and pass the step green.
  if out=$(gh workflow run "${workflow}" --ref "${BRANCH}" --repo "${REPO}" 2>&1); then
    triggered=$((triggered + 1))
    echo "  Triggered: ${workflow}"
  elif printf '%s' "${out}" \
    | grep -qiE 'could not find|not found|404|no workflow|does not have'; then
    echo "  Skipped: ${workflow} (not found or not dispatchable)"
  else
    errored=$((errored + 1))
    echo "::warning::Failed to trigger ${workflow} on ${BRANCH}: ${out}"
  fi
done

echo "Triggered ${triggered}/${attempted} workflow(s); ${errored} error(s)."

if [[ "${triggered}" -eq 0 ]]; then
  if [[ "${errored}" -gt 0 ]]; then
    # Real failures and nothing got triggered: the PR may have NO CI coverage.
    # Surface loudly and fail the step rather than reporting a misleading green.
    echo "::error::No CI workflows could be triggered on ${BRANCH}: ${errored} of ${attempted} attempts failed with errors (not 'not found'). The PR may have no CI coverage."
    exit 1
  fi
  # None of the candidate names exist/are dispatchable. Expected for repos that
  # have not customized WORKFLOWS — warn (don't fail) so CI coverage gaps are
  # still visible without breaking the common case.
  echo "::warning::No CI workflows were triggered on ${BRANCH}: none of [${WORKFLOWS}] were found or dispatchable. Set the WORKFLOWS env var to your project's CI workflow filenames. The PR may have no CI coverage."
fi
