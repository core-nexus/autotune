# Proposed code-quality fixes — 2026-05-24

Concrete, ready-to-apply fixes for every finding in the code-quality review
issue (`review(code-quality): findings — 2026-05-24`).

**Why these are staged as `.proposed` files instead of applied directly:**
the automated fixer runs as a GitHub App that does not hold the `workflows`
permission, so it cannot push changes to anything under `.github/workflows/`
(this includes the `scripts/*.sh` files). Every fix below lives there. The full
fixed content of each file is provided here so a maintainer with the `workflows`
permission can apply them in one step. This mirrors the convention used by the
previous code-quality fix PR.

## How to apply

From the repo root, copy each `*.proposed` over its real target (drop the
`.proposed` suffix):

```bash
DIR=.github/auto-review/proposed-fixes/2026-05-24

cp "$DIR/codebase-review.yml.proposed"          .github/workflows/codebase-review.yml
cp "$DIR/claude-pr-review.yml.proposed"         .github/workflows/claude-pr-review.yml
cp "$DIR/extract-review-priority.sh.proposed"   .github/workflows/scripts/extract-review-priority.sh
cp "$DIR/extract-pr-review-priority.sh.proposed" .github/workflows/scripts/extract-pr-review-priority.sh
cp "$DIR/resolve-review-area.sh.proposed"       .github/workflows/scripts/resolve-review-area.sh
cp "$DIR/trigger-ci-workflows.sh.proposed"      .github/workflows/scripts/trigger-ci-workflows.sh
cp "$DIR/README.md.proposed"                    README.md

chmod +x .github/workflows/scripts/*.sh
rm -rf "$DIR"   # remove the staging bundle once applied
```

All proposed scripts pass `shellcheck`; both proposed workflows parse as valid
YAML.

## What each fix addresses

### HIGH

- **item 1 — fix stage gated on a non-deterministic matrix job output.**
  `codebase-review.yml`: removed the job-level `outputs.priority` from the
  `review` matrix job (GitHub exposes only one arbitrary leg's value). Each
  `fix` matrix leg now has a `gate` step that derives **its own** area's
  priority from that area's review issue (via `extract-review-priority.sh`) and
  only runs the fixer when the priority is MEDIUM or HIGH. The fixer prompt's
  `REVIEW PRIORITY` now reads `steps.gate.outputs.priority`.

### MEDIUM

- **item 2 — one failed review leg skipped the fix stage for all areas.**
  `codebase-review.yml`: the `fix` job's `if` no longer requires
  `needs.review.result == 'success'`; it is now
  `always() && needs.determine-area.result == 'success'`. Combined with the
  per-area gate (item 1), each area's fix is independent of other areas'
  review outcomes.

- **item 3 — CI-trigger branch was reconstructed from `date`, not derived.**
  `codebase-review.yml`: a new `Detect pushed branch` step records the branch
  the fixer actually pushed (`git rev-parse --abbrev-ref HEAD`); the
  `Trigger CI workflows` step passes that exact `BRANCH` and only runs when the
  branch starts with `review/`.

- **item 4 — PR-comment fetch was not paginated; marker could be missed.**
  `extract-pr-review-priority.sh`: uses `gh api --paginate`; no longer swallows
  API errors into a silent `NONE` (only a true no-match falls back); validates
  the value against the allowed set.

- **item 5 — review-area list was a duplicated source of truth (already
  drifted).** `resolve-review-area.sh`: derives the area list from the prompt
  files in `.github/review-prompts/` (the single source of truth). A
  single-area dispatch for a missing prompt file now fails loudly. README
  guidance updated to match (`README.md.proposed`). Note: the
  `workflow_dispatch` `options` list still must be edited by hand (GitHub
  Actions cannot populate choice options dynamically); a mismatch there now
  fails loudly at resolve time instead of silently.

### LOW

- **item 6 — asymmetric concurrency between schedule and dispatch.**
  `codebase-review.yml`: concurrency group falls back to `github.event_name`
  (stable) instead of `github.run_id`, so overlapping scheduled runs are
  serialized.

- **item 7 — fragile `tail -1` priority extraction over the full transcript.**
  `extract-review-priority.sh`: the review issue body is now the authoritative
  source (marker matched on a marker-only line and validated against the
  allowed values); the execution transcript is a fallback.

- **item 8 — hardcoded magic limit in the fallback issue lookup.**
  `extract-review-priority.sh`: the limit is a documented constant
  (`ISSUE_LOOKUP_LIMIT`) and the matching issue is selected as the newest by
  `createdAt` (direct list, not the lagging search index).

- **item 9 — stale comment "11 focus areas".** `codebase-review.yml`: the
  header comment no longer hardcodes a count (there are 12); README sections
  updated.

- **item 10 — duplicated bot/comment guard in the PR workflow.**
  `claude-pr-review.yml`: a single `gate` job computes `run_review` / `run_fix`
  once; the `review` and `fix-review-issues` jobs depend on its boolean
  outputs.

- **item 11 — documented "Required" `GH_TOKEN` not validated/needed.** Both
  extract scripts: `GH_TOKEN` documented accurately (conditionally required in
  `extract-review-priority.sh`; required in `extract-pr-review-priority.sh`).

### XLOW (nits, folded in)

- Priority regexes use an explicit `(NONE|XLOW|LOW|MEDIUM|HIGH)` alternation
  (rejects typos like `HIGHEST`) and a consistent `\K` idiom in both scripts.
- `trigger-ci-workflows.sh` reads `WORKFLOWS` into a Bash array instead of
  relying on unquoted word-splitting.
- The dead `security` default in `resolve-review-area.sh` (review_area is
  `required`) is removed.

Automated fix by codebase-review workflow
