#!/usr/bin/env bash
set -euo pipefail

# Extract MAXIMUM_FIX_PRIORITY from a codebase review execution file or GitHub
# issue, then decide whether the fix stage should run based on the configured
# threshold.
#
# Required env vars:
#   GITHUB_OUTPUT
#   GH_TOKEN
#   REVIEW_AREA - the review area name (e.g. "security")
#   REPO - GitHub repository (owner/repo)
#
# Optional env vars:
#   EXECUTION_FILE - path to the claude-code-action execution file
#   MAXIMUM_FIX_PRIORITY - minimum severity that triggers a fix (default: MEDIUM).
#     Valid values: HIGH, MEDIUM, LOW, XLOW. Uses the same scale as the review
#     output. A review priority is "should_fix=true" iff it is >= this threshold.

: "${GITHUB_OUTPUT:?}" "${REVIEW_AREA:?}" "${REPO:?}"

THRESHOLD="${MAXIMUM_FIX_PRIORITY:-MEDIUM}"

PRIORITY=""

# Method 1: parse the local execution file (most reliable)
if [[ -n "${EXECUTION_FILE:-}" ]] && [[ -f "${EXECUTION_FILE}" ]]; then
  PRIORITY=$(grep -oP 'MAXIMUM_FIX_PRIORITY:\K[A-Z_]+' "${EXECUTION_FILE}" \
    | tail -1 || true)
  echo "Extracted from execution file: ${PRIORITY:-<empty>}"
else
  echo "No execution file found at: ${EXECUTION_FILE:-<unset>}"
fi

# Method 2 (fallback): list recent issues via REST API
if [[ -z "${PRIORITY}" ]]; then
  echo "Falling back to gh issue list..."
  BODY=$(gh issue list \
    --repo "${REPO}" \
    --state all --limit 10 \
    --json title,body \
    --jq "[.[] | select(.title | startswith(\"review(${REVIEW_AREA})\"))] | .[0].body" \
    2>/dev/null || true)
  PRIORITY=$(echo "${BODY}" \
    | grep -oP 'MAXIMUM_FIX_PRIORITY:\K[A-Z_]+' || true)
  echo "Extracted from issue list: ${PRIORITY:-<empty>}"
fi

PRIORITY="${PRIORITY:-NONE}"

priority_rank() {
  case "$1" in
    HIGH) echo 4 ;;
    MEDIUM) echo 3 ;;
    LOW) echo 2 ;;
    XLOW) echo 1 ;;
    NONE | *) echo 0 ;;
  esac
}

PRI_RANK=$(priority_rank "${PRIORITY}")
THRESHOLD_RANK=$(priority_rank "${THRESHOLD}")

# NONE never triggers a fix, regardless of threshold.
if (( THRESHOLD_RANK > 0 )) && (( PRI_RANK >= THRESHOLD_RANK )); then
  SHOULD_FIX=true
else
  SHOULD_FIX=false
fi

echo "MAXIMUM_FIX_PRIORITY (review output) for ${REVIEW_AREA}: ${PRIORITY}"
echo "MAXIMUM_FIX_PRIORITY (threshold):                         ${THRESHOLD}"
echo "should_fix:                                               ${SHOULD_FIX}"

echo "priority=${PRIORITY}" >> "${GITHUB_OUTPUT}"
echo "threshold=${THRESHOLD}" >> "${GITHUB_OUTPUT}"
echo "should_fix=${SHOULD_FIX}" >> "${GITHUB_OUTPUT}"
