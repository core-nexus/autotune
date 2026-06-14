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

# Recognized priority values, in escalating order. Anything outside this set is
# treated as a parse failure rather than silently trusted.
VALID_PRIORITIES="NONE LOW MEDIUM HIGH CRITICAL"

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
    | grep -oP 'MAXIMUM_FIX_PRIORITY:\K[A-Z_]+' | tail -1 || true)
  echo "Extracted from issue list: ${PRIORITY:-<empty>}"
fi

# A missing marker and a genuinely clean review both arrive here as empty.
# Default to NONE (which suppresses the fix stage), but log a distinguishable
# warning so a silent parse failure is not mistaken for "nothing to fix".
if [[ -z "${PRIORITY}" ]]; then
  echo "WARNING: no MAXIMUM_FIX_PRIORITY marker found for '${REVIEW_AREA}'; defaulting to NONE. If a fix was expected, the marker format may have drifted." >&2
  PRIORITY="NONE"
elif [[ " ${VALID_PRIORITIES} " != *" ${PRIORITY} "* ]]; then
  echo "WARNING: unrecognized priority '${PRIORITY}' for '${REVIEW_AREA}'; defaulting to NONE." >&2
  PRIORITY="NONE"
fi

echo "MAXIMUM_FIX_PRIORITY for ${REVIEW_AREA}: ${PRIORITY}"
echo "priority=${PRIORITY}" >> "${GITHUB_OUTPUT}"
