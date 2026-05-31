#!/usr/bin/env bash
set -euo pipefail

# Trigger CI workflows on a given branch via workflow_dispatch.
#
# Required env vars:
#   GH_TOKEN
#   REPO - GitHub repository (owner/repo)
#   BRANCH - branch name to trigger on
#
# Optional env vars:
#   WORKFLOWS - space-separated list of workflow filenames (default: auto-detect)
#
# If WORKFLOWS is not set, this script will attempt to trigger common CI
# workflow names. Customize the WORKFLOWS variable for your project.
#
# Failure semantics:
#   - A workflow that does not exist on the branch is a benign skip (warning).
#   - ANY other failure (auth, network, permission, invalid ref) is surfaced
#     loudly. We do NOT collapse such failures into the "not found" message —
#     doing so would let a misconfigured PR open without any CI running.
#   - If zero workflows were dispatched, emit a ::warning:: so the absence of
#     CI on an auto-fix PR is visible rather than silent.

: "${GH_TOKEN:?}" "${REPO:?}" "${BRANCH:?}"

# Default: try common CI workflow names. Override with WORKFLOWS env var.
WORKFLOWS="${WORKFLOWS:-ci.yml checks.yml test.yml}"

DISPATCHED=0
HARD_FAILURES=0

echo "Triggering CI workflows on branch: ${BRANCH}"
for workflow in ${WORKFLOWS}; do
  echo "  -> ${workflow}"
  GH_STDERR=$(mktemp)
  # Run gh and capture both exit code and stderr. Tolerate non-zero so we can
  # branch on the kind of failure rather than aborting the whole loop.
  if gh workflow run "${workflow}" --ref "${BRANCH}" --repo "${REPO}" 2>"${GH_STDERR}"; then
    DISPATCHED=$((DISPATCHED + 1))
    echo "    dispatched"
  else
    GH_EXIT=$?
    STDERR_CONTENT=$(cat "${GH_STDERR}")
    # `gh workflow run` returns this message when the workflow file is absent
    # on the target ref. Treat that — and only that — as a benign skip.
    if [[ "${STDERR_CONTENT}" == *"could not find any workflows"* ]] \
        || [[ "${STDERR_CONTENT}" == *"Workflow does not exist"* ]] \
        || [[ "${STDERR_CONTENT}" == *"HTTP 404"* ]]; then
      echo "    skipped: ${workflow} not present on ${BRANCH}"
    else
      HARD_FAILURES=$((HARD_FAILURES + 1))
      echo "::error::gh workflow run failed for ${workflow} (exit ${GH_EXIT})"
      echo "--- gh stderr ---"
      echo "${STDERR_CONTENT}"
      echo "--- end gh stderr ---"
    fi
  fi
  rm -f "${GH_STDERR}"
done

echo "Dispatched ${DISPATCHED} workflow(s); ${HARD_FAILURES} hard failure(s)."

if (( DISPATCHED == 0 )); then
  echo "::warning::No CI workflows were dispatched on ${BRANCH}. The auto-fix PR may merge without CI signal."
fi

# Surface auth/network/permission failures by exiting non-zero. The "not
# found" skip path does NOT count toward this — only genuine errors do.
if (( HARD_FAILURES > 0 )); then
  echo "::error::${HARD_FAILURES} workflow trigger(s) failed for non-benign reasons."
  exit 1
fi
