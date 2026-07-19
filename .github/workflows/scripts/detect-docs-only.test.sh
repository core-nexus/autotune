#!/usr/bin/env bash
# Tests for detect-docs-only.sh — the classifier that decides whether a PR's
# changed-file list is "docs-only" (safe to skip the full lint/test/build/e2e
# suite) or contains real code (must run everything).
#
# The script reads changed filenames from stdin (one per line) and prints
# `true` (run the full suite) or `false` (docs-only, skip). Tests pipe fixture
# file lists in and assert the printed verdict.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_SCRIPT="${SCRIPT_DIR}/detect-docs-only.sh"

PASS=0
FAIL=0
FAILED_TESTS=()

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "${expected}" == "${actual}" ]]; then
    PASS=$((PASS + 1))
    echo "  ✓ ${label}"
  else
    FAIL=$((FAIL + 1))
    FAILED_TESTS+=("${label}")
    echo "  ✗ ${label}"
    echo "    expected: ${expected}"
    echo "    actual:   ${actual}"
  fi
}

# Pipe a newline-separated file list into the classifier and capture its verdict.
run_classifier() {
  printf '%s' "$1" | bash "${TARGET_SCRIPT}"
}

# --- docs-only cases: expect `false` (skip the suite) -----------------------

test_single_markdown() {
  echo "test_single_markdown"
  assert_eq "one .md file → false" "false" "$(run_classifier 'README.md')"
}

test_doc_directory() {
  echo "test_doc_directory"
  assert_eq "doc/ tree → false" "false" "$(run_classifier 'doc/guides/foo.md
doc/architecture/system-diagram.html')"
}

test_docs_directory() {
  echo "test_docs_directory"
  assert_eq "docs/ tree → false" "false" "$(run_classifier 'docs/index.html')"
}

test_doc_html_and_txt() {
  echo "test_doc_html_and_txt"
  assert_eq "doc .html + .txt → false" "false" "$(run_classifier 'doc/reports/week.html
notes.txt')"
}

test_license() {
  echo "test_license"
  assert_eq "LICENSE + LICENSE.md → false" "false" "$(run_classifier 'LICENSE
LICENSE.md')"
}

test_mixed_docs_only() {
  echo "test_mixed_docs_only"
  assert_eq "md + doc html + txt + LICENSE → false" "false" "$(run_classifier 'README.md
doc/architecture/data-model.html
CHANGES.txt
LICENSE')"
}

# --- code cases: expect `true` (run the full suite) -------------------------

test_source_file() {
  echo "test_source_file"
  assert_eq "one source file → true" "true" "$(run_classifier 'src/index.ts')"
}

test_component_file() {
  echo "test_component_file"
  assert_eq "one component file → true" "true" "$(run_classifier 'src/components/Button.tsx')"
}

test_mixed_doc_and_code() {
  echo "test_mixed_doc_and_code"
  # A PR mixing docs with any code file must run the full suite.
  assert_eq "md + source → true" "true" "$(run_classifier 'README.md
src/lib/billing.ts')"
}

test_app_shell_html_is_code() {
  echo "test_app_shell_html_is_code"
  # src/app.html is an app shell — real app code despite the .html extension.
  # It must NOT be treated as docs-only.
  assert_eq "src/app.html → true" "true" "$(run_classifier 'src/app.html')"
}

test_src_html_is_code() {
  echo "test_src_html_is_code"
  # Any .html under src/ (e.g. a framework error page src/error.html) is app code.
  assert_eq "src/error.html → true" "true" "$(run_classifier 'src/error.html')"
}

test_workflow_yaml_is_code() {
  echo "test_workflow_yaml_is_code"
  # CI config changes must run the suite — a broken workflow is a real defect.
  assert_eq "workflow .yml → true" "true" "$(run_classifier '.github/workflows/ci.yml')"
}

test_empty_input_is_safe() {
  echo "test_empty_input_is_safe"
  # No files (degenerate / API returned nothing) → fail safe, run the suite.
  assert_eq "empty input → true" "true" "$(run_classifier '')"
}

# --- Run --------------------------------------------------------------------

test_single_markdown
test_doc_directory
test_docs_directory
test_doc_html_and_txt
test_license
test_mixed_docs_only
test_source_file
test_component_file
test_mixed_doc_and_code
test_app_shell_html_is_code
test_src_html_is_code
test_workflow_yaml_is_code
test_empty_input_is_safe

echo
echo "Results: ${PASS} passed, ${FAIL} failed"
if (( FAIL > 0 )); then
  echo "Failed tests:"
  for t in "${FAILED_TESTS[@]}"; do
    echo "  - ${t}"
  done
  exit 1
fi
exit 0
