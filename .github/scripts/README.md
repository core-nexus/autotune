# Review helper scripts

These are the fixed versions of the codebase-review helper scripts, addressing
the error-handling review findings (issue: `review(error-handling): findings`).

## Why these live in `.github/scripts/` instead of `.github/workflows/scripts/`

The automated **fix** job runs as the `claude[bot]` GitHub App with
`contents: write` but **not** `workflows: write`. GitHub refuses to let an App
token create or update *any* path under `.github/workflows/` without that
permission — including the `scripts/` subdirectory. Because every file the
error-handling review flagged lives under `.github/workflows/`, the fix job
literally cannot push its own corrections in place, and the push fails with:

```
refusing to allow a GitHub App to create or update workflow
`.github/workflows/scripts/...` without `workflows` permission
```

Worse, that push failure is currently **silent** — exactly the class of
"invisible failure" this review targets.

To still deliver the fixes, the corrected scripts + tests are placed here (a
pushable path) and the workflow-file edits that can only live under the blocked
path are provided as `workflow-changes.patch`.

## To finish wiring this up (requires `workflows: write`)

A maintainer (or a token with `workflows: write`) should:

1. Apply the workflow edits: `git apply .github/scripts/workflow-changes.patch`
   This repoints the workflow `run:` steps at `.github/scripts/`, adds the
   `notify`-job alerting fix (item M2), and adds `ci.yml`.
2. Remove the now-superseded `.github/workflows/scripts/` directory.
3. Grant the fix job `workflows: write` (or supply a PAT) so future automated
   fixes to workflow-located code can land directly — otherwise this same
   silent-push-failure will recur.

## Tests

`tests/run-tests.sh` is a self-contained bash suite (stubs `gh` on `PATH`) that
covers the error paths of every changed script. Run it directly:

```
.github/scripts/tests/run-tests.sh
```
