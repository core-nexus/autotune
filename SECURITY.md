# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in this project — including in the
GitHub Actions workflows or scripts it ships — please report it privately.

- **Preferred:** Open a [GitHub Security Advisory](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)
  ("Report a vulnerability" under the repository's **Security** tab).
- Do **not** open a public issue for security reports.

Please include the affected file(s), a description of the issue, and a
proof-of-concept or reproduction steps where possible. We aim to acknowledge
reports within a few business days.

## Scope and Threat Model

This repository is a **drop-in CI/CD template** that runs autonomous Claude
agents with repository write access and secrets. Because every weakness here
propagates to repositories that adopt it, the workflows themselves are the
primary attack surface. We are particularly interested in reports about:

- Triggers that allow untrusted users to launch privileged (write-scoped) jobs.
- Prompt-injection paths where attacker-controlled content (PR diffs/comments,
  issue bodies) can redirect an agent.
- Secret exposure (tokens in logs, on disk, or via OIDC misuse).
- Supply-chain integrity of the third-party Actions used.

## Hardening Expectations for Adopters

When installing this template, you are responsible for:

- **Branch protection** on your default branch — see the README setup steps.
- Restricting who can invoke the `/claude-review` and `/claude-fix` commands
  (the workflows gate these on `author_association`).
- Keeping the pinned Action SHAs current (Dependabot is configured for this).
