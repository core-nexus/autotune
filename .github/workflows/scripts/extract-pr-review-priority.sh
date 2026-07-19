#!/usr/bin/env bash
set -euo pipefail

# Extract MAXIMUM_FIX_PRIORITY from the PR review and decide whether the fix
# stage should run, based on the configured threshold.
#
# Required env vars:
#   GITHUB_OUTPUT
#   GH_TOKEN
#   REPO - GitHub repository (owner/repo)
#   PR_NUMBER - the PR number
#
# Optional env vars:
#   EXECUTION_FILE - path to the claude-code-action execution file. When
#     present this is the most reliable source: it is the local transcript
#     of the review the action just finished writing, so there is no race
#     with GitHub's comments API which may not have propagated the final
#     comment body yet by the time this script runs.
#   MAXIMUM_FIX_PRIORITY - minimum severity that triggers a fix (default: MEDIUM).
#     Valid values: HIGH, MEDIUM, LOW, XLOW. Uses the same scale as the review
#     output. A review priority is "should_fix=true" iff it is >= this threshold.

: "${GITHUB_OUTPUT:?}" "${REPO:?}" "${PR_NUMBER:?}"

THRESHOLD="${MAXIMUM_FIX_PRIORITY:-MEDIUM}"

priority_rank() {
  case "$1" in
    HIGH) echo 4 ;;
    MEDIUM) echo 3 ;;
    LOW) echo 2 ;;
    XLOW) echo 1 ;;
    NONE | *) echo 0 ;;
  esac
}

# We pull the review priority from two sources and take the MAX of both:
#
#   - Method 1 (EXECUTION_FILE): the local transcript of the review the
#     action just finished writing. Most reliable for the just-run review
#     since the GitHub comments API may not yet have propagated its final
#     comment body.
#   - Method 2 (PR comments): scan ALL `MAXIMUM_FIX_PRIORITY:` lines on the
#     PR and pick the highest. Captures sibling reviewer workflows (e.g. a
#     path-scoped domain review) whose execution file is invisible to this
#     run but whose comment has already propagated to the API.
#
# Taking the max prevents a HIGH finding from one workflow getting silently
# overridden by a lower-severity finding from another (which a naive
# "last comment wins" approach is vulnerable to).

PRIORITY_FROM_FILE=""
PRIORITY_FROM_COMMENTS=""

# Method 1: parse the local execution file. claude-code-action writes its
# full transcript here, including the final MAXIMUM_FIX_PRIORITY:<LEVEL>
# line that the review prompt requires.
if [[ -n "${EXECUTION_FILE:-}" ]] && [[ -f "${EXECUTION_FILE}" ]]; then
  PRIORITY_FROM_FILE=$(grep -oP 'MAXIMUM_FIX_PRIORITY:\K[A-Z_]+' "${EXECUTION_FILE}" \
    | tail -1 || true)
  echo "Extracted from execution file: ${PRIORITY_FROM_FILE:-<empty>}"
else
  echo "No execution file found at: ${EXECUTION_FILE:-<unset>}"
fi

# Method 2: scan ALL PR comments and take the max severity. This is no
# longer a fallback — it always runs, so a HIGH from a sibling review
# workflow is still considered even when Method 1 already produced a value.
ALL_PRIORITIES=$(gh api "repos/${REPO}/issues/${PR_NUMBER}/comments" \
  --jq '.[].body' 2>/dev/null \
  | grep -oP '(?<=MAXIMUM_FIX_PRIORITY:)[A-Z_]+' || true)
echo "Priorities found in PR comments: ${ALL_PRIORITIES:-<empty>}"

MAX_COMMENT_RANK=0
while IFS= read -r p; do
  [[ -z "${p}" ]] && continue
  r=$(priority_rank "${p}")
  if (( r > MAX_COMMENT_RANK )); then
    MAX_COMMENT_RANK=${r}
    PRIORITY_FROM_COMMENTS="${p}"
  fi
done <<< "${ALL_PRIORITIES}"

# Choose the higher-ranked of the two sources.
FILE_RANK=$(priority_rank "${PRIORITY_FROM_FILE:-NONE}")
COMMENTS_RANK=$(priority_rank "${PRIORITY_FROM_COMMENTS:-NONE}")

if (( FILE_RANK >= COMMENTS_RANK )); then
  PRIORITY="${PRIORITY_FROM_FILE}"
else
  PRIORITY="${PRIORITY_FROM_COMMENTS}"
fi

# Loud warning when neither source produced a priority. This usually means
# either the review genuinely posted NONE, OR the GitHub comments API hasn't
# propagated the review's final body yet — and the two cases look identical
# downstream. Emitting a ::warning:: makes the difference visible in the
# Actions UI: operators can distinguish "review said NONE" from "API race"
# by checking whether a MAXIMUM_FIX_PRIORITY: comment actually exists on the PR.
if [[ -z "${PRIORITY_FROM_FILE}" ]] && [[ -z "${PRIORITY_FROM_COMMENTS}" ]]; then
  echo "::warning::No MAXIMUM_FIX_PRIORITY comment found for PR #${PR_NUMBER} via either execution-file or API scan; defaulting to NONE. If a review comment is visible on the PR, this is a GitHub comments-API race — the babysit loop will re-dispatch /claude-fix on its next pass."
fi

PRIORITY="${PRIORITY:-NONE}"

PRI_RANK=$(priority_rank "${PRIORITY}")
THRESHOLD_RANK=$(priority_rank "${THRESHOLD}")

# NONE never triggers a fix, regardless of threshold.
if (( THRESHOLD_RANK > 0 )) && (( PRI_RANK >= THRESHOLD_RANK )); then
  SHOULD_FIX=true
else
  SHOULD_FIX=false
fi

echo "MAXIMUM_FIX_PRIORITY (from file):     ${PRIORITY_FROM_FILE:-<empty>}"
echo "MAXIMUM_FIX_PRIORITY (from comments): ${PRIORITY_FROM_COMMENTS:-<empty>}"
echo "MAXIMUM_FIX_PRIORITY (max of both):   ${PRIORITY}"
echo "MAXIMUM_FIX_PRIORITY (threshold):     ${THRESHOLD}"
echo "should_fix:                           ${SHOULD_FIX}"

echo "priority=${PRIORITY}" >> "${GITHUB_OUTPUT}"
echo "threshold=${THRESHOLD}" >> "${GITHUB_OUTPUT}"
echo "should_fix=${SHOULD_FIX}" >> "${GITHUB_OUTPUT}"
