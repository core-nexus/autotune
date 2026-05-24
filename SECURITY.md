# Security & Threat Model

This repository ships **no application code** — it is a copy-paste template of a
GitHub Actions automation that runs Claude as a code reviewer and auto-fixer.
The automation itself is the attack surface, so its trust model is documented
here. If you install this template into your own repo, read this first.

> **Status note.** The workflow- and script-level controls described below
> (author-association gating, fork gating, trusted-source fix gate, SHA pins,
> least-privilege `notify`, input validation) live under `.github/workflows/`.
> The automation bot that opened this change could not commit those files
> because its GitHub App installation lacks the `workflows` permission, so they
> are delivered as `security-review-fixes.patch` at the repo root. A maintainer
> (or a token/App with `workflows: write`) must apply that patch — see the PR
> description — to put the controls in place. Granting the App `workflows: write`
> lets future automated fixes land these changes directly.

## Why this matters

The `fix` jobs run the agent with `--dangerously-skip-permissions`, a
write-scoped `GITHUB_TOKEN` (`contents: write`), and the
`CLAUDE_CODE_OAUTH_TOKEN` secret. An attacker who can drive one of these jobs,
or smuggle instructions into the content the agent reads, can potentially commit
code, modify workflows, or exfiltrate secrets. On a **public** repository, PR
diffs and PR/issue/comment bodies are all attacker-controlled.

## Trust boundaries enforced by the workflows

1. **Author-association gate on comment triggers.**
   `issue_comment` events always run in the base-repo context with secrets,
   regardless of who commented. Both the `review` and `fix-review-issues` jobs in
   `claude-pr-review.yml` therefore require the commenter to be
   `OWNER`, `MEMBER`, or `COLLABORATOR` before `/claude-review` or `/claude-fix`
   will run.

2. **Fork gate on the PR auto path.**
   The auto `pull_request` review runs only for same-repo (non-fork) branches.
   Pushing a same-repo branch already requires write access, so this limits the
   auto path to trusted collaborators. Fork PRs do not get secrets from GitHub
   anyway, so they are skipped explicitly rather than failing silently.

3. **Privileged fix gate reads only a trusted source.**
   Whether a `fix` job runs is decided by the `MAXIMUM_FIX_PRIORITY` value, which
   is parsed **only** from the review step's own execution file (an in-run,
   trusted artifact). The scripts deliberately do not read PR comments or GitHub
   issues for this, because anyone can post `MAXIMUM_FIX_PRIORITY:HIGH` in a
   comment or open a same-titled issue. If the trusted source is missing, the
   gate fails closed (`NONE`) and no fix runs. See
   `.github/workflows/scripts/extract-pr-review-priority.sh` and
   `extract-review-priority.sh`.

4. **Fetched content is treated as data, not instructions.**
   The fix prompts instruct the agent to treat PR diffs, comments, and review
   issues as untrusted data describing code findings — never as commands to
   exfiltrate secrets, add network calls, weaken workflow security, or change
   git remotes. The codebase-review fixer additionally verifies the review issue
   was authored by the review bot (`claude[bot]`) and ignores spoofed issues.

5. **Pinned actions.**
   Third-party actions are pinned to full commit SHAs (with the human-readable
   version in a trailing comment), and Dependabot (`.github/dependabot.yml`)
   keeps the pins patched. This prevents a retagged/compromised upstream action
   from executing inside a job that holds write tokens and secrets.

6. **Least-privilege tokens.**
   Each job declares the minimum `permissions:` it needs; the `notify` job uses
   `permissions: {}`.

## Recommended additional hardening

Because the `fix` jobs push code autonomously, consider gating them behind a
**GitHub Environment with required reviewers** so a human approves each run:

1. Create an environment (e.g. `auto-fix`) under
   *Settings → Environments* and add yourself as a required reviewer.
2. Add `environment: auto-fix` to the `fix` / `fix-review-issues` jobs.

This adds a human-in-the-loop checkpoint between an injected instruction and any
push, on top of the controls above.

## Reporting a vulnerability

Open a private security advisory via the repository's *Security → Advisories*
tab, or contact the maintainers directly. Please do not file public issues for
exploitable findings.
