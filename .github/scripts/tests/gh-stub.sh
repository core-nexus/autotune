#!/usr/bin/env bash
# Configurable `gh` test double for the script tests. Behavior is driven by env
# vars set by each test case; every invocation is appended to $GH_STUB_LOG so
# tests can assert on which subcommands were called.
set -uo pipefail

echo "gh $*" >> "${GH_STUB_LOG:-/dev/null}"

cmd="${1:-}"
sub="${2:-}"

case "${cmd}" in
  issue)
    case "${sub}" in
      list)
        if [[ "${GH_ISSUE_LIST_FAIL:-0}" == "1" ]]; then
          echo "gh: simulated API error (issue list)" >&2
          exit 1
        fi
        printf '%s' "${GH_ISSUE_LIST_OUT:-}"
        exit 0
        ;;
      comment)
        exit 0
        ;;
      create)
        echo "https://github.com/o/r/issues/999"
        exit 0
        ;;
    esac
    ;;
  api)
    if [[ "${GH_API_FAIL:-0}" == "1" ]]; then
      echo "gh: simulated API error (api)" >&2
      exit 1
    fi
    printf '%s' "${GH_API_OUT:-}"
    exit 0
    ;;
  label)
    exit 0
    ;;
  pr)
    # pr comment
    exit 0
    ;;
  workflow)
    # workflow run <name> --ref <branch> --repo <repo>
    wf="${3:-}"
    case "${GH_WORKFLOW_MODE:-success}" in
      success) exit 0 ;;
      notfound) echo "could not find any workflows named ${wf}" >&2; exit 1 ;;
      autherror) echo "HTTP 401: Bad credentials" >&2; exit 1 ;;
    esac
    ;;
esac

exit 0
