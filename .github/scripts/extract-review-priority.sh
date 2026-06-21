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

: "${GITHUB_OUTPUT:?}" "${REVIEW_AREA:?}" "${REPO:?}"

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
# A failed API call (auth, rate limit, network, transient 5xx) must NOT be
# treated the same as a successful call that found no priority marker. Coercing
# a failure to NONE would silently gate off the fix stage even when the review
# found HIGH/MEDIUM issues. So capture the gh exit status separately and fail
# loudly on an API error instead of swallowing stderr with `2>/dev/null`.
if [[ -z "${PRIORITY}" ]]; then
  echo "Falling back to gh issue list..."
  set +e
  BODY=$(gh issue list \
    --repo "${REPO}" \
    --state all --limit 10 \
    --json title,body \
    --jq "[.[] | select(.title | startswith(\"review(${REVIEW_AREA})\"))] | .[0].body")
  gh_status=$?
  set -e

  if [[ ${gh_status} -ne 0 ]]; then
    echo "::error::Failed to query issues for '${REVIEW_AREA}' (gh exit ${gh_status}). Cannot determine review priority; refusing to coerce to NONE." >&2
    exit "${gh_status}"
  fi

  PRIORITY=$(echo "${BODY}" \
    | grep -oP 'MAXIMUM_FIX_PRIORITY:\K[A-Z_]+' || true)
  echo "Extracted from issue list: ${PRIORITY:-<empty>}"
fi

PRIORITY="${PRIORITY:-NONE}"
echo "MAXIMUM_FIX_PRIORITY for ${REVIEW_AREA}: ${PRIORITY}"
echo "priority=${PRIORITY}" >> "${GITHUB_OUTPUT}"
