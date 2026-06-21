#!/usr/bin/env bash
set -euo pipefail

# Surface a PR review/fix pipeline failure on the pull request itself.
#
# The failed job already marks the workflow run red, but a silently failed
# auto-fix job can leave a PR looking unreviewed. Posting a comment puts the
# failure where the author will actually see it.
#
# Required env vars:
#   GH_TOKEN
#   REPO       - GitHub repository (owner/repo)
#   PR_NUMBER  - the pull request number
#   RUN_URL    - URL of the failing workflow run
#
# Optional env vars (job results; default "unknown"):
#   REVIEW_RESULT, FIX_RESULT

: "${GH_TOKEN:?}" "${REPO:?}" "${PR_NUMBER:?}" "${RUN_URL:?}"

REVIEW_RESULT="${REVIEW_RESULT:-unknown}"
FIX_RESULT="${FIX_RESULT:-unknown}"

SUMMARY="review: ${REVIEW_RESULT}, fix: ${FIX_RESULT}"
echo "::warning::PR review workflow failed. ${SUMMARY}"

COMMENT=$(printf 'Automated PR review/fix pipeline failed (%s).\n\nSee the run for details: %s\n\nThis comment is posted automatically so a failed review or auto-fix stage is not missed.' \
  "${SUMMARY}" "${RUN_URL}")

gh pr comment "${PR_NUMBER}" --repo "${REPO}" --body "${COMMENT}"
