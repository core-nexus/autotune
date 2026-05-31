# Security fix patches

This directory contains patch files for security fixes that the auto-review
bot cannot apply directly. GitHub Apps cannot modify files under
`.github/workflows/` without an explicit `workflows` write permission, which
this bot's token does not have — so every fix that lands in a workflow file
or workflow-adjacent script must be applied by a maintainer.

## Applying a patch

From the repo root, on a fresh branch:

```bash
git checkout -b apply-security-fix-2026-05-31
git apply --index .security-fixes/2026-05-31-issue-83.patch
git commit -m "fix(security): apply 2026-05-31 review fixes (issue 83)"
git push -u origin HEAD
```

Then open a PR. After it merges, delete the corresponding `.patch` file in
a follow-up commit.

## Verifying a patch before applying

```bash
git apply --check .security-fixes/2026-05-31-issue-83.patch
```

The patch is self-contained — it only touches files in this repo and adds
unit tests that run as a new lightweight workflow (`scripts-ci.yml`).
