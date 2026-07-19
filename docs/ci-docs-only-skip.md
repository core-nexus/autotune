# Skipping CI on docs-only PRs

Documentation-only pull requests (README tweaks, `docs/` edits, a `LICENSE`
change) don't need your full lint/test/build/e2e suite. Skipping it on those PRs
saves minutes and CI minutes. There are two ways to skip, and they solve
different problems.

## Option A — `paths-ignore` (simple, for NON-required workflows)

If the workflow is **not** a required status check, the simplest skip is
`paths-ignore` on the trigger — the workflow just doesn't run:

```yaml
on:
  pull_request:
    paths-ignore:
      - '**/*.md'
      - '**/*.txt'
      - 'docs/**'
```

This repo's `claude-pr-review.yml` and `ai-qa-review.yml` already do this — a
docs-only PR gets no AI code review and no visual QA, because there's nothing
code-shaped to review.

**The catch:** if the workflow is a **required** status check, `paths-ignore`
makes it never run, so its status never reports, and the PR sits forever waiting
on a check that will never arrive. For required checks, use Option B.

## Option B — `detect-docs-only.sh` (for REQUIRED status checks)

`scripts/detect-docs-only.sh` reads a PR's changed-file list on stdin and prints
`true` (run the full suite) or `false` (docs-only, skip). Gate your expensive
jobs on it. Because the job still **runs** and **reports success** (it just skips
the expensive steps), a required check stays green and the PR stays mergeable.

It's fail-safe: an empty file list or any unrecognized extension resolves to
`true` (run everything). It only skips when it is certain every changed file is
documentation.

### Wiring it into a required CI workflow

```yaml
jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      run_suite: ${{ steps.detect.outputs.run_suite }}
    steps:
      - uses: actions/checkout@v4
      - name: Detect docs-only PR
        id: detect
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          if [ "${{ github.event_name }}" = "pull_request" ]; then
            FILES=$(gh pr view "${{ github.event.number }}" \
              --json files --jq '.files[].path')
          else
            FILES=$(git diff --name-only HEAD~1 HEAD)
          fi
          RUN=$(printf '%s\n' "$FILES" | .github/workflows/scripts/detect-docs-only.sh)
          echo "run_suite=${RUN}" >> "$GITHUB_OUTPUT"

  test:
    needs: detect-changes
    if: needs.detect-changes.outputs.run_suite == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      # ... your lint / test / build steps ...
```

When `run_suite == 'false'`, the `test` job is skipped. If `test` is a required
check, a skipped required job is treated as passing, so the docs-only PR merges
without waiting.

### What counts as "docs"

`detect-docs-only.sh` treats these as docs (safe to skip):

- `*.md`, `*.txt`, `*.html` (but see the exception below)
- anything under `doc/` or `docs/`
- `LICENSE` / `LICENSE.*`

Everything else forces the full suite. The one exception: `*.html` **under your
source root** (`src/*.html`) is treated as code, not docs — an app shell or
framework error page ends in `.html` but is real application code. Adjust the
`src/` prefix in the script to match your source layout.

### Tests

`scripts/detect-docs-only.test.sh` exercises the classifier against docs-only,
code, mixed, app-shell, and empty-input cases. Run it with:

```bash
bash .github/workflows/scripts/detect-docs-only.test.sh
```
