# Code-Quality Review Fixes — 2026-06-28

This directory holds the fixes for the code-quality review
(issue titled `review(code-quality): findings — 2026-06-28`) as a **patch
file** rather than as direct edits.

## Why a patch instead of direct commits?

Every finding in this review targets files under `.github/workflows/`
(the workflow YAMLs and their helper scripts). The automated-review bot
authenticates with a GitHub App token that does **not** carry the
`workflows` permission, so GitHub's pre-receive hook rejects any push that
creates or modifies *anything* under `.github/workflows/` — including the
`.sh` helper scripts:

```
refusing to allow a GitHub App to create or update workflow
`.github/workflows/...` without `workflows` permission
```

Because 100% of the fixes live under that protected path, they cannot be
pushed directly by this workflow. They are captured here as a patch so a
maintainer (or a token with the `workflows` permission) can apply them.
This mirrors the convention already used by prior automated reviews in
this repo (e.g. `.security-review/`, `.github/review-fixes/`).

## How to apply

From the repo root, on a fresh branch off `main`:

```bash
git checkout -b apply-code-quality-fixes main
git apply .github/code-quality-review/2026-06-28-code-quality-fixes.patch
# verify
shellcheck .github/workflows/scripts/*.sh
bash .github/workflows/scripts/check-review-areas-in-sync.sh
git add -A && git commit -m "review(code-quality): apply 2026-06-28 fixes"
```

The patch applies cleanly onto `main` and was verified with
`git apply --check`.

## What the patch changes

### HIGH

- **item 1 — `codebase-review.yml`: per-area fix gating.** The `review`
  job is a matrix, but exposed a single job-level `priority` output.
  GitHub Actions does not namespace matrix outputs per leg, so that scalar
  held whichever leg finished last (nondeterministic). Gating the `fix`
  job on it meant a scheduled "all" run could silently skip every HIGH
  finding (if the last leg reported NONE/LOW) or run Opus for areas with
  no findings. The patch removes the scalar gate and makes each `fix`
  matrix leg re-derive its **own** area's priority from that area's review
  issue, gating the expensive fix + CI-trigger steps on it.

### MEDIUM

- **item 2 — `extract-pr-review-priority.sh`:** collapse multiple regex
  hits with `tail -1` (matching its sibling) so a multi-line value can't
  corrupt `GITHUB_OUTPUT` and mis-trigger the fix gate.
- **item 3 — both `extract-*-priority.sh`:** distinguish a genuine `gh`
  API failure from "found nothing" — a non-zero call now emits `::error::`
  and exits 1 instead of silently defaulting to `NONE` and skipping fixes.
- **item 4 — `codebase-review.yml`:** correct the stale "11 focus areas"
  header comment to 12.

### LOW

- **item 5 — review-area drift guard:** add
  `scripts/check-review-areas-in-sync.sh` (asserts the workflow dropdown
  options equal `ALL_AREAS`), wire it into a new `ci.yml`, and add
  keep-in-sync comments in both locations.
- **item 6 — `codebase-review.yml`:** standardize the CI-trigger token on
  `${{ github.token }}`.
- **item 7 — scripts:** add the documented-required `GH_TOKEN` to the
  fail-fast guards where `gh` is actually used.
- **item 8 — `codebase-review.yml`:** drop the dead `pull_request` clause
  from the `notify` gate (this workflow never runs on `pull_request`).
- **item 9 — `codebase-review.yml`:** derive the CI-trigger branch from
  `HEAD` instead of recomputing the date, which could drift across UTC
  midnight on the 90-minute fix job.

Automated fix by codebase-review workflow
