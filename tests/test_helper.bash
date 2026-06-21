# Shared helpers for the script test suites.
#
# These are BLACK-BOX tests: each script is run as a real subprocess with its
# documented env vars, a temp GITHUB_OUTPUT, and (where relevant) a stubbed `gh`
# on PATH. `gh` is the only genuine external boundary in these scripts, so it is
# the only thing stubbed — all parsing/branching logic runs for real.
#
# Tests live outside .github/workflows so they remain editable without the
# `workflows` permission; they reference the scripts there read-only.

# Repo root = parent of tests/. The path vars below are consumed by the .bats
# files that source this helper, so shellcheck cannot see their use here.
# shellcheck disable=SC2034
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC2034
SCRIPTS_DIR="${REPO_ROOT}/.github/workflows/scripts"
# shellcheck disable=SC2034
WORKFLOW_YAML="${REPO_ROOT}/.github/workflows/codebase-review.yml"

# Install a fake `gh` on PATH that echoes scripted output and records calls.
#   GH_STUB_OUT - file whose contents `gh` prints to stdout (optional)
#   GH_STUB_RC  - exit code `gh` returns (default 0)
#   GH_STUB_LOG - file each invocation's args are appended to (set by this fn)
use_gh_stub() {
  STUB_DIR="$(mktemp -d)"
  cat > "${STUB_DIR}/gh" <<'EOF'
#!/usr/bin/env bash
if [[ -n "${GH_STUB_LOG:-}" ]]; then
  printf '%s\n' "$*" >> "${GH_STUB_LOG}"
fi
if [[ -n "${GH_STUB_OUT:-}" ]]; then
  cat "${GH_STUB_OUT}"
fi
exit "${GH_STUB_RC:-0}"
EOF
  chmod +x "${STUB_DIR}/gh"
  PATH="${STUB_DIR}:${PATH}"
  export PATH
  GH_STUB_LOG="$(mktemp)"
  export GH_STUB_LOG
}

teardown_gh_stub() {
  [[ -n "${STUB_DIR:-}" ]] && rm -rf "${STUB_DIR}"
  [[ -n "${GH_STUB_LOG:-}" ]] && rm -f "${GH_STUB_LOG}"
  [[ -n "${GH_STUB_OUT:-}" ]] && rm -f "${GH_STUB_OUT}"
  unset GH_STUB_OUT GH_STUB_RC GH_STUB_LOG STUB_DIR
  return 0
}

# Write content to a temp file and echo its path.
make_tmpfile() {
  local f
  f="$(mktemp)"
  printf '%s' "$1" > "${f}"
  printf '%s' "${f}"
}

# Read the value of `priority=` written to a GITHUB_OUTPUT file.
output_priority() {
  grep -oP '^priority=\K.*' "$1" | tail -1
}

# Read the value of `areas_json=` written to a GITHUB_OUTPUT file.
output_areas_json() {
  grep -oP '^areas_json=\K.*' "$1" | tail -1
}
