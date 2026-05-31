#!/usr/bin/env bash
# Shared helper for extracting MAXIMUM_FIX_PRIORITY verdicts from text.
#
# Source this file; do not execute it directly. Exposes:
#   extract_priority_from_text  — reads text from stdin, prints verdict
#   extract_priority_from_file  — reads from a file path, prints verdict
#   write_priority_output       — writes a single, validated priority= line
#                                 to $GITHUB_OUTPUT
#
# The verdict is the LAST line of the form `^MAXIMUM_FIX_PRIORITY:VALUE$`
# where VALUE is one of {NONE, XLOW, LOW, MEDIUM, HIGH}, EXCLUDING the
# prompt's own example block — five consecutive lines in the exact order
# NONE/XLOW/LOW/MEDIUM/HIGH that appear in codebase-review.yml and
# claude-pr-review.yml as the value menu shown to the model. Without that
# exclusion, `tail -1` returns HIGH from the prompt's menu whenever it
# appears after the verdict in the execution transcript.
#
# Unknown or missing values resolve to NONE (the safest default — it
# skips the expensive fix stage rather than running it on bad input).

# Allowed priority values, in their canonical example-block order.
PRIORITY_EXAMPLE_BLOCK="NONE XLOW LOW MEDIUM HIGH"
PRIORITY_VALID_RE='^(NONE|XLOW|LOW|MEDIUM|HIGH)$'

extract_priority_from_text() {
  awk -v example="${PRIORITY_EXAMPLE_BLOCK}" '
    BEGIN {
      n_examples = split(example, ex_arr, " ")
      result = "NONE"
      buf_n = 0
    }
    function flush_buffer(   i, is_example_block, joined) {
      if (buf_n == 0) return
      is_example_block = 0
      if (buf_n == n_examples) {
        is_example_block = 1
        for (i = 1; i <= n_examples; i++) {
          if (buf[i] != ex_arr[i]) { is_example_block = 0; break }
        }
      }
      if (!is_example_block) {
        result = buf[buf_n]
      }
      buf_n = 0
      delete buf
    }
    /^MAXIMUM_FIX_PRIORITY:(NONE|XLOW|LOW|MEDIUM|HIGH)$/ {
      v = $0
      sub(/^MAXIMUM_FIX_PRIORITY:/, "", v)
      buf[++buf_n] = v
      next
    }
    { flush_buffer() }
    END {
      flush_buffer()
      print result
    }
  '
}

extract_priority_from_file() {
  local file="$1"
  if [[ -z "${file}" ]] || [[ ! -f "${file}" ]]; then
    echo "NONE"
    return
  fi
  extract_priority_from_text < "${file}"
}

# validate_priority VALUE — echoes VALUE if it matches the allowed set,
# otherwise echoes NONE. Used as a final sanity gate before writing the
# value to $GITHUB_OUTPUT, so a typo or upstream regression in the
# extractor never reaches the workflow's `if` condition.
validate_priority() {
  local v="$1"
  if [[ "${v}" =~ ${PRIORITY_VALID_RE} ]]; then
    echo "${v}"
  else
    echo "NONE"
  fi
}

# write_priority_output VALUE — appends exactly one `priority=VALUE` line
# to $GITHUB_OUTPUT (after validation). Centralised here so the two
# extractor scripts cannot diverge on output formatting.
write_priority_output() {
  local v
  v=$(validate_priority "$1")
  : "${GITHUB_OUTPUT:?GITHUB_OUTPUT must be set}"
  printf 'priority=%s\n' "${v}" >> "${GITHUB_OUTPUT}"
  echo "${v}"
}
