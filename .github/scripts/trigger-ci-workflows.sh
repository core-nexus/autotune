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
for workflow in ${WORKFLOWS}; do
  echo "  -> ${workflow}"
  # Capture stderr so an intentionally-absent workflow can be distinguished
  # from a genuine failure (auth, bad ref). This stays best-effort — a failure
  # is reported but does not abort the loop or fail the step.
  if err="$(gh workflow run "${workflow}" --ref "${BRANCH}" --repo "${REPO}" 2>&1)"; then
    echo "  Triggered: ${workflow}"
  elif grep -qiE 'could not find|not found|no.*workflow|does not exist' <<<"${err}"; then
    echo "  Skipped: ${workflow} (not found or not dispatchable)"
  else
    echo "  Failed: ${workflow}: ${err}" >&2
  fi
done
