#!/usr/bin/env bash
set -euo pipefail

# Extract MAXIMUM_FIX_PRIORITY from the latest PR review comment.
#
# Required env vars:
#   GITHUB_OUTPUT
#   GH_TOKEN
#   REPO - GitHub repository (owner/repo)
#   PR_NUMBER - the PR number

: "${GITHUB_OUTPUT:?}" "${REPO:?}" "${PR_NUMBER:?}"

# Fetch PR comments. A failed API call must NOT be conflated with a genuine
# "no priority marker found" result — burying the error with `2>/dev/null` and
# defaulting to NONE would silently skip the fix stage even when the review
# found real issues. Capture the gh exit status separately and fail loudly on
# an API error; only treat a successful-but-empty result as NONE.
set +e
COMMENTS=$(gh api "repos/${REPO}/issues/${PR_NUMBER}/comments" \
  --jq '[.[] | select(.body | test("MAXIMUM_FIX_PRIORITY:"))] | last | .body')
gh_status=$?
set -e

if [[ ${gh_status} -ne 0 ]]; then
  echo "::error::Failed to fetch comments for PR ${PR_NUMBER} (gh exit ${gh_status}). Cannot determine review priority; refusing to coerce to NONE." >&2
  exit "${gh_status}"
fi

PRIORITY=$(echo "${COMMENTS}" \
  | grep -oP '(?<=MAXIMUM_FIX_PRIORITY:)[A-Z_]+' || true)
PRIORITY="${PRIORITY:-NONE}"

echo "MAXIMUM_FIX_PRIORITY: ${PRIORITY}"
echo "priority=${PRIORITY}" >> "${GITHUB_OUTPUT}"
