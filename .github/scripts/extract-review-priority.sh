#!/usr/bin/env bash
set -euo pipefail

# Extract MAXIMUM_FIX_PRIORITY from a codebase review execution file or GitHub issue.
#
# Required env vars:
#   GITHUB_OUTPUT
#   GH_TOKEN
#   REVIEW_AREA - the review area name (e.g. "security")
#   REPO - GitHub repository (owner/repo)
#
# Optional env vars:
#   EXECUTION_FILE - path to the claude-code-action execution file

: "${GITHUB_OUTPUT:?}" "${GH_TOKEN:?}" "${REVIEW_AREA:?}" "${REPO:?}"

PRIORITY=""

# Method 1: parse the local execution file (most reliable)
if [[ -n "${EXECUTION_FILE:-}" ]] && [[ -f "${EXECUTION_FILE}" ]]; then
  PRIORITY=$(grep -oP 'MAXIMUM_FIX_PRIORITY:\K[A-Z_]+' "${EXECUTION_FILE}" \
    | tail -1 || true)
  echo "Extracted from execution file: ${PRIORITY:-<empty>}"
else
  echo "No execution file found at: ${EXECUTION_FILE:-<unset>}"
fi

# Method 2 (fallback): list recent issues via REST API.
#
# A real gh failure here (auth, network, rate limit, 5xx) must NOT be silently
# downgraded to NONE: that would gate off the fix stage even though the review
# genuinely found HIGH/MEDIUM issues, and no one would be told. We therefore
# distinguish an API failure (-> explicit error + EXTRACT_FAILED, fail the step)
# from the legitimate "no matching issue / no marker" case (-> NONE).
if [[ -z "${PRIORITY}" ]]; then
  echo "Falling back to gh issue list..."
  if ! BODY=$(gh issue list \
    --repo "${REPO}" \
    --state all --limit 10 \
    --json title,body \
    --jq "[.[] | select(.title | startswith(\"review(${REVIEW_AREA})\"))] | .[0].body"); then
    echo "::error::Failed to list issues for ${REPO} (gh api error) while extracting priority for ${REVIEW_AREA}. Cannot determine fix priority; not defaulting to NONE."
    echo "priority=EXTRACT_FAILED" >> "${GITHUB_OUTPUT}"
    exit 1
  fi
  PRIORITY=$(printf '%s' "${BODY}" \
    | grep -oP 'MAXIMUM_FIX_PRIORITY:\K[A-Z_]+' || true)
  echo "Extracted from issue list: ${PRIORITY:-<empty>}"
fi

PRIORITY="${PRIORITY:-NONE}"
echo "MAXIMUM_FIX_PRIORITY for ${REVIEW_AREA}: ${PRIORITY}"
echo "priority=${PRIORITY}" >> "${GITHUB_OUTPUT}"
