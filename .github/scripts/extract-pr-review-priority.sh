#!/usr/bin/env bash
set -euo pipefail

# Extract MAXIMUM_FIX_PRIORITY from the latest PR review comment.
#
# Required env vars:
#   GITHUB_OUTPUT
#   GH_TOKEN
#   REPO - GitHub repository (owner/repo)
#   PR_NUMBER - the PR number

: "${GITHUB_OUTPUT:?}" "${GH_TOKEN:?}" "${REPO:?}" "${PR_NUMBER:?}"

# Fetch PR comments. We must distinguish a real API failure (auth, network,
# rate limit, secondary rate limit, 5xx) from the legitimate "no priority
# marker found" case. Routing a transient failure through the benign NONE
# default would silently gate off the fix stage with no one noticing, so a
# genuine gh error is surfaced as an explicit error + EXTRACT_FAILED sentinel
# and fails the step. Note: stderr is intentionally NOT discarded so the error
# text reaches the workflow logs.
if ! COMMENTS=$(gh api "repos/${REPO}/issues/${PR_NUMBER}/comments" \
  --jq '[.[] | select(.body | test("MAXIMUM_FIX_PRIORITY:"))] | last | .body'); then
  echo "::error::Failed to fetch comments for ${REPO} item ${PR_NUMBER} (gh api error). Cannot determine fix priority; not defaulting to NONE."
  echo "priority=EXTRACT_FAILED" >> "${GITHUB_OUTPUT}"
  exit 1
fi

# API call succeeded. A missing marker here is genuine "no priority" -> NONE.
PRIORITY=$(printf '%s' "${COMMENTS}" \
  | grep -oP '(?<=MAXIMUM_FIX_PRIORITY:)[A-Z_]+' || true)
PRIORITY="${PRIORITY:-NONE}"

echo "MAXIMUM_FIX_PRIORITY: ${PRIORITY}"
echo "priority=${PRIORITY}" >> "${GITHUB_OUTPUT}"
