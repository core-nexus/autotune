# How to apply: review(error-handling) — 2026-05-03

The auto-fix bot prepared two commits addressing the findings in
`review(error-handling): findings — 2026-05-03` (issue 5), but its
GitHub App installation token lacks the `workflows` permission, so it
cannot push changes to any file under `.github/workflows/`. Every fix
in this review touches that directory, so the patches are committed
here for a maintainer to apply manually.

## What's in each patch

- `0001-fix-scripts-fail-loud-on-transient-gh-errors-instead.patch`
  — addresses items 1, 2, 3, and 7. Stops the priority-extraction and
  CI-trigger scripts from silently mapping every `gh` failure to a
  benign default. Adds 3-attempt exponential-backoff retry on the
  read-only API calls.

- `0002-fix-workflows-real-failure-notifications-for-both-re.patch`
  — addresses items 4, 5, and 6. Replaces the no-op `::warning::`
  notify job in `codebase-review.yml` with one that opens (or comments
  on) a tracking GitHub issue; broadens its trigger to include
  `determine-area` failures and `cancelled` results. Adds a parallel
  notify job to `claude-pr-review.yml` that posts a PR comment when
  either upstream job fails or is cancelled.

## To apply

From a maintainer checkout with workflow-write permission:

```sh
git checkout -b review/error-handling-2026-05-03
git am auto-review-patches/error-handling-2026-05-03/*.patch
shellcheck .github/workflows/scripts/*.sh
git push -u origin HEAD
gh pr create --title "review(error-handling): weekly codebase review fixes" \
  --label auto-review \
  --body "Applied from auto-review-patches/error-handling-2026-05-03/. Closes the bot-prepared PR."
```

After applying, delete the `auto-review-patches/error-handling-2026-05-03/`
directory in the same PR — the patches no longer need to live in-tree
once their changes are landed.

## Why the bot couldn't push these directly

GitHub blocks GitHub App installation tokens (`ghs_*`) from creating
or updating workflow files unless the App has the `workflows`
permission. The Anthropic Claude Code GitHub App used by this
workflow does not currently request that scope, so any review whose
fix lands inside `.github/workflows/` hits this block. Two ways to
unblock future runs:

1. Add a personal access token (or another App with the `workflows`
   scope) as a secret, and pass it to `actions/checkout@v4` via the
   `token:` input in the fix job. This is the straightforward fix.
2. Restructure the fix job to commit and create the PR via a separate
   token only when changes touch `.github/workflows/`.

Either is a one-line workflow change a maintainer would need to make
once.
