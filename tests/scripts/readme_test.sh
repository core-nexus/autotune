#!/usr/bin/env bash
# README invariants — the closest thing to an end-to-end install test we
# can run inside this repo. Every script and workflow filename the README
# tells users to copy or edit must actually exist.

set -euo pipefail

README="${REPO_ROOT}/README.md"

# Files the README's install instructions explicitly reference. If a file
# named here is renamed without updating the README, this test fails.
EXPECTED_FILES=(
  ".github/review-prompts/security.md"
  ".github/review-prompts/code-quality.md"
  ".github/review-prompts/performance.md"
  ".github/review-prompts/testing.md"
  ".github/review-prompts/error-handling.md"
  ".github/review-prompts/correctness.md"
  ".github/review-prompts/privacy.md"
  ".github/review-prompts/compliance.md"
  ".github/review-prompts/ai-compliance.md"
  ".github/review-prompts/documentation.md"
  ".github/review-prompts/dependency-health.md"
  ".github/review-prompts/e-commerce.md"
  ".github/workflows/codebase-review.yml"
  ".github/workflows/claude-pr-review.yml"
  ".github/workflows/scripts/resolve-review-area.sh"
  ".github/workflows/scripts/extract-review-priority.sh"
  ".github/workflows/scripts/extract-pr-review-priority.sh"
  ".github/workflows/scripts/trigger-ci-workflows.sh"
)

test_all_documented_files_exist() {
  local missing=()
  for f in "${EXPECTED_FILES[@]}"; do
    if [[ ! -f "${REPO_ROOT}/${f}" ]]; then
      missing+=("${f}")
    fi
  done
  if (( ${#missing[@]} > 0 )); then
    printf '    Missing files referenced by README:\n' >&2
    printf '      - %s\n' "${missing[@]}" >&2
    return 1
  fi
}

test_readme_mentions_each_review_area() {
  # The "Review Areas" table in the README should mention every area name
  # we have a prompt file for. If we add a new prompt but forget to
  # document it, this test fails.
  local areas a
  areas=$(find "${GITHUB_DIR}/review-prompts" -maxdepth 1 -name '*.md' -printf '%f\n' \
    | sed 's/\.md$//' | sort -u)
  local missing=()
  while IFS= read -r a; do
    if ! grep -q "\\*\\*${a}\\*\\*" "${README}"; then
      missing+=("${a}")
    fi
  done <<< "${areas}"
  if (( ${#missing[@]} > 0 )); then
    printf '    README does not mention these review areas in **bold** form:\n' >&2
    printf '      - %s\n' "${missing[@]}" >&2
    return 1
  fi
}

test_codebase_review_yaml_focus_area_count() {
  # codebase-review.yml has a header comment claiming a count of focus
  # areas. Surface drift as a ::warning::, but do not fail the test —
  # updating the workflow file requires the GitHub `workflows` permission
  # which the auto-fix bot does not hold. The signal is enough to nudge a
  # human; the assertion can be made strict once the bot has the right.
  local wf="${WORKFLOWS_DIR}/codebase-review.yml"
  local script="${SCRIPTS_DIR}/resolve-review-area.sh"
  local actual_count claimed_count
  actual_count=$(grep -oP "ALL_AREAS='\K[^']+" "${script}" | jq 'length')
  claimed_count=$(grep -oP 'across \K[0-9]+(?= focus areas)' "${wf}" | head -1 || true)
  if [[ -z "${claimed_count}" ]]; then
    return 0
  fi
  if [[ "${actual_count}" != "${claimed_count}" ]]; then
    printf '    ::warning::codebase-review.yml comment says %s focus areas but ALL_AREAS has %s — update the header comment.\n' \
      "${claimed_count}" "${actual_count}" >&2
  fi
}
