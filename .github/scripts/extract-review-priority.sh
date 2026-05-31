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
#
# Exit codes:
#   0 - real priority extracted (HIGH/MEDIUM/LOW/XLOW/NONE)
#   1 - UNKNOWN: extraction failed (gh API error, no parseable output, etc.)
#       The script still writes `priority=UNKNOWN` to GITHUB_OUTPUT before
#       exiting non-zero so downstream jobs that re-read this output can
#       distinguish "no signal" from a real value. Exiting non-zero turns
#       the review step red so the `notify` job fires — required for item 2
#       of the error-handling review: a silent extraction failure must not
#       look identical to a genuinely clean codebase.
#
# Output:
#   priority=<HIGH|MEDIUM|LOW|XLOW|NONE|UNKNOWN>

: "${GITHUB_OUTPUT:?}" "${GH_TOKEN:?}" "${REVIEW_AREA:?}" "${REPO:?}"

PRIORITY=""
EXECUTION_FILE_PRESENT=0
ISSUE_FOUND=0

# Method 1: parse the local execution file (most reliable).
# The action may not always emit one (e.g. internal failure before write),
# so absence here is informational, not fatal — we fall through to method 2.
if [[ -n "${EXECUTION_FILE:-}" ]] && [[ -f "${EXECUTION_FILE}" ]]; then
  EXECUTION_FILE_PRESENT=1
  # grep with no matches exits 1 under `set -e`; tolerate that here so we can
  # cleanly distinguish "file exists but no priority line" from "file missing".
  PRIORITY=$(grep -oP 'MAXIMUM_FIX_PRIORITY:\K[A-Z_]+' "${EXECUTION_FILE}" \
    | tail -1 || true)
  echo "Extracted from execution file: ${PRIORITY:-<empty>}"
else
  echo "No execution file found at: ${EXECUTION_FILE:-<unset>}"
fi

# Method 2 (fallback): fetch the latest review issue for this area.
# Do NOT discard stderr here — a `gh` failure must be visible in the job log
# and must propagate as a hard failure rather than collapsing to NONE.
if [[ -z "${PRIORITY}" ]]; then
  echo "Falling back to gh issue list..."
  GH_STDERR=$(mktemp)
  trap 'rm -f "${GH_STDERR}"' EXIT
  if BODY=$(gh issue list \
        --repo "${REPO}" \
        --state all --limit 10 \
        --json title,body \
        --jq "[.[] | select(.title | startswith(\"review(${REVIEW_AREA})\"))] | .[0].body" \
        2>"${GH_STDERR}"); then
    if [[ -n "${BODY}" && "${BODY}" != "null" ]]; then
      ISSUE_FOUND=1
      PRIORITY=$(echo "${BODY}" \
        | grep -oP 'MAXIMUM_FIX_PRIORITY:\K[A-Z_]+' | tail -1 || true)
      echo "Extracted from issue list: ${PRIORITY:-<empty>}"
    else
      echo "No matching review issue found for area: ${REVIEW_AREA}"
    fi
  else
    GH_EXIT=$?
    echo "::error::gh issue list failed (exit ${GH_EXIT}) for area ${REVIEW_AREA}" >&2
    echo "--- gh stderr ---" >&2
    cat "${GH_STDERR}" >&2
    echo "--- end gh stderr ---" >&2
    echo "priority=UNKNOWN" >> "${GITHUB_OUTPUT}"
    exit 1
  fi
fi

# Decide the sentinel.
#
# - A real priority value (HIGH/MEDIUM/LOW/XLOW/NONE): use it.
# - Empty AND we never had any signal (no execution file, no issue): UNKNOWN.
#   The review step likely failed before producing any output; treating this
#   as NONE would silently skip the fix stage AND the failure notification.
# - Empty AND we DID have a signal (file or issue) but no priority line:
#   the review output is malformed. Also UNKNOWN — same reasoning.
if [[ -z "${PRIORITY}" ]]; then
  if (( EXECUTION_FILE_PRESENT == 0 && ISSUE_FOUND == 0 )); then
    echo "::error::No execution file and no matching review issue for ${REVIEW_AREA} — review likely did not complete"
  else
    echo "::error::Review output for ${REVIEW_AREA} did not contain MAXIMUM_FIX_PRIORITY line"
  fi
  echo "priority=UNKNOWN" >> "${GITHUB_OUTPUT}"
  exit 1
fi

echo "MAXIMUM_FIX_PRIORITY for ${REVIEW_AREA}: ${PRIORITY}"
echo "priority=${PRIORITY}" >> "${GITHUB_OUTPUT}"
