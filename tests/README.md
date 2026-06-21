# Tests

Unit tests for the automation shell scripts in
[`.github/workflows/scripts/`](../.github/workflows/scripts/). These scripts gate
the entire review/fix pipeline and are copied verbatim into downstream repos (see
the root `README.md`), so a regression here ships to every adopter — yet they had
no test coverage of any kind. This suite closes that gap.

## What's covered

| Script | Suite | Key behaviours pinned |
|---|---|---|
| `extract-review-priority.sh` | `extract-review-priority.bats` | execution-file parsing, **`tail -1` selects the real trailing value** when a body enumerates every priority, uppercase-token isolation, all five canonical values, `gh issue list` fallback, empty/failed `gh` → `NONE` |
| `extract-pr-review-priority.sh` | `extract-pr-review-priority.bats` | latest-comment parsing, token isolation, `NONE` default on no comment / `gh` failure |
| `resolve-review-area.sh` | `resolve-review-area.bats` | dispatch+all, dispatch+single, dispatch+unset → `security`, schedule → all, non-dispatch → all, valid-JSON output, **drift guard** asserting the area list matches the `workflow_dispatch` options in `codebase-review.yml` |
| `trigger-ci-workflows.sh` | `trigger-ci-workflows.bats` | one dispatch per workflow, a missing workflow doesn't abort the rest, default workflow names |

Every suite also asserts the scripts abort when a required env var is unset.

## Design

These are **black-box** tests: each script runs as a real subprocess with its
documented env vars and a temporary `GITHUB_OUTPUT`. The only thing stubbed is
`gh` — the scripts' sole external boundary — via a fake `gh` placed on `PATH`
(see `test_helper.bash`). All parsing and branching logic executes for real; no
internal function is mocked.

## Running

Requires [`bats`](https://github.com/bats-core/bats-core), `jq`, and GNU `grep`
(for `grep -oP`, matching the scripts).

```bash
# Ubuntu / Debian
sudo apt-get install -y bats jq

# From the repo root:
bats tests/

# Lint the scripts too:
shellcheck .github/workflows/scripts/*.sh tests/*.bash
```

## Recommended CI gate (requires maintainer action)

The repository has **no CI** running these tests or `shellcheck`. A workflow to
add this gate is proposed in the accompanying pull request body. It could not be
committed here because the automation's GitHub App token lacks the `workflows`
permission, which is required to create or modify any file under
`.github/workflows/`. A maintainer should add it manually.
