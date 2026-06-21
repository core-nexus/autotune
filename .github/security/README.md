# Pending workflow security hardening

`workflow-hardening.patch` contains the security fixes for everything under
`.github/workflows/` — the two workflow files
(`claude-pr-review.yml`, `codebase-review.yml`) and the helper script
`scripts/extract-review-priority.sh` — from the automated security review
(issue titled `review(security): findings`).

These changes could **not** be pushed by the automated fixer because the bot's
GitHub App installation token lacks the `workflows` permission, which GitHub
requires to create or update **any** file under `.github/workflows/` (including
the `scripts/` subdirectory). The README documentation fix was applied directly;
all `.github/workflows/` changes are preserved here for a maintainer to apply.

## What the patch fixes

- **item 1 (HIGH)** — Author-authorization guard on the `/claude-review` and
  `/claude-fix` comment triggers (only `OWNER`/`MEMBER`/`COLLABORATOR`).
- **item 2 (HIGH)** — PR/issue content framed as untrusted data, not
  instructions (prompt-injection defense).
- **item 3 (MEDIUM)** — Third-party actions pinned to commit SHAs.
- **item 4 (MEDIUM)** — `--dangerously-skip-permissions` replaced with scoped
  `--allowedTools` allowlists.
- **item 5 (MEDIUM)** — `id-token: write` removed from all jobs.
- **item 6 (MEDIUM)** — Fix-stage priority gate fails closed; the issue-list
  fallback only trusts bot-authored issues (`scripts/extract-review-priority.sh`).
- **item 7 (LOW)** — Slash-command matching uses `startsWith()` not `contains()`.

Also fixes a pre-existing SC2155 shellcheck warning in the Trigger CI step.

## How to apply

From the repository root, on this branch:

```bash
git apply .github/security/workflow-hardening.patch
git add .github/workflows/
git commit -m "fix(security): apply workflow hardening (items 1-7)"
git rm -r .github/security && git commit -m "chore: remove applied hardening patch"
```

Applying requires a token/account with the `workflows` permission (a maintainer
pushing manually, or a GitHub App granted `workflows: write`).

Verify the patch applies cleanly first with:

```bash
git apply --check .github/security/workflow-hardening.patch
```
