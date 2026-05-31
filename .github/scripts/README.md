# Codebase review automation — fixed scripts (relocated)

This directory holds the **fixed** versions of the codebase-review automation
scripts and workflow files, addressing the findings from issue
`review(error-handling): findings — 2026-05-31`.

These were placed here (under `.github/scripts/`) rather than at their original
location (`.github/workflows/scripts/`) for a single, structural reason: **the
auto-fix bot lacks `workflows: write` permission**, and GitHub treats every
file under `.github/workflows/` (including the `scripts/` subdirectory) as a
workflow file. Pushing fixes to the original paths fails with:

```
refusing to allow a GitHub App to create or update workflow
`.github/workflows/scripts/extract-pr-review-priority.sh` without
`workflows` permission
```

A human (with the appropriate permission, or a token that has `workflows:
write`) needs to complete the rewiring — see "Manual rewiring steps" below.
The fixes themselves are self-contained code; they only need to be moved or
wired in.

## What was fixed

Findings from the review issue, by severity:

### HIGH

- **item 1** — Matrix `priority` output race. The `review` job's matrix
  instances all wrote to a single scalar job output (last-writer-wins,
  non-deterministic), letting a clean area silently override a HIGH-priority
  area and skip its fix stage. **Fix:** removed the shared output; the `fix`
  job re-extracts priority per `matrix.area` and gates each instance locally.
- **item 2** — Silent extraction failures looked identical to a clean
  codebase. The script defaulted to `NONE` whenever the review action errored,
  hit max-turns, or produced malformed output. **Fix:** new `UNKNOWN` sentinel
  + non-zero exit when extraction fails, which turns the review step red so
  the `notify` job actually fires.

### MEDIUM

- **item 3** — `2>/dev/null` on `gh issue list` collapsed API/auth/network
  failures into `NONE`. **Fix:** capture stderr to a tempfile, check exit code
  separately, log stderr on failure, exit non-zero on genuine API errors.
- **item 4** — `notify` job only emitted a `::warning::` annotation (alerts
  no one) and omitted `determine-area` from its `needs`. **Fix:** add Slack
  notification (when `SLACK_WEBHOOK_URL` is set) with a fallback that opens a
  tracking GitHub issue; include `determine-area` in `needs`.
- **item 5** — `claude-pr-review.yml` had no failure-handling job. **Fix:**
  add a `notify-failure` job that posts a PR comment when either stage fails.
- **item 6** — `trigger-ci-workflows.sh` masked every failure (auth, network,
  invalid ref) as the benign "workflow not found". **Fix:** only swallow the
  specific not-found/404 case; surface other errors loudly; emit a warning if
  zero workflows dispatched; exit non-zero on any non-benign failure.

### LOW

- **item 7** — `GH_TOKEN` documented as required but missing from `:?` env
  guards. **Fix:** add `"${GH_TOKEN:?}"` to the env guard in each script.
- **item 8** — `resolve-review-area.sh` didn't validate `INPUT_REVIEW_AREA`
  against known areas. **Fix:** validate against the area list AND check that
  the corresponding prompt file exists.

## File layout in this PR

```
.github/scripts/
├── README.md                                      ← this file
├── extract-pr-review-priority.sh                  ← fixed (items 3, 5, 7)
├── extract-review-priority.sh                     ← fixed (items 2, 3, 7)
├── resolve-review-area.sh                         ← fixed (item 8)
├── trigger-ci-workflows.sh                        ← fixed (items 6, 7)
└── workflow-patches/
    ├── claude-pr-review.yml.fixed                 ← full fixed workflow
    ├── claude-pr-review.yml.patch                 ← diff vs current main
    ├── codebase-review.yml.fixed                  ← full fixed workflow
    └── codebase-review.yml.patch                  ← diff vs current main
```

The old scripts at `.github/workflows/scripts/*.sh` are **unchanged** in this
PR — the bot was not permitted to modify them. After merging this PR, a human
needs to perform the manual rewiring step below.

## Manual rewiring steps

After this PR is merged (or as part of merging it, with a fixup commit by a
maintainer):

1. **Replace the two workflow files** with their fixed counterparts:
   ```bash
   cp .github/scripts/workflow-patches/codebase-review.yml.fixed \
      .github/workflows/codebase-review.yml
   cp .github/scripts/workflow-patches/claude-pr-review.yml.fixed \
      .github/workflows/claude-pr-review.yml
   ```
   Or, equivalently, apply the patches:
   ```bash
   patch -p0 < .github/scripts/workflow-patches/codebase-review.yml.patch
   patch -p0 < .github/scripts/workflow-patches/claude-pr-review.yml.patch
   ```
   The fixed workflows reference scripts at `.github/scripts/...`, not at
   `.github/workflows/scripts/...`.

2. **Delete the old scripts** at the old path:
   ```bash
   rm -r .github/workflows/scripts
   ```

3. **Commit and push** the rewiring. This commit DOES require `workflows:
   write` permission.

4. **Recommended follow-up:** add `workflows: write` to the `fix` job's
   `permissions:` block in `codebase-review.yml`. Without it, future
   automated review cycles that find workflow-related issues will hit the
   same wall this PR did and will not be able to fully self-fix.

## Why not just commit everything?

The codebase-review automation runs in a GitHub Action context with a token
that does not have `workflows: write` scope. The bot tried to push the full
set of fixes to the original paths and was rejected by GitHub's server-side
pre-receive check. The relocation to `.github/scripts/` was the only path
that allowed any of the fixes to be pushed for review at all.
