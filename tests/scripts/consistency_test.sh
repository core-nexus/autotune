#!/usr/bin/env bash
# Configuration consistency tests.
#
# Three sources of truth list the review areas:
#   1. ALL_AREAS in resolve-review-area.sh
#   2. workflow_dispatch.inputs.review_area.options in codebase-review.yml
#   3. The set of *.md files in .github/review-prompts/
#
# This file enforces that they agree. Drift between them silently breaks
# the system: a workflow_dispatch option without a matching prompt file
# would fail at run time when the review step tries to read it.

set -euo pipefail

# Extract the JSON array assigned to ALL_AREAS in resolve-review-area.sh
# and emit each element on its own line, sorted.
_areas_from_script() {
  local script="${SCRIPTS_DIR}/resolve-review-area.sh"
  grep -oP "ALL_AREAS='\K[^']+" "${script}" \
    | jq -r '.[]' \
    | sort -u
}

# Extract the workflow_dispatch.inputs.review_area.options list from the
# codebase-review.yml workflow, dropping the literal "all" sentinel.
_areas_from_workflow() {
  local wf="${WORKFLOWS_DIR}/codebase-review.yml"
  awk '
    /^[[:space:]]+options:[[:space:]]*$/ { in_opts = 1; next }
    in_opts && /^[[:space:]]+-[[:space:]]/ {
      gsub(/^[[:space:]]+-[[:space:]]+/, "")
      print
      next
    }
    in_opts && /^[^[:space:]-]/ { in_opts = 0 }
  ' "${wf}" \
    | grep -v '^all$' \
    | sort -u
}

# Names of every .md file under review-prompts/, sans extension, sorted.
_areas_from_prompt_files() {
  local prompts_dir="${GITHUB_DIR}/review-prompts"
  find "${prompts_dir}" -maxdepth 1 -name '*.md' -printf '%f\n' \
    | sed 's/\.md$//' \
    | sort -u
}

test_all_areas_matches_workflow_options() {
  local script_areas workflow_areas
  script_areas=$(_areas_from_script)
  workflow_areas=$(_areas_from_workflow)
  if [[ "${script_areas}" != "${workflow_areas}" ]]; then
    printf '    ALL_AREAS in resolve-review-area.sh disagrees with workflow_dispatch options:\n' >&2
    diff <(echo "${script_areas}") <(echo "${workflow_areas}") >&2 || true
    return 1
  fi
}

test_all_areas_matches_prompt_files() {
  local script_areas prompt_areas
  script_areas=$(_areas_from_script)
  prompt_areas=$(_areas_from_prompt_files)
  if [[ "${script_areas}" != "${prompt_areas}" ]]; then
    printf '    ALL_AREAS disagrees with .github/review-prompts/*.md filenames:\n' >&2
    diff <(echo "${script_areas}") <(echo "${prompt_areas}") >&2 || true
    return 1
  fi
}

test_workflow_options_matches_prompt_files() {
  local workflow_areas prompt_areas
  workflow_areas=$(_areas_from_workflow)
  prompt_areas=$(_areas_from_prompt_files)
  if [[ "${workflow_areas}" != "${prompt_areas}" ]]; then
    printf '    workflow_dispatch options disagree with prompt files:\n' >&2
    diff <(echo "${workflow_areas}") <(echo "${prompt_areas}") >&2 || true
    return 1
  fi
}

test_each_area_has_nonempty_prompt() {
  local areas a path
  areas=$(_areas_from_script)
  while IFS= read -r a; do
    path="${GITHUB_DIR}/review-prompts/${a}.md"
    if [[ ! -s "${path}" ]]; then
      printf '    Prompt file missing or empty: %s\n' "${path}" >&2
      return 1
    fi
  done <<< "${areas}"
}
