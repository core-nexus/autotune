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

# Recognized priority values. Anything outside this set is treated as a parse
# failure rather than silently trusted.
VALID_PRIORITIES="NONE LOW MEDIUM HIGH CRITICAL"

PRIORITY=$(gh api "repos/${REPO}/issues/${PR_NUMBER}/comments" \
  --jq '[.[] | select(.body | test("MAXIMUM_FIX_PRIORITY:"))] | last | .body' 2>/dev/null \
  | grep -oP '(?<=MAXIMUM_FIX_PRIORITY:)[A-Z_]+' | tail -1 || true)

# Default to NONE on a parse miss, but log a distinguishable warning so a
# missing/malformed marker is not silently equated with "nothing to fix".
if [[ -z "${PRIORITY}" ]]; then
  echo "WARNING: no MAXIMUM_FIX_PRIORITY marker found in PR ${PR_NUMBER} comments; defaulting to NONE." >&2
  PRIORITY="NONE"
elif [[ " ${VALID_PRIORITIES} " != *" ${PRIORITY} "* ]]; then
  echo "WARNING: unrecognized priority '${PRIORITY}' in PR ${PR_NUMBER}; defaulting to NONE." >&2
  PRIORITY="NONE"
fi

echo "MAXIMUM_FIX_PRIORITY: ${PRIORITY}"
echo "priority=${PRIORITY}" >> "${GITHUB_OUTPUT}"
