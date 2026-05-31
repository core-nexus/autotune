#!/usr/bin/env bash
set -euo pipefail

# Extract MAXIMUM_FIX_PRIORITY from the latest PR review comment.
#
# Required env vars:
#   GITHUB_OUTPUT
#   GH_TOKEN
#   REPO - GitHub repository (owner/repo)
#   PR_NUMBER - the PR number
#
# Exit codes:
#   0 - priority extracted successfully (including NONE/UNKNOWN)
#   1 - hard failure (gh API error, missing env)
#
# Output:
#   priority=<HIGH|MEDIUM|LOW|XLOW|NONE|UNKNOWN>
#
# Sentinel rules:
#   - NONE: review fetched successfully and found no priority line.
#   - UNKNOWN: review fetched but its content lacked any parseable priority.
#   - hard failure (exit 1): the API call itself failed, so the review step
#     should turn red and the notify job should fire. Do NOT silently default
#     to NONE on an API failure — that lets a transient outage skip the fix
#     stage with no signal that anything went wrong.

: "${GITHUB_OUTPUT:?}" "${GH_TOKEN:?}" "${REPO:?}" "${PR_NUMBER:?}"

GH_STDERR=$(mktemp)
trap 'rm -f "${GH_STDERR}"' EXIT

# Capture stderr separately so we can log it on failure rather than silently
# routing it to /dev/null. We need to distinguish "API succeeded, no priority
# line in comments" from "API call failed".
if ! COMMENT_BODY=$(gh api "repos/${REPO}/issues/${PR_NUMBER}/comments" \
      --jq '[.[] | select(.body | test("MAXIMUM_FIX_PRIORITY:"))] | last | .body' \
      2>"${GH_STDERR}"); then
  GH_EXIT=$?
  echo "::error::gh api failed (exit ${GH_EXIT}) fetching comments for PR ${PR_NUMBER}" >&2
  echo "--- gh stderr ---" >&2
  cat "${GH_STDERR}" >&2
  echo "--- end gh stderr ---" >&2
  echo "priority=UNKNOWN" >> "${GITHUB_OUTPUT}"
  exit 1
fi

if [[ -z "${COMMENT_BODY}" || "${COMMENT_BODY}" == "null" ]]; then
  PRIORITY="NONE"
  echo "No review comment with MAXIMUM_FIX_PRIORITY found on PR ${PR_NUMBER}"
else
  PRIORITY=$(echo "${COMMENT_BODY}" \
    | grep -oP '(?<=MAXIMUM_FIX_PRIORITY:)[A-Z_]+' | tail -1 || true)
  if [[ -z "${PRIORITY}" ]]; then
    echo "::error::Review comment contained MAXIMUM_FIX_PRIORITY: marker but value was unparseable"
    echo "priority=UNKNOWN" >> "${GITHUB_OUTPUT}"
    exit 1
  fi
fi

echo "MAXIMUM_FIX_PRIORITY: ${PRIORITY}"
echo "priority=${PRIORITY}" >> "${GITHUB_OUTPUT}"
