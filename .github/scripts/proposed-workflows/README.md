# Proposed workflow files

These are drop-in replacements for the workflows in `.github/workflows/`. They
exist here because the automated review bot's token lacks the `workflows`
permission and therefore cannot modify files under `.github/workflows/`
directly.

A maintainer (or any token with `workflows` permission) should copy them into
place:

```bash
cp .github/scripts/proposed-workflows/codebase-review.yml .github/workflows/codebase-review.yml
cp .github/scripts/proposed-workflows/claude-pr-review.yml .github/workflows/claude-pr-review.yml
git rm -r .github/workflows/scripts   # old script location, now under .github/scripts/
```

## What changed vs the current workflows

- **`run:` paths** now point at `.github/scripts/` (the scripts were moved out of
  the permission-locked `.github/workflows/` tree so the bot can maintain them).
- **`codebase-review.yml` notify job** now `needs` `determine-area` as well, fires
  on any non-success terminal result (failure / cancelled / timed out), and runs
  `notify-failure.sh` — which opens a durable tracking issue and exits non-zero
  instead of a fire-and-forget `echo "::warning::"`.
- **`codebase-review.yml` fix job** re-derives the priority for its own
  `matrix.area` (via `extract-review-priority.sh`) instead of reading an
  unreliable shared matrix scalar output, so per-area fixes are gated correctly.
- **`claude-pr-review.yml`** gains a `notify-failure` job that comments on the PR
  via `notify-pr-failure.sh`.

Once copied in, delete this directory.
