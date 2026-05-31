#!/usr/bin/env bash
set -euo pipefail

# Extract MAXIMUM_FIX_PRIORITY from a codebase review execution file or
# the matching GitHub issue body.
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/extract-priority.sh
. "${SCRIPT_DIR}/lib/extract-priority.sh"

PRIORITY="NONE"

# Method 1: parse the local execution file.
# The execution transcript contains the prompt itself (with its verbatim
# five-value example block) interleaved with the model's response. The
# shared helper skips that block, so the verdict is recovered correctly
# even when the prompt's menu appears after the verdict in the transcript.
if [[ -n "${EXECUTION_FILE:-}" ]] && [[ -f "${EXECUTION_FILE}" ]]; then
  PRIORITY=$(extract_priority_from_file "${EXECUTION_FILE}")
  echo "Extracted from execution file: ${PRIORITY}"
else
  echo "No execution file found at: ${EXECUTION_FILE:-<unset>}"
fi

# Method 2 (fallback): fetch the matching issue body.
# `startswith("review(${REVIEW_AREA}):")` is anchored with the trailing
# `):` so a short area substring cannot match a neighbouring area's
# issues (e.g. area "code" matching "review(code-quality): ...").
if [[ "${PRIORITY}" = "NONE" ]]; then
  echo "Falling back to gh issue list..."
  BODY=$(gh issue list \
    --repo "${REPO}" \
    --state all --limit 10 \
    --json title,body \
    --jq "[.[] | select(.title | startswith(\"review(${REVIEW_AREA}):\"))] | .[0].body" \
    2>/dev/null || true)
  if [[ -n "${BODY}" ]]; then
    PRIORITY=$(printf '%s\n' "${BODY}" | extract_priority_from_text)
    echo "Extracted from issue body: ${PRIORITY}"
  else
    echo "No matching issue body found"
  fi
fi

PRIORITY=$(write_priority_output "${PRIORITY}")
echo "MAXIMUM_FIX_PRIORITY for ${REVIEW_AREA}: ${PRIORITY}"
