#!/usr/bin/env bats
#
# Black-box tests for resolve-review-area.sh — the script that decides the entire
# review/fix job matrix. A regression could explode one requested area into all
# twelve (12x cost) or collapse the scheduled run to one (silently dropping 11
# weekly reviews), and the output is only ever consumed by fromJson() in the
# matrix, never surfaced to a human.

load test_helper

SCRIPT="${SCRIPTS_DIR}/resolve-review-area.sh"

setup() { OUT="$(mktemp)"; }
teardown() { rm -f "${OUT}"; return 0; }

# The canonical full list, read once from the script's schedule branch so the
# expectations track the source of truth rather than duplicating it.
all_areas_json() {
  local out; out="$(mktemp)"
  GITHUB_OUTPUT="${out}" EVENT_NAME="schedule" bash "${SCRIPT}" >/dev/null
  output_areas_json "${out}"
  rm -f "${out}"
}

@test "workflow_dispatch + all → every area" {
  GITHUB_OUTPUT="${OUT}" EVENT_NAME="workflow_dispatch" INPUT_REVIEW_AREA="all" run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(output_areas_json "${OUT}")" = "$(all_areas_json)" ]
}

@test "workflow_dispatch + single area → just that area" {
  GITHUB_OUTPUT="${OUT}" EVENT_NAME="workflow_dispatch" INPUT_REVIEW_AREA="performance" run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(output_areas_json "${OUT}")" = '["performance"]' ]
}

@test "workflow_dispatch + unset input → defaults to security only" {
  GITHUB_OUTPUT="${OUT}" EVENT_NAME="workflow_dispatch" run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(output_areas_json "${OUT}")" = '["security"]' ]
}

@test "schedule → every area" {
  GITHUB_OUTPUT="${OUT}" EVENT_NAME="schedule" run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(output_areas_json "${OUT}")" = "$(all_areas_json)" ]
}

@test "non-dispatch event (e.g. push) → every area" {
  GITHUB_OUTPUT="${OUT}" EVENT_NAME="push" run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(output_areas_json "${OUT}")" = "$(all_areas_json)" ]
}

@test "output is a valid JSON array consumable by fromJson()" {
  GITHUB_OUTPUT="${OUT}" EVENT_NAME="workflow_dispatch" INPUT_REVIEW_AREA="all" run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  echo "$(output_areas_json "${OUT}")" | jq -e 'type == "array" and length == 12' >/dev/null
}

@test "aborts when EVENT_NAME is unset" {
  GITHUB_OUTPUT="${OUT}" run bash "${SCRIPT}"
  [ "$status" -ne 0 ]
}

@test "aborts when GITHUB_OUTPUT is unset" {
  run env -u GITHUB_OUTPUT EVENT_NAME="schedule" bash "${SCRIPT}"
  [ "$status" -ne 0 ]
}

# ─── drift guard ───────────────────────────────────────────────────────────

@test "area list matches the workflow_dispatch review_area options (minus 'all')" {
  script_areas="$(all_areas_json | jq -r '.[]' | sort)"

  # Extract the indented "- <area>" items under the `options:` key in the YAML,
  # stopping at the next non-list line. Excludes the synthetic "all" option.
  yaml_areas="$(awk '
    /^[[:space:]]*options:/ { f=1; next }
    f {
      if ($0 ~ /^[[:space:]]*-[[:space:]]/) { s=$0; sub(/^[[:space:]]*-[[:space:]]*/, "", s); print s }
      else { f=0 }
    }' "${WORKFLOW_YAML}" | grep -v '^all$' | sort)"

  [ -n "$script_areas" ]
  [ -n "$yaml_areas" ]
  [ "$script_areas" = "$yaml_areas" ]
}
