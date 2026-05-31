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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/extract-priority.sh
. "${SCRIPT_DIR}/lib/extract-priority.sh"

BODY=$(gh api "repos/${REPO}/issues/${PR_NUMBER}/comments" \
  --jq '[.[] | select(.body | test("MAXIMUM_FIX_PRIORITY:"))] | last | .body' \
  2>/dev/null || true)

if [[ -z "${BODY}" || "${BODY}" = "null" ]]; then
  PRIORITY="NONE"
else
  PRIORITY=$(printf '%s\n' "${BODY}" | extract_priority_from_text)
fi

PRIORITY=$(write_priority_output "${PRIORITY}")
echo "MAXIMUM_FIX_PRIORITY: ${PRIORITY}"
