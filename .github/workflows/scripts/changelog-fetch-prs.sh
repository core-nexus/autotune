#!/usr/bin/env bash
set -euo pipefail

# Fetch PRs merged into the base branch since the last changelog entry, writing
# them to a JSON file for the changelog-generation step to read.
#
# Required env vars:
#   GITHUB_OUTPUT
#   GH_TOKEN     - token with permission to list PRs
#   REPO         - GitHub repository (owner/repo)
#   LAST_DATE    - date string (YYYY-MM-DD) from the previous step
# Optional env vars:
#   BASE_BRANCH  - branch merged PRs targeted (default: main)
#   PR_JSON_FILE - output path for the fetched PRs (default: $RUNNER_TEMP/merged-prs.json)

: "${GITHUB_OUTPUT:?}" "${REPO:?}" "${LAST_DATE:?}"
BASE_BRANCH="${BASE_BRANCH:-main}"
PR_JSON_FILE="${PR_JSON_FILE:-${RUNNER_TEMP:-/tmp}/merged-prs.json}"

SINCE="${LAST_DATE}T00:00:00Z"
echo "Fetching PRs merged after ${SINCE} into ${BASE_BRANCH}"

gh pr list \
  --repo "${REPO}" \
  --state merged \
  --base "${BASE_BRANCH}" \
  --search "merged:>=${SINCE}" \
  --json number,title,body,mergedAt \
  --limit 200 \
  --jq 'sort_by(.mergedAt)' > "${PR_JSON_FILE}"

PR_COUNT=$(jq length "${PR_JSON_FILE}")
echo "Found ${PR_COUNT} merged PRs since ${SINCE}"
echo "pr_count=${PR_COUNT}" >> "${GITHUB_OUTPUT}"

if [[ "${PR_COUNT}" -eq 0 ]]; then
  echo "No new PRs to process"
fi
