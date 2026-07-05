# Pending workflow security fixes — 2026-07-05

The file `workflow-security-fixes.patch` contains the security hardening
changes for files under `.github/workflows/` (the workflow YAML and the helper
scripts) from the 2026-07-05 security review (see the `review(security):
findings — 2026-07-05` issue).

These changes could **not** be pushed by the automated review bot because the
GitHub App token used by the fix workflow lacks the `workflows` permission,
which GitHub requires to create or update **any** file under `.github/workflows/`
(this includes the helper `.sh` scripts, not just the YAML). Every other change
in this PR is pushable and has been applied directly.

A maintainer (or a token/PAT with the `workflow` scope) must apply the patch:

```bash
git checkout review/security-2026-07-05
git apply .security-review/workflow-security-fixes.patch
git add .github/workflows
git commit -m "fix(security): apply workflow + script hardening from 2026-07-05 review"
git push
```

Verify before committing:

```bash
git apply --check .security-review/workflow-security-fixes.patch   # applies cleanly
```

## What the patch contains (mapped to the review findings)

- **HIGH — item 1** — Gate the `issue_comment` triggers (`/claude-review`,
  `/claude-fix`) on `github.event.comment.author_association` so only
  `OWNER`/`MEMBER`/`COLLABORATOR` can launch the privileged review/fix jobs.
  Previously the only gate was `!endsWith(github.actor, '[bot]')`, which lets
  any human commenter invoke the agent and burn the paid OAuth token.
- **HIGH — item 2** — Documented (in a `SECURITY NOTE` header on
  `claude-pr-review.yml`) that untrusted PR/issue content flows into an
  autonomous agent running `--dangerously-skip-permissions`; the item 1 gate
  and the item 4 permissions floor are the concrete blast-radius reductions.
- **HIGH — item 7** — Match commands with `startsWith(...)` at the start of the
  comment body instead of `contains(...)` anywhere, so quoting a command while
  discussing it no longer triggers a run.
- **MEDIUM — item 3** — Pin `actions/checkout@v4`,
  `anthropics/claude-code-action@v1`, and the Slack action to full commit SHAs
  (with a trailing version comment) in both workflows.
- **MEDIUM — item 4** — Add a top-level deny-all `permissions: {}` floor to both
  workflows; grant `determine-area` `contents: read` and `notify` `{}`.
- **LOW — item 5** — `extract-review-priority.sh` now passes `REVIEW_AREA` to
  `jq` via `--arg` instead of interpolating it into the jq program text.
- **LOW — item 6** — `resolve-review-area.sh` now validates the review area
  against the known list before writing it to `GITHUB_OUTPUT`, failing closed on
  any unexpected value (prevents `GITHUB_OUTPUT` injection).

## Pushable changes applied directly in this PR

- `README.md` — pinned the Slack action snippet to a commit SHA (item 3).
- `.github/dependabot.yml` — enables Dependabot for the `github-actions`
  ecosystem so the newly pinned SHAs are kept up to date safely (item 3
  follow-up recommendation).
- `.github/CODEOWNERS` — requires code-owner review on any change under
  `.github/`, so future workflow edits (including this patch) get human review.

Once the patch is applied and this PR is merged, the `.security-review/`
directory can be removed.
