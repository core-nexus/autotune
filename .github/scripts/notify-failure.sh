#!/usr/bin/env bash
set -euo pipefail

# Report a codebase-review pipeline failure durably and visibly.
#
# A scheduled (cron) review run has no human watching it, so a bare
# `echo "::warning::..."` — which only writes an annotation to a run log nobody
# reads and still leaves the job green — is not real notification. This script:
#   1. Emits a workflow warning annotation (cheap, shows on the run).
#   2. Opens (or appends to an existing) tracking GitHub issue so the failure
#      is recorded somewhere durable and visible.
#   3. Exits non-zero so the run status itself reflects the failure.
#
# Required env vars:
#   GH_TOKEN
#   REPO     - GitHub repository (owner/repo)
#   RUN_URL  - URL of the failing workflow run
#
# Optional env vars (job results; default "unknown"):
#   DETERMINE_RESULT, REVIEW_RESULT, FIX_RESULT

: "${GH_TOKEN:?}" "${REPO:?}" "${RUN_URL:?}"

DETERMINE_RESULT="${DETERMINE_RESULT:-unknown}"
REVIEW_RESULT="${REVIEW_RESULT:-unknown}"
FIX_RESULT="${FIX_RESULT:-unknown}"

SUMMARY="determine-area: ${DETERMINE_RESULT}, review: ${REVIEW_RESULT}, fix: ${FIX_RESULT}"
echo "::warning::Codebase review workflow failed. ${SUMMARY}"

LABEL="auto-review-failure"
TITLE="codebase-review pipeline failure"
COMMENT=$(printf 'Automated codebase-review pipeline failed.\n\n- Run: %s\n- Job results: %s\n\nThis issue is opened automatically when a scheduled or manual review run fails, so the failure is not silently lost. Close it once the cause is resolved.' \
  "${RUN_URL}" "${SUMMARY}")

# Reuse an existing open tracking issue if one exists, else open a new one.
set +e
EXISTING=$(gh issue list --repo "${REPO}" --state open --label "${LABEL}" \
  --search "${TITLE} in:title" --json number --jq '.[0].number // empty')
list_status=$?
set -e

if [[ ${list_status} -ne 0 ]]; then
  echo "::error::Could not query existing tracking issues (gh exit ${list_status}). Failing the run so the failure is still visible via run status." >&2
  exit 1
fi

if [[ -n "${EXISTING}" ]]; then
  echo "Appending to existing tracking issue ${EXISTING}"
  gh issue comment "${EXISTING}" --repo "${REPO}" --body "${COMMENT}"
else
  echo "Opening new tracking issue"
  # Ensure the label exists (ignore the error if it already does).
  gh label create "${LABEL}" --repo "${REPO}" --color B60205 \
    --description "Automated review pipeline failure" 2>/dev/null || true
  gh issue create --repo "${REPO}" --title "${TITLE}" --label "${LABEL}" --body "${COMMENT}"
fi

# Mark the run as failed so the failure is reflected in run status, not just an
# annotation that leaves the job green.
exit 1
