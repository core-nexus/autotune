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
#   WORKFLOWS - space-separated list of workflow filenames
#               (default: ci.yml checks.yml test.yml)
#
# Trigger failures are categorised so that a genuine dispatch error
# (auth, transient network, etc.) is surfaced via `::warning::` rather
# than silently treated as "workflow not found".

: "${REPO:?}" "${BRANCH:?}"

WORKFLOWS="${WORKFLOWS:-ci.yml checks.yml test.yml}"

echo "Triggering CI workflows on branch: ${BRANCH}"
for workflow in ${WORKFLOWS}; do
  echo "  -> ${workflow}"
  err_output=$(gh workflow run "${workflow}" \
    --ref "${BRANCH}" --repo "${REPO}" 2>&1) && rc=0 || rc=$?
  if [[ "${rc}" -eq 0 ]]; then
    echo "     dispatched"
    continue
  fi
  # gh prints "Could not find any workflows named ..." on 404. Treat that
  # case as a best-effort skip; surface anything else as a real warning
  # so genuine failures aren't lost in the noise.
  if printf '%s\n' "${err_output}" | grep -qiE 'could not find|not found|no workflow'; then
    echo "     Skipped: ${workflow} (not found)"
  else
    echo "::warning::Failed to dispatch ${workflow} on ${BRANCH}: ${err_output}"
  fi
done
