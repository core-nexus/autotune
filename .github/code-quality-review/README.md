# Code-Quality Review Fixes — 2026-07-12

This directory holds the fixes for the code-quality review
(issue titled `review(code-quality): findings — 2026-07-12`) as a **patch
file** rather than as direct edits.

## Why a patch instead of direct commits?

Every finding in this review targets files under `.github/workflows/`
(the workflow YAMLs and their helper scripts). The automated-review bot
authenticates with a GitHub App token that does **not** carry the
`workflows` permission, so GitHub's pre-receive hook rejects any push that
creates or modifies anything under `.github/workflows/`:

```
refusing to allow a GitHub App to create or update workflow
`.github/workflows/...` without `workflows` permission
```

Because 100% of the fixes live under that protected path, they cannot be
pushed directly by this workflow. They are captured here as a patch so a
maintainer (or a token with the `workflows` permission) can apply them.
This mirrors the convention used by the prior code-quality review
(`review/code-quality-2026-06-28`).

## How to apply

From the repo root, on a fresh branch off `main`:

```bash
git checkout -b apply-code-quality-fixes main
git apply .github/code-quality-review/2026-07-12-code-quality-fixes.patch
# verify
shellcheck .github/workflows/scripts/*.sh
python3 -c "import yaml; [yaml.safe_load(open(f)) for f in \
  ['.github/workflows/codebase-review.yml', '.github/workflows/claude-pr-review.yml']]"
git add -A && git commit -m "review(code-quality): apply 2026-07-12 fixes"
```

The patch applies cleanly onto `main` and was verified with
`git apply --check`. After applying, `shellcheck` passes on all helper
scripts and both workflow YAMLs parse.

## What the patch changes

### HIGH

- **item 1 — `codebase-review.yml`: matrix job outputs broke per-area fix
  gating.** The `review` job is a matrix over up to 12 areas but exposed a
  single job-level `priority` output. GitHub Actions does not namespace
  matrix outputs per leg, so that scalar held whichever leg finished last
  (nondeterministic). Gating the `fix` job on it meant a scheduled "all"
  run could silently skip every MEDIUM+ finding (if the last leg reported
  NONE/LOW) or run the fixer for areas with no findings. The patch has each
  review leg persist its priority to a per-area artifact (`priority-<area>`);
  the `fix` job downloads its own area's artifact and gates the fix +
  CI-trigger steps on that value, restoring correct per-area gating.

### MEDIUM

- **item 2 — `resolve-review-area.sh`: duplicated area list.** The 12 area
  names were hardcoded independently in the script and in the workflow
  dropdown. The script now derives the list from the
  `.github/review-prompts/*.md` filenames (single source of truth), keeping
  the hardcoded list only as a defensive fallback. A comment notes the
  dropdown `options:` must still be kept in sync by hand (Actions cannot
  populate `choice` options dynamically).
- **item 3 — `claude-pr-review.yml`: duplicated review criteria.** The PR
  workflow inlined its own copy of the security/privacy/error-handling/
  code-quality/performance/testing/documentation checklists. It now points
  at the canonical `.github/review-prompts/*.md` files instead of restating
  them, so criteria improvements reach both review paths.
- **item 4 — `codebase-review.yml`: fix branch name reconstructed twice.**
  The fix step told the model to create `review/<area>-YYYY-MM-DD` and the
  CI-trigger step independently recomputed the branch with its own
  `date -u`; a mismatch (formatting or a 00:00 UTC boundary) silently
  targeted a nonexistent branch. The branch name is now computed once in a
  step and consumed by both the fix prompt and the CI-trigger step.

### LOW

- **item 5 — `codebase-review.yml`:** header comment said "11 focus areas";
  corrected to 12.
- **item 6 — `codebase-review.yml`:** removed the dead
  `github.event_name != 'pull_request'` guard in the `notify` job (the
  workflow only runs on `schedule`/`workflow_dispatch`).
- **item 7 — `resolve-review-area.sh`:** documented the unreachable
  `:-` default (the `review_area` choice input is `required: true`) as a
  defensive guard.
- **item 8 — `extract-review-priority.sh`:** the fallback listed
  `--state all --limit 10` and took `.[0]`, which could pick a stale/closed
  or "clean" issue. It now lists open issues, matches `": findings"` titles
  (skipping "clean" reports), sorts by `createdAt` descending, and collapses
  multiple regex hits with `tail -1`.
- **item 9 — `claude-pr-review.yml`:** the `/claude-fix` (issue_comment)
  path checked out the default branch. It now resolves and checks out the
  PR head branch so fixes are based on — and pushed to — the PR branch.

---

Automated fix by codebase-review workflow
