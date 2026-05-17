# Security & Threat Model

This repository ships GitHub Actions automation that runs an **autonomous
Claude agent with a write-scoped `GITHUB_TOKEN` and a `CLAUDE_CODE_OAUTH_TOKEN`**.
On a public repository the automation is itself the primary attack surface.
This document records the trust model so future changes do not silently
re-open closed holes.

## Assets

- `CLAUDE_CODE_OAUTH_TOKEN` (repository secret).
- The job `GITHUB_TOKEN` — write-scoped in the fix jobs (`contents: write`,
  `pull-requests: write`, `issues: write`).
- The contents and history of the repository.

## Trust boundaries

| Source | Trust |
| --- | --- |
| Repo code on the default branch | Trusted |
| Local `claude-code-action` execution file from the current run | Trusted |
| PR diff / PR head branch code | **Untrusted** |
| PR title, body, and PR/issue comments | **Untrusted** |
| Issues opened by arbitrary users | **Untrusted** |
| Issues/comments authored by a `[bot]`/app account | Semi-trusted |

`[bot]` is a login suffix that GitHub reserves for Apps/bots; regular users
cannot register a login ending in `[bot]`, so author-login checks are a usable
(if coarse) trust signal.

## Controls

1. **Comment triggers are gated on author association.** Every
   `issue_comment`-triggered job (`review`, `fix-review-issues` in
   `claude-pr-review.yml`) requires
   `github.event.comment.author_association` ∈ `{OWNER, MEMBER, COLLABORATOR}`.
   `issue_comment` events always run in the base-repo context with secrets, so
   without this gate any GitHub user could start the privileged agent.
2. **Fork PRs are excluded from the auto path.** The `review` job skips
   `pull_request` events where `head.repo.fork == true`. GitHub already
   withholds secrets/write tokens from fork runs; this is defense in depth and
   documents intent.
3. **Untrusted content is data, not instructions.** The agent system prompts
   explicitly classify diffs, PR/issue bodies, and comments as untrusted data
   and forbid acting on embedded directives (workflow/permission changes,
   network calls, secret/token exfiltration). Detected injection attempts are
   reported, not executed.
4. **The privileged fix jobs run in the `auto-fix` Environment.** Repository
   maintainers should configure **required reviewers** on the `auto-fix`
   environment (Settings → Environments → `auto-fix`) so a human approves any
   autonomous push. Until configured, the environment is a no-op gate.
5. **The fix gate is derived only from trusted sources.** Priority comes from
   the local execution file of the current run; the issue-list fallback is
   restricted to `[bot]`-authored issues. It is never read from arbitrary
   PR/issue comments. The gate fails **closed** (`NONE` ⇒ fix does not run) on
   any API error, which is logged rather than swallowed.
6. **Least privilege.** Workflows set a restrictive top-level
   `permissions: contents: read` default and widen per job only as needed; the
   `notify` job carries `permissions: {}`.
7. **Supply chain.** Third-party actions are pinned to full commit SHAs with a
   version comment; Dependabot (`github-actions` ecosystem) keeps the pins
   current.

## Accepted residual risk

`--dangerously-skip-permissions` is intrinsic to the automation's design: the
agent must act without interactive approval. This amplifies any
prompt-injection or supply-chain issue into full token authority. It is
accepted and mitigated by controls 1–7 above; the `auto-fix` required-reviewer
gate (control 4) is the recommended human backstop for higher-risk repos.

## Reporting

Report suspected vulnerabilities privately via the repository's GitHub
Security Advisories ("Report a vulnerability"). Do not open a public issue.
