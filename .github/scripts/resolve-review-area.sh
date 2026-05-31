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
#
# Fails fast with an explicit message if INPUT_REVIEW_AREA is not a recognised
# area. The workflow_dispatch `choice` input already constrains the UI, but
# REST-API dispatch bypasses that constraint, so this validation is required
# to avoid a downstream review step failing with an opaque
# "review-prompts/<typo>.md not found" error.

: "${GITHUB_OUTPUT:?}" "${EVENT_NAME:?}"

ALL_AREAS_BASH=(security privacy compliance ai-compliance error-handling code-quality performance testing documentation dependency-health correctness e-commerce)
ALL_AREAS_JSON='["security","privacy","compliance","ai-compliance","error-handling","code-quality","performance","testing","documentation","dependency-health","correctness","e-commerce"]'

is_known_area() {
  local candidate="$1"
  local area
  for area in "${ALL_AREAS_BASH[@]}"; do
    if [[ "${candidate}" = "${area}" ]]; then
      return 0
    fi
  done
  return 1
}

if [[ "${EVENT_NAME}" = "workflow_dispatch" ]]; then
  AREA="${INPUT_REVIEW_AREA:-security}"
  if [[ "${AREA}" = "all" ]]; then
    echo "areas_json=${ALL_AREAS_JSON}" >> "${GITHUB_OUTPUT}"
  else
    if ! is_known_area "${AREA}"; then
      echo "::error::Unknown review area: '${AREA}'. Expected one of: ${ALL_AREAS_BASH[*]} (or 'all')." >&2
      exit 1
    fi
    # Also sanity-check that the prompt file actually exists. The known-area
    # list and the file set should stay in sync; if they ever drift, fail
    # here rather than deep inside the review step.
    PROMPT_FILE=".github/review-prompts/${AREA}.md"
    if [[ ! -f "${PROMPT_FILE}" ]]; then
      echo "::error::Review prompt file missing: ${PROMPT_FILE}" >&2
      exit 1
    fi
    echo "areas_json=[\"${AREA}\"]" >> "${GITHUB_OUTPUT}"
  fi
else
  # Schedule trigger: run all areas at once (Sunday morning)
  echo "areas_json=${ALL_AREAS_JSON}" >> "${GITHUB_OUTPUT}"
fi
