# Applying these patches

The fixes for `review(error-handling): findings — 2026-05-10` all
land under `.github/workflows/`. The auto-fix bot's GitHub App token
(`ghs_*`) does **not** carry the `workflows` scope, and GitHub
hard-blocks any push from such a token that touches files in that
directory:

```
refusing to allow a GitHub App to create or update workflow
.github/workflows/<file> without `workflows` permission
```

So the changes ship here as `git format-patch` output. A maintainer
applies them from a token (PAT or another App) that does carry the
`workflows` scope.

## How to apply

```bash
git checkout review/error-handling-2026-05-10
git am auto-review-patches/error-handling-2026-05-10/*.patch
git rm -r auto-review-patches/error-handling-2026-05-10
git commit --amend --no-edit          # fold the cleanup into the last patch, optional
git push origin review/error-handling-2026-05-10
```

Verification commands the patches were tested against:

```bash
shellcheck -x .github/workflows/scripts/*.sh   # clean
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/codebase-review.yml')); yaml.safe_load(open('.github/workflows/claude-pr-review.yml'))"
bash -n .github/workflows/scripts/*.sh
```

A retry-helper smoke test was also run locally:

```bash
# Permanent-failure case: rc propagates correctly (returns gh's exit code).
# Transient-failure case: succeeds on the third attempt with the captured stdout.
```

## What's in each patch

1. `0001-fix-error-handling-surface-gh-API-failures-instead-o.patch`
   Adds `lib.sh` with `gh_with_retry` (3 attempts, 1s/2s exponential
   backoff). Rewrites both extract-priority scripts to drop
   `2>/dev/null | ... || echo NONE` — failures of the underlying
   `gh api` / `gh issue list` now exit non-zero. The literal `NONE`
   default is reserved for the legitimate "API succeeded but no
   `MAXIMUM_FIX_PRIORITY` token in the response" case.
   Addresses items 1, 2, 8 of the review.

2. `0002-fix-error-handling-distinguish-404-from-real-errors-.patch`
   Rewrites `trigger-ci-workflows.sh`. Verifies the branch up-front
   (so a missing ref is reported as such, not misclassified as 12
   missing workflows). Captures stderr from each `gh workflow run`,
   treats 404 / "Not Found" / "Could not find any workflow" as a
   legitimate skip (the default `WORKFLOWS` list speculatively probes
   common names), and surfaces every other failure as an error that
   exits the step non-zero.
   Addresses item 3.

3. `0003-fix-error-handling-make-codebase-review-failures-vis.patch`
   Three changes inside `codebase-review.yml`:
   - Replaces the no-op `echo "::warning::..."` notify step with a
     new `notify-workflow-failure.sh` that opens a tracking GitHub
     issue using only the built-in `GITHUB_TOKEN`. No extra secrets;
     lands in the same Issues UI as review findings; README still
     documents the Slack swap as an upgrade.
   - Adds `determine-area` to `notify.needs` (its failure used to
     leave `review`/`fix` as `skipped`, which the old condition
     swallowed) and broadens the firing condition to include
     `cancelled` (review timeouts surface as `cancelled`, not
     `failure` — the most likely failure mode for a Claude API
     stall).
   - Computes the branch name once via a new `branch` step,
     interpolates it into Claude's prompt (so the fix step pushes
     the exact ref the trigger step expects) and reuses the same
     value in the trigger step. Removes the date-arithmetic window
     where a fix step crossing 00:00 UTC would push branch `X` while
     the trigger step looked for branch `X+1`.
   Addresses items 4, 5, 6.

4. `0004-fix-error-handling-post-failure-comment-on-claude-pr.patch`
   Adds a `notify-failure` job to `claude-pr-review.yml` that posts
   a single PR comment when either the `review` or `fix-review-issues`
   job fails or is cancelled — so a `/claude-fix` request that
   errors out doesn't leave the requester silently waiting.
   Addresses item 7.

## After applying

Once these are merged, the **next** error-handling review run can
push directly (assuming a `workflows`-scoped token is wired into
`actions/checkout@v4` via `with: token:` for the fix job). Until
then, every review touching `.github/workflows/` will need this same
patch-bundle workaround.

## Unblocking future runs

Add a PAT (or another App installation) with the `workflows` scope
as a repo secret, and pass it to `actions/checkout@v4` in the fix
job, e.g.:

```yaml
- name: Checkout repository
  uses: actions/checkout@v4
  with:
    fetch-depth: 0
    token: ${{ secrets.WORKFLOWS_WRITE_PAT }}
```

That removes the patch-bundle workaround for all future review areas.
