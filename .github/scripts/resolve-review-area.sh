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

# Canonical list of review areas. Keep this in sync with the prompts under
# .github/review-prompts/ and the workflow_dispatch choices in
# codebase-review.yml.
ALL_AREAS=(
  security privacy compliance ai-compliance error-handling code-quality
  performance testing documentation dependency-health correctness e-commerce
)

# Render ALL_AREAS as a JSON array string (the form the build matrix expects).
all_areas_json() {
  local out="" area
  for area in "${ALL_AREAS[@]}"; do
    out+="\"${area}\","
  done
  printf '[%s]' "${out%,}"
}

# Emit the resolved matrix to the step output.
emit_areas() {
  echo "areas_json=$1" >> "${GITHUB_OUTPUT}"
}

if [[ "${EVENT_NAME}" = "workflow_dispatch" ]]; then
  AREA="${INPUT_REVIEW_AREA:-security}"
  if [[ "${AREA}" = "all" ]]; then
    emit_areas "$(all_areas_json)"
  else
    # Validate against the known areas so a typo (or empty input) fails fast
    # with a clear message, rather than producing a matrix entry that points
    # at a non-existent review prompt and reviews nothing.
    valid=false
    for known in "${ALL_AREAS[@]}"; do
      if [[ "${AREA}" = "${known}" ]]; then
        valid=true
        break
      fi
    done
    if [[ "${valid}" != true ]]; then
      echo "Unknown review area: '${AREA}'. Valid areas: ${ALL_AREAS[*]} all" >&2
      exit 1
    fi
    emit_areas "[\"${AREA}\"]"
  fi
else
  # Schedule trigger: run all areas at once (Sunday morning)
  emit_areas "$(all_areas_json)"
fi
