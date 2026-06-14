# Pending workflow performance fixes — 2026-06-14

The performance review (`review(performance): findings — 2026-06-14`)
found that the only executable code in this repository lives under
`.github/workflows/` — specifically the helper shell scripts in
`.github/workflows/scripts/`.

The automated fixer prepared and verified every change, but the GitHub
App running this workflow **does not hold the `workflows` permission**.
GitHub blocks that App from writing **any** path under
`.github/workflows/` — workflow YAML and the `scripts/*.sh` helpers
alike — via both `git push` and the REST contents API (`refusing to
allow a GitHub App to ... update workflow ... without workflows
permission`).

The complete, verified diff for those files is therefore committed here
as a patch instead of being applied in-tree:

- [`2026-06-14-workflow-fixes.patch`](./2026-06-14-workflow-fixes.patch)

## What the patch fixes

| Severity | Finding | Change |
| --- | --- | --- |
| LOW 1 | Unpaginated comment fetch in `extract-pr-review-priority.sh` could silently miss the priority marker on busy PRs | `gh api .../comments` returned only the first page (default 30, ascending) and took the `last` match, so the `MAXIMUM_FIX_PRIORITY` marker fell outside the page once a PR accumulated >30 comments — silently falling back to `NONE` and skipping the fix stage. Now fetches newest-first server-side (`sort=created&direction=desc&per_page=100`) and takes the first match: bounded to a single page, yet reliably surfaces the latest marker. |
| LOW 2 (found during exploration; same scaling class) | Truncated issue-list window in `extract-review-priority.sh` fallback | The `gh issue list` fallback used `--limit 10`, but a full weekly review batch creates 12 issues at once — so an area's most recent issue can be truncated out of the window and misread as `NONE`. Raised to `--limit 100` to comfortably exceed one batch while staying a single page. |

The remaining items in the review issue (sequential CI-trigger loop;
weekly fan-out cost) were classified XLOW / "no action recommended" —
trivial impact or already-documented cost trade-offs — and are
intentionally not changed.

## How to apply

A maintainer (or a re-run with a token that has the `workflows`
permission) can apply the patch from the repo root:

```sh
git apply .github/performance-review/2026-06-14-workflow-fixes.patch
git add .github/workflows/
git commit -m "fix(perf): bound priority-marker fetches so they don't silently miss markers at scale (LOW 1/2)"
```

The patch was verified to apply cleanly against `main` with
`git apply --check`, and the changed scripts passed `shellcheck` and
`bash -n`. The jq selection logic was tested against sample payloads:
the newest marker wins, the area filter picks the latest matching issue,
and the no-marker case correctly yields `NONE`. Once applied, this
directory can be deleted.

---

Automated fix by codebase-review workflow
