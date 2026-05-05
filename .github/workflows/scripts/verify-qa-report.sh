#!/usr/bin/env bash
# Fail the QA job if the agent could not actually run a browser-based
# QA pass. We detect this by inspecting the draft report at
# $ARTIFACTS_DIR/_comment.md:
#
#   - Missing or empty       → agent crashed before writing anything;
#                               fail the job so the post-comment step's
#                               failure-banner branch fires (which
#                               preserves the claude[bot] tracking
#                               comment with diagnostic detail).
#   - Contains "could not run" heading
#                            → agent's Step 0 fired (no MCP tools
#                               loaded), or the prewarm step wrote a
#                               diagnostic. Either way: no real QA
#                               happened, so the job is failure.
#   - Otherwise              → real report; succeed.
#
# Required env:
#   ARTIFACTS_DIR  - directory where the agent (and the prewarm script
#                    before it) writes _comment.md.

set -uo pipefail

: "${ARTIFACTS_DIR:?}"

COMMENT_FILE="${ARTIFACTS_DIR}/_comment.md"
# The exact heading both the agent's Step 0 template AND the prewarm
# script's hard-failure path emit. Anchored to the em-dash + phrase to
# avoid false positives from a real report that mentions "could not run"
# in passing.
COULD_NOT_RUN_PATTERN='— could not run'

if [[ ! -f "${COMMENT_FILE}" ]]; then
  echo "::error::QA agent did not write a report at ${COMMENT_FILE}; failing the qa job."
  exit 1
fi

if [[ ! -s "${COMMENT_FILE}" ]]; then
  echo "::error::QA agent wrote an empty report at ${COMMENT_FILE}; failing the qa job."
  exit 1
fi

if grep -qF -- "${COULD_NOT_RUN_PATTERN}" "${COMMENT_FILE}"; then
  echo "::error::QA agent wrote a 'could not run' verdict — no real browser QA happened. Failing the qa job so diagnostics are preserved."
  echo
  echo "----- _comment.md (first 60 lines) -----"
  head -n 60 "${COMMENT_FILE}"
  exit 1
fi

echo "QA produced a real report at ${COMMENT_FILE} ($(wc -c <"${COMMENT_FILE}") bytes)."
exit 0
