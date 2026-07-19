#!/usr/bin/env bash
set -euo pipefail

# Resolve which codebase review area(s) to run based on schedule or input.
#
# Required env vars:
#   GITHUB_OUTPUT
#   EVENT_NAME - "workflow_dispatch" or "schedule"
#
# Optional env vars:
#   INPUT_REVIEW_AREA - the area chosen by the user (workflow_dispatch only)

: "${GITHUB_OUTPUT:?}" "${EVENT_NAME:?}"

ALL_AREAS='["security","privacy","compliance","ai-compliance","error-handling","code-quality","performance","testing","documentation","dependency-health","correctness","e-commerce","infrastructure","architecture","resilience"]'

if [[ "${EVENT_NAME}" = "workflow_dispatch" ]]; then
  AREA="${INPUT_REVIEW_AREA:-security}"
  if [[ "${AREA}" = "all" ]]; then
    echo "areas_json=${ALL_AREAS}" >> "${GITHUB_OUTPUT}"
  else
    echo "areas_json=[\"${AREA}\"]" >> "${GITHUB_OUTPUT}"
  fi
else
  # Schedule trigger: run all areas at once (Sunday morning)
  echo "areas_json=${ALL_AREAS}" >> "${GITHUB_OUTPUT}"
fi
