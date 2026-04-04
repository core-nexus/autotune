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

PRIORITY=$(gh api "repos/${REPO}/issues/${PR_NUMBER}/comments" \
  --jq '[.[] | select(.body | test("MAXIMUM_FIX_PRIORITY:"))] | last | .body' 2>/dev/null \
  | grep -oP '(?<=MAXIMUM_FIX_PRIORITY:)[A-Z_]+' || echo "NONE")

echo "MAXIMUM_FIX_PRIORITY: ${PRIORITY}"
echo "priority=${PRIORITY}" >> "${GITHUB_OUTPUT}"
