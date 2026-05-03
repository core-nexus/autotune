# Manual workflow patches — correctness review (2026-05-03)

The GitHub App that runs the auto-review workflow does not have the
`workflows` permission, so it cannot push edits to anything under
`.github/workflows/` (including shell scripts in `scripts/`). The fixes
for this review's FIX-REQUIRED findings are shipped here as patch files
for a maintainer to apply manually.

## Patches in this directory

### 0001-per-area-priority-artifact-for-matrix-fix-gate.patch
**Fixes review issue 12, HIGH finding** ("Matrix job outputs collapse to
a single value, breaking the fix gate"). Modifies
`.github/workflows/codebase-review.yml`.

The `review` job runs as a matrix and exposed `outputs.priority` at the
job level. GitHub Actions stores only one value per job-level output
across all matrix variants (last writer wins, ordering non-deterministic).
The downstream `fix` job's gate
(`needs.review.outputs.priority == 'HIGH' || == 'MEDIUM'`) therefore
reflected a single random variant — for the scheduled run that fans out
to 12 areas, this silently dropped critical findings or spawned 11
unnecessary fix jobs.

After the patch:
- Each review variant uploads its priority as a per-area artifact
  (`review-priority-<area>`).
- The fix matrix runs for every area where the review job succeeded and
  gates inside the job by downloading its own area's artifact.
- Subsequent steps (checkout, fixer prompt, CI trigger) are conditional
  on the gate's `proceed=true` output, so skipped areas exit cheaply.
- The fix prompt's `REVIEW PRIORITY` placeholder is rewired from the
  removed `needs.review.outputs.priority` to `steps.gate.outputs.priority`.

### 0002-collapse-pr-priority-extractor-to-single-line.patch
**Fixes review issue 12, MEDIUM finding** ("`extract-pr-review-priority.sh`
writes a multi-line value to `GITHUB_OUTPUT`"). Modifies
`.github/workflows/scripts/extract-pr-review-priority.sh`.

If a PR comment body contained more than one `MAXIMUM_FIX_PRIORITY:`
marker (e.g. a reviewer enumerating options or quoting a previous
suggestion), the value piped to `priority=...` was multi-line and the
runner silently dropped or partially set the output, so the fix gate in
`claude-pr-review.yml` line 141 failed to match any priority and the fix
stage was skipped. The sister script `extract-review-priority.sh`
already uses `tail -1` for the same reason.

After the patch: `| tail -1` collapses grep output to a single line, plus
a defensive `${PRIORITY:-NONE}` fallback for the empty-stream case.

## How to apply

From the repo root, on a branch where you can push workflow edits:

```bash
git apply auto-review-patches/correctness-2026-05-03/0001-per-area-priority-artifact-for-matrix-fix-gate.patch
git apply auto-review-patches/correctness-2026-05-03/0002-collapse-pr-priority-extractor-to-single-line.patch

git add .github/workflows/codebase-review.yml \
        .github/workflows/scripts/extract-pr-review-priority.sh
git commit -m "fix(workflows): correctness review fixes (matrix gate + PR priority extractor)"
```

Validate after applying:

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/codebase-review.yml'))"
bash -n .github/workflows/scripts/extract-pr-review-priority.sh
shellcheck .github/workflows/scripts/extract-pr-review-priority.sh
```
