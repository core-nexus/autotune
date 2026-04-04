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
  gh workflow run "${workflow}" --ref "${BRANCH}" --repo "${REPO}" 2>/dev/null \
    || echo "  Skipped: ${workflow} (not found or not dispatchable)"
done
