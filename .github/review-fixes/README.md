# Performance review fix — delivered as a patch (token cannot push it directly)

`codebase-review-performance-fix.patch` contains the complete fix for the
performance review findings (issue: `review(performance): findings — 2026-06-21`).

## Why it is a patch and not direct file changes

Every file the fix touches lives under `.github/workflows/`:

- `.github/workflows/codebase-review.yml`
- `.github/workflows/scripts/extract-review-priority.sh`
- `.github/workflows/scripts/collect-fix-areas.sh` (new)
- `.github/workflows/scripts/tests/collect-fix-areas.test.sh` (new)

GitHub refuses to let a GitHub App installation token create or update **any**
file under `.github/workflows/` (workflows and their helper scripts alike)
unless the app has the `workflows: write` permission. The automated review/fix
bot does not have it, so it cannot push these changes itself. The fix is
therefore committed here as an applyable patch, in a directory that is allowed.

## What the fix does

**Item 1 (MEDIUM) — paid Opus fix sessions fan out to all 12 areas.**
The `review` matrix job declared a single job-level `priority` output. GitHub
Actions does not key matrix-job outputs per leg, so the last-finishing leg
overwrites it. The `fix` job — itself a 12-area matrix — was gated only on that
one collided value, launching a full Opus session (`--max-turns 250`) for **all
12 areas** whenever the last review leg reported MEDIUM/HIGH, including areas
that reviewed clean. (It was also a correctness bug: a clean last leg could
suppress fixes for a genuinely HIGH area.)

The fix makes the decision per-area:

1. Each `review` leg writes its priority to `PRIORITY_FILE` and uploads it as a
   `priority-<area>` artifact.
2. A new `collect-priorities` job downloads every artifact and, via
   `collect-fix-areas.sh`, emits a `matrix.include` of **only** the HIGH/MEDIUM
   areas — each carrying its own priority.
3. The `fix` job runs solely over that set. No Opus session is spent on an area
   that reviewed clean.

**Item 2 (LOW)** — the fix-job checkout switches from `fetch-depth: 0` (full
history) to `fetch-depth: 1`; the fix only branches from HEAD, commits, and
pushes.

**Item 3 (LOW)** — per-area gating bounds weekly fix cost to the areas that
actually found issues, mitigating the unbounded fan-out.

Plus: corrected the header comment (12 areas, not 11) and added
`collect-priorities` to the `notify` job's failure check.

## Tests

`collect-fix-areas.test.sh` (included in the patch) covers HIGH/MEDIUM
filtering, the empty-result cases that skip the fix job, whitespace trimming,
and tolerance of a missing `priority.txt`. Run it with:

```bash
bash .github/workflows/scripts/tests/collect-fix-areas.test.sh
```

## How to apply (requires `workflows` write access)

```bash
git apply .github/review-fixes/codebase-review-performance-fix.patch
# verify
bash .github/workflows/scripts/tests/collect-fix-areas.test.sh
git add .github/workflows
git rm -r .github/review-fixes
git commit -m "ci(perf): per-area fix matrix for codebase-review (apply review patch)"
```

The patch has been verified to apply cleanly against `main` with
`git apply --check`.
