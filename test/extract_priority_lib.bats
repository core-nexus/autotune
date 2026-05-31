#!/usr/bin/env bats
# Tests for the shared priority-extraction helper.

load helpers

setup() {
  # shellcheck source=../scripts/lib/extract-priority.sh
  source "${LIB_DIR}/extract-priority.sh"
  setup_tmp
}

teardown() { teardown_tmp; }

@test "single verdict line yields that value" {
  result=$(printf 'preamble\nMAXIMUM_FIX_PRIORITY:MEDIUM\n' | extract_priority_from_text)
  [ "${result}" = "MEDIUM" ]
}

@test "no verdict in input defaults to NONE" {
  result=$(printf 'no verdict here at all\n' | extract_priority_from_text)
  [ "${result}" = "NONE" ]
}

@test "empty input defaults to NONE" {
  result=$(printf '' | extract_priority_from_text)
  [ "${result}" = "NONE" ]
}

@test "example block alone (NONE,XLOW,LOW,MEDIUM,HIGH) is excluded" {
  # The literal value menu from codebase-review.yml — must not surface as HIGH.
  result=$(printf 'MAXIMUM_FIX_PRIORITY:NONE\nMAXIMUM_FIX_PRIORITY:XLOW\nMAXIMUM_FIX_PRIORITY:LOW\nMAXIMUM_FIX_PRIORITY:MEDIUM\nMAXIMUM_FIX_PRIORITY:HIGH\n' \
    | extract_priority_from_text)
  [ "${result}" = "NONE" ]
}

@test "verdict before example block survives (the order-dependent tail -1 bug)" {
  # Reproduces the bug from issue 88, item 3: verdict NONE precedes the
  # prompt's example menu in the transcript. tail -1 returned HIGH.
  result=$(printf 'MAXIMUM_FIX_PRIORITY:NONE\n\nfindings preamble\n\nMAXIMUM_FIX_PRIORITY:NONE\nMAXIMUM_FIX_PRIORITY:XLOW\nMAXIMUM_FIX_PRIORITY:LOW\nMAXIMUM_FIX_PRIORITY:MEDIUM\nMAXIMUM_FIX_PRIORITY:HIGH\n' \
    | extract_priority_from_text)
  [ "${result}" = "NONE" ]
}

@test "example block before verdict returns the verdict" {
  result=$(printf 'MAXIMUM_FIX_PRIORITY:NONE\nMAXIMUM_FIX_PRIORITY:XLOW\nMAXIMUM_FIX_PRIORITY:LOW\nMAXIMUM_FIX_PRIORITY:MEDIUM\nMAXIMUM_FIX_PRIORITY:HIGH\n\nactual verdict:\nMAXIMUM_FIX_PRIORITY:LOW\n' \
    | extract_priority_from_text)
  [ "${result}" = "LOW" ]
}

@test "multiple separated verdicts: last wins" {
  # Reproduces the multi-match bug from item 3 / item 5: two separate
  # `MAXIMUM_FIX_PRIORITY:` lines used to produce a multi-line value
  # that corrupted GITHUB_OUTPUT.
  result=$(printf 'MAXIMUM_FIX_PRIORITY:MEDIUM\nbetween\nMAXIMUM_FIX_PRIORITY:HIGH\n' \
    | extract_priority_from_text)
  [ "${result}" = "HIGH" ]
}

@test "invalid token (BANANA) is ignored" {
  # Reproduces item 3's "no value validation" issue: garbage tokens
  # used to pass through. The pattern now refuses them.
  result=$(printf 'MAXIMUM_FIX_PRIORITY:BANANA\n' | extract_priority_from_text)
  [ "${result}" = "NONE" ]
}

@test "invalid token before a valid verdict does not poison output" {
  result=$(printf 'MAXIMUM_FIX_PRIORITY:BANANA\nMAXIMUM_FIX_PRIORITY:LOW\n' \
    | extract_priority_from_text)
  [ "${result}" = "LOW" ]
}

@test "verdict embedded in a non-anchored line is ignored" {
  # Inline mentions like "use MAXIMUM_FIX_PRIORITY:HIGH for ..." should
  # not match — only standalone verdict lines do.
  result=$(printf 'see also: MAXIMUM_FIX_PRIORITY:HIGH for details\n' \
    | extract_priority_from_text)
  [ "${result}" = "NONE" ]
}

@test "validate_priority accepts each allowed value verbatim" {
  for v in NONE XLOW LOW MEDIUM HIGH; do
    [ "$(validate_priority "${v}")" = "${v}" ]
  done
}

@test "validate_priority rejects unknown tokens" {
  [ "$(validate_priority "BANANA")" = "NONE" ]
  [ "$(validate_priority "")" = "NONE" ]
  [ "$(validate_priority "medium")" = "NONE" ]
}

@test "write_priority_output writes exactly one priority= line" {
  write_priority_output "MEDIUM" > /dev/null
  assert_github_output_lines 1
  [ "$(get_output_value priority)" = "MEDIUM" ]
}

@test "write_priority_output sanitises unknown tokens to NONE" {
  write_priority_output "BANANA" > /dev/null
  assert_github_output_lines 1
  [ "$(get_output_value priority)" = "NONE" ]
}

@test "extract_priority_from_file: missing file returns NONE" {
  result=$(extract_priority_from_file "${TMP_DIR}/does-not-exist")
  [ "${result}" = "NONE" ]
}

@test "extract_priority_from_file: empty path returns NONE" {
  result=$(extract_priority_from_file "")
  [ "${result}" = "NONE" ]
}

@test "extract_priority_from_file: reads a real file" {
  printf 'MAXIMUM_FIX_PRIORITY:HIGH\n' > "${TMP_DIR}/exec"
  result=$(extract_priority_from_file "${TMP_DIR}/exec")
  [ "${result}" = "HIGH" ]
}
