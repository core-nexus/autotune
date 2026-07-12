# Pipeline shell-script tests

Bats test suite for the four scripts under `.github/workflows/scripts/`, which
are the only executable logic in this repository and hold the control flow that
decides whether the auto-fix stage runs. A silent parse/branch regression there
would make the pipeline look healthy while doing nothing, so these scripts are
worth testing.

The tests exercise the real scripts end-to-end. The only thing stubbed is `gh`
(a genuine external boundary — the GitHub CLI / network); all parsing, branching
and JSON construction runs for real.

## Running locally

```sh
sudo apt-get install -y bats shellcheck   # once
bats tests/scripts/
shellcheck .github/workflows/scripts/*.sh
```

## Coverage

| Script | Cases |
| --- | --- |
| `resolve-review-area.sh` | `workflow_dispatch`+area, `+all`, default area, `schedule`, JSON validity (`jq -e`), required-env guards |
| `extract-review-priority.sh` | execution-file path, `gh issue list` fallback, NONE default, required-env guards, multi-marker regression |
| `extract-pr-review-priority.sh` | latest-comment extraction, NONE default, empty-`gh` default, required-env guards, multi-marker regression |
| `trigger-ci-workflows.sh` | dispatch of each configured workflow, graceful skip of non-dispatchable workflows, default workflow list, required-env guards |

## Known-blocked items

Two items from the testing review live under `.github/workflows/` and could
**not** be committed by the review-bot token, which lacks GitHub `workflows`
write permission (`refusing to allow a GitHub App to create or update workflow`).
Their diffs are in the PR body for a maintainer to apply:

1. The one-line `| tail -1` fix in `extract-review-priority.sh` and
   `extract-pr-review-priority.sh` (finding 2 — multiline priority output).
   The two `skip`-gated regression tests in this suite guard it; remove the
   `skip` lines once the fix lands.
2. A `shell-ci.yml` workflow that runs `shellcheck` + this suite on pull
   requests (finding 3).
