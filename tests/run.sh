#!/usr/bin/env bash
set -euo pipefail

# Local quality gate for the pipeline's shell scripts: shellcheck + bats.
#
# This mirrors what a CI job would run. A CI workflow could not be committed
# from the automated review/fix flow because the GitHub App lacks `workflows`
# permission to add files under .github/workflows/. A maintainer can wire this
# script into CI (e.g. `run: tests/run.sh`).
#
# Usage: tests/run.sh

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

echo "== shellcheck =="
shellcheck .github/workflows/scripts/*.sh tests/stubs/gh tests/test_helper.bash

echo "== bats =="
bats tests/

echo "All checks passed."
