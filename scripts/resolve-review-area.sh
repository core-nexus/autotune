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
# Exits non-zero if INPUT_REVIEW_AREA is not "all" and not in ALL_AREAS_LIST,
# so a mistyped workflow_dispatch input fails fast here rather than producing
# a matrix job that later 404s on a missing prompt file.

: "${GITHUB_OUTPUT:?}" "${EVENT_NAME:?}"

ALL_AREAS_LIST=(
  security
  privacy
  compliance
  ai-compliance
  error-handling
  code-quality
  performance
  testing
  documentation
  dependency-health
  correctness
  e-commerce
)

ALL_AREAS_JSON='["security","privacy","compliance","ai-compliance","error-handling","code-quality","performance","testing","documentation","dependency-health","correctness","e-commerce"]'

is_valid_area() {
  local candidate="$1"
  local a
  for a in "${ALL_AREAS_LIST[@]}"; do
    if [[ "${a}" = "${candidate}" ]]; then
      return 0
    fi
  done
  return 1
}

if [[ "${EVENT_NAME}" = "workflow_dispatch" ]]; then
  AREA="${INPUT_REVIEW_AREA:-security}"
  if [[ "${AREA}" = "all" ]]; then
    echo "areas_json=${ALL_AREAS_JSON}" >> "${GITHUB_OUTPUT}"
  elif is_valid_area "${AREA}"; then
    echo "areas_json=[\"${AREA}\"]" >> "${GITHUB_OUTPUT}"
  else
    echo "::error::Unknown review area '${AREA}'. Valid: ${ALL_AREAS_LIST[*]} all" >&2
    exit 1
  fi
else
  # Schedule trigger: run all areas at once (Sunday morning)
  echo "areas_json=${ALL_AREAS_JSON}" >> "${GITHUB_OUTPUT}"
fi
