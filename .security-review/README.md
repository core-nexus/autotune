# Pending workflow security fixes

The file `workflow-security-fixes.patch` contains the security hardening
changes for files under `.github/workflows/` (the workflow YAML and the helper
scripts) from the 2026-06-28 security review.

These changes could **not** be pushed by the automated review bot because the
GitHub App token used by the fix workflow lacks the `workflows` permission,
which GitHub requires to create or update any file under `.github/workflows/`.

A maintainer (or a token/PAT with the `workflow` scope) must apply them:

```bash
git checkout review/security-2026-06-28
git apply .security-review/workflow-security-fixes.patch
git add .github/workflows
git commit -m "fix(security): apply workflow + script hardening from review"
git push
```

## What the patch contains

- **CRITICAL** — Gate the `issue_comment` triggers (`/claude-review`,
  `/claude-fix`) on `author_association` and use `startsWith` exact-command
  matching, so arbitrary commenters can no longer launch the privileged agent.
- **CRITICAL** — Trust-boundary preamble in both fix prompts: untrusted
  PR/issue content is treated as data, not instructions; the codebase fixer
  verifies the review issue's label/author before acting on it.
- **HIGH** — PR fix-stage priority is read from the trusted review execution
  file, not spoofable PR comments (`extract-pr-review-priority.sh`).
- **MEDIUM** — Pin `actions/checkout` and `anthropics/claude-code-action` to
  commit SHAs; `persist-credentials: false` on every read-only checkout.
- **LOW** — jq `--arg` instead of string interpolation; surface API failures
  instead of silently suppressing stderr.

Once applied and merged, this `.security-review/` directory can be removed.
