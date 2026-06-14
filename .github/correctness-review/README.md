# Pending workflow correctness fix — 2026-06-14

The correctness review (`review(correctness): findings — 2026-06-14`)
flagged one **FIX-REQUIRED (HIGH)** logic error. It lives entirely under
`.github/workflows/` — both the workflow YAML and a helper shell script.

The automated fixer prepared and verified every change, but the GitHub
App running this workflow **does not hold the `workflows` permission**.
GitHub blocks that App from writing **any** path under
`.github/workflows/` — workflow YAML and `scripts/*.sh` helpers alike —
via both `git push` and the REST contents API (`refusing to allow a
GitHub App to ... update workflow ... without workflows permission`).

The complete, verified diff is therefore committed here as a patch
instead of being applied in-tree:

- [`2026-06-14-workflow-fixes.patch`](./2026-06-14-workflow-fixes.patch)

## What the patch fixes

| Severity | Finding | Change |
| --- | --- | --- |
| HIGH | Fix-stage gate used a single matrix-collapsed `review` job output, so one arbitrary area's priority decided whether fixes ran for **every** area on the scheduled all-areas run | The `fix` job now runs a cell per area and **self-gates per area**: a new `Determine fix priority` step re-derives that area's priority from its own review issue (`extract-review-priority.sh`), and the fixer step, the `REVIEW PRIORITY:` prompt line, and the `Trigger CI` step all gate on that per-area value. The broken job-level `priority` output is removed from the `review` job. |
| Supporting | `extract-review-priority.sh` issue-fallback path (now load-bearing for the per-area gate) lacked the `tail -1` single-line guard the execution-file path has | Adds `\| tail -1` so a body with duplicate `MAXIMUM_FIX_PRIORITY:` markers can't write a malformed multi-line value to `$GITHUB_OUTPUT`. |
| Cleanup | `export BRANCH=$(...)` masked the subcommand exit status (shellcheck SC2155) | Splits declaration and assignment in the `Trigger CI` step. |

### Why the HIGH finding is a real bug

The `review` job is a matrix (one cell per area). GitHub Actions
collapses matrix-job outputs to a **single** value written by whichever
cell finishes last (ordering is not guaranteed). The old `fix` gate read
that one `needs.review.outputs.priority` value, yet `fix` is itself a
matrix over **all** areas. On the documented primary path — the Sunday
`schedule` run across all 12 areas — the consequences were:

- last finisher `NONE`/`LOW`/`XLOW` → the entire `fix` stage skipped even
  when another area returned `HIGH`, so critical findings were silently
  never fixed; or
- last finisher `HIGH`/`MEDIUM` → `fix` ran for **all** areas including
  clean ones, and each fixer is told "no commits = FAILED", pressuring it
  to invent changes / open a spurious PR for a clean area.

Order-dependent and nondeterministic between runs. The single-area
`workflow_dispatch` path only worked because its matrix has one cell.

## How to apply

A maintainer (or a re-run with a token that has the `workflows`
permission) can apply the patch from the repo root:

```sh
git apply .github/correctness-review/2026-06-14-workflow-fixes.patch
git add .github/workflows/
git commit -m "fix(correctness): per-area fix-stage gate instead of matrix-collapsed output (HIGH)"
```

The patch was verified to apply cleanly against `main` with
`git apply --check`, and the changes passed `shellcheck`, `bash -n`,
YAML parsing, and `actionlint`. The per-area gate was exercised against
the live review issues: it returns `HIGH` for the `correctness` area and
fails closed to `NONE` for an area with no matching issue. Once applied,
this directory can be deleted.

## Warnings for Human Review (WARN-ONLY findings)

The review also recorded WARN-ONLY items. Per the correctness review
policy these are **not** auto-fixed; a human should evaluate them:

1. **Branch name computed twice** (`codebase-review.yml` fixer prompt vs.
   the `Trigger CI` step) — derived independently from "today's date" by
   two actors; a run crossing 00:00 UTC could target a nonexistent
   branch. Impact is limited (the trigger swallows the failure). Consider
   computing the branch name once and passing it to both.
2. **Aggregate `needs.review.result == 'success'`** still gated the old
   `fix` job on the whole matrix; one area's review failure blocked fixes
   for all areas. The new per-area self-gate removes the priority half of
   this coupling, but decide whether a failed review cell should still be
   a global fail-safe.
3. **Header comment says "11 focus areas"** but 12 are configured — pure
   comment drift, no runtime effect.
4. **`notify` job's `github.event_name != 'pull_request'` clause** is dead
   code (this workflow only runs on `schedule`/`workflow_dispatch`).
5. **`extract-pr-review-priority.sh`** greps without a single-line guard
   (its `last | .body` jq already narrows to one comment, so lower risk).
6. **`/claude-fix` and PR-event fix paths** (`claude-pr-review.yml`) may
   check out the default branch / a detached merge ref rather than the PR
   head — confirm `claude-code-action` resolves the PR branch in both
   paths.
