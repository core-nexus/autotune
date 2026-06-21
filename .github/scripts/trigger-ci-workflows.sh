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

: "${REPO:?}" "${BRANCH:?}"

# Default: try common CI workflow names. Override with WORKFLOWS env var.
WORKFLOWS="${WORKFLOWS:-ci.yml checks.yml test.yml}"

echo "Triggering CI workflows on branch: ${BRANCH}"

triggered=0
errored=0
for workflow in ${WORKFLOWS}; do
  echo "  -> ${workflow}"

  # Capture stderr and the exit code instead of blanket-swallowing every error
  # as a benign "not found" skip. A genuinely missing/non-dispatchable workflow
  # is expected and benign; auth failures, rate limiting, network errors, and an
  # invalid --ref are NOT and must be surfaced — otherwise an auto-fix PR could
  # ship with no CI while the log falsely reports everything was "skipped".
  set +e
  err=$(gh workflow run "${workflow}" --ref "${BRANCH}" --repo "${REPO}" 2>&1 1>/dev/null)
  status=$?
  set -e

  if [[ ${status} -eq 0 ]]; then
    triggered=$((triggered + 1))
    echo "     Triggered: ${workflow}"
  elif echo "${err}" | grep -qiE 'could not find|not found|no workflow|does not exist'; then
    echo "     Skipped: ${workflow} (not found or not dispatchable)"
  else
    errored=$((errored + 1))
    echo "::warning::Failed to trigger ${workflow} on ${BRANCH}: ${err}"
  fi
done

echo "CI trigger summary: ${triggered} triggered, ${errored} errored."

# If nothing was triggered, the auto-fix PR may have no CI coverage at all —
# make that visible rather than letting the PR look validated when it is not.
if [[ ${triggered} -eq 0 ]]; then
  echo "::warning::No CI workflows were triggered on ${BRANCH} (checked: ${WORKFLOWS}). The auto-fix PR may have no CI coverage. Set the WORKFLOWS env var to your project's workflow filenames."
fi
