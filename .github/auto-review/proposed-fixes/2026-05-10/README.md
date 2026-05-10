# Proposed fixes for code-quality review issue 27 (2026-05-10)

These files are proposed replacements for files under `.github/workflows/`
that the auto-review bot could not push directly (its GitHub App token
lacks the `workflows` permission, so any change under
`.github/workflows/**` is rejected at push time).

A maintainer with appropriate permissions should review the diffs and,
if accepted, apply each `.proposed` file by replacing the corresponding
file in `.github/workflows/`.

## How to apply

```bash
# From the repo root, on the auto-review branch:
cp .github/auto-review/proposed-fixes/2026-05-10/codebase-review.yml.proposed \
   .github/workflows/codebase-review.yml

cp .github/auto-review/proposed-fixes/2026-05-10/claude-pr-review.yml.proposed \
   .github/workflows/claude-pr-review.yml

cp .github/auto-review/proposed-fixes/2026-05-10/resolve-review-area.sh.proposed \
   .github/workflows/scripts/resolve-review-area.sh

cp .github/auto-review/proposed-fixes/2026-05-10/trigger-ci-workflows.sh.proposed \
   .github/workflows/scripts/trigger-ci-workflows.sh

cp .github/auto-review/proposed-fixes/2026-05-10/extract-review-priority.sh.proposed \
   .github/workflows/scripts/extract-review-priority.sh

cp .github/auto-review/proposed-fixes/2026-05-10/decide-fix-areas.sh.proposed \
   .github/workflows/scripts/decide-fix-areas.sh

chmod +x .github/workflows/scripts/*.sh

# Then verify:
shellcheck .github/workflows/scripts/*.sh
python3 -c "import yaml; [yaml.safe_load(open(f)) for f in ['.github/workflows/codebase-review.yml','.github/workflows/claude-pr-review.yml']]"

# After merging, you can delete this directory.
```

## What each file fixes

See the PR description for the full mapping of files to review-issue items
(items 1–13 in issue 27). At a glance:

- `codebase-review.yml.proposed` — items 1, 2, 3, 4, 10, 11, 12, 13
- `claude-pr-review.yml.proposed` — items 9, 10, 11, 13
- `resolve-review-area.sh.proposed` — items 5, 6
- `trigger-ci-workflows.sh.proposed` — item 7
- `extract-review-priority.sh.proposed` — item 8
- `decide-fix-areas.sh.proposed` — new helper for item 1

## Why the bot couldn't push these directly

GitHub blocks GitHub App tokens that lack the `workflows: write`
permission from creating or modifying any file under
`.github/workflows/**` (this includes scripts inside
`.github/workflows/scripts/`). The auto-review bot's token is granted
`contents: write` but not `workflows: write`, by design — granting
`workflows: write` would let the bot rewrite its own workflow logic.

To make future auto-fix runs able to push workflow changes, a
maintainer would need to either:
1. Use a Personal Access Token (or a separate App with `workflows`
   permission) for the push step, **or**
2. Continue to apply workflow-related fixes by hand from these
   `.proposed` files.

Option 2 is the safer default.
